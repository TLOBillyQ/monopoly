local lu = require("luaunit")
local entity_pool = require("src.host.entity_pool")
local unit_lifecycle = require("src.host.units")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local support = require("test.support.shared_support")
local with_patches = support.with_patches

local PARK_POS = runtime_constants.entity_pool_park_pos
local MAX_IDLE = runtime_constants.entity_pool_max_idle

local function _assert_eq(actual, expected, message)
  assert(actual == expected, (message or "assertion failed")
    .. " expected=" .. tostring(expected)
    .. " actual=" .. tostring(actual))
end

-- Handles in this pool are invoked positionally (handle.method(arg)), never as
-- methods (handle:method(arg)), so the recording closures take the forwarded
-- value as their first argument.
local function make_handle(tag, log)
  return {
    tag = tag,
    set_position = function(p) log[#log + 1] = { tag = tag, m = "set_position", arg = p } end,
    set_orientation = function(r) log[#log + 1] = { tag = tag, m = "set_orientation", arg = r } end,
    set_world_scale = function(s) log[#log + 1] = { tag = tag, m = "set_world_scale", arg = s } end,
    set_model_visible = function(v) log[#log + 1] = { tag = tag, m = "set_model_visible", arg = v } end,
  }
end

TestEntityPool = {}

function TestEntityPool:tearDown()
  entity_pool.reset()
end

function TestEntityPool:test_returns_nil_when_unit_key_is_nil()
  lu.assertEvalToTrue(entity_pool.acquire(nil, {}) == nil, "expected nil with nil unit_key")
end

function TestEntityPool:test_returns_nil_when_pos_is_nil()
  lu.assertEvalToTrue(entity_pool.acquire("k", nil) == nil, "expected nil with nil pos")
end

function TestEntityPool:test_returns_nil_when_gameapi_absent_and_no_idle_handles()
  lu.assertEvalToTrue(entity_pool.acquire("miss_key", { x = 0 }) == nil, "expected nil without GameAPI")
end

function TestEntityPool:test_pulls_a_parked_handle_and_re_applies_position_orientation_scale_and_visibility()
  local log = {}
  local handle = make_handle("h", log)
  entity_pool.release("reuse_key", handle)
  -- Discard the release-time calls; only the acquire re-application matters here.
  for i = #log, 1, -1 do log[i] = nil end

  local pos = { x = 1 }
  local rotation = { y = 2 }
  local scale = { z = 3 }
  local got = entity_pool.acquire("reuse_key", pos, rotation, scale)

  lu.assertEvalToTrue(got == handle, "acquire should reuse the parked handle instead of creating a new one")
  local by_method = {}
  for _, call in ipairs(log) do by_method[call.m] = call.arg end
  lu.assertEvalToTrue(by_method.set_position == pos, "reused handle should be moved to the requested pos")
  lu.assertEvalToTrue(by_method.set_orientation == rotation, "reused handle should take the requested orientation")
  lu.assertEvalToTrue(by_method.set_world_scale == scale, "reused handle should take the requested scale")
  lu.assertEvalToTrue(by_method.set_model_visible == true, "reused handle should be made visible")

  local stats = entity_pool.stats()["reuse_key"]
  lu.assertEvalToTrue(stats.idle == 0, "reused handle should leave the idle list")
  lu.assertEvalToTrue(stats.live == 1, "reusing a handle should increment the live count")
  lu.assertEvalToTrue(stats.miss == 0, "reusing an idle handle should not count as a miss")
end

function TestEntityPool:test_forwards_key_pos_rotation_scale_to_the_host_and_counts_a_miss()
  local seen
  local created = make_handle("created", {})
  with_patches({
    { target = unit_lifecycle, key = "create_unit_with_scale", value = function(unit_key, pos, rotation, scale)
      seen = { unit_key = unit_key, pos = pos, rotation = rotation, scale = scale }
      return created
    end },
  }, function()
    local pos = { x = 7 }
    local rotation = { y = 8 }
    local scale = { z = 9 }
    local got = entity_pool.acquire("mk", pos, rotation, scale)
    lu.assertEvalToTrue(got == created, "acquire should return the freshly created handle")
    lu.assertEvalToTrue(seen.unit_key == "mk", "create should receive the unit_key")
    lu.assertEvalToTrue(seen.pos == pos, "create should receive the pos")
    lu.assertEvalToTrue(seen.rotation == rotation, "create should receive the rotation")
    lu.assertEvalToTrue(seen.scale == scale, "create should receive the scale")
  end)

  local stats = entity_pool.stats()["mk"]
  lu.assertEvalToTrue(stats.miss == 1, "a create should be counted as one miss")
  lu.assertEvalToTrue(stats.live == 1, "a successful create should increment live")
  lu.assertEvalToTrue(stats.peak == 1, "peak should track the first live handle")
end

function TestEntityPool:test_logs_the_entity_pool_prefix_when_the_host_create_yields_nil()
  -- kills the warn call's "[entity_pool]" -> nil.
  local logger = require("src.foundation.log")
  local warns = {}
  with_patches({
    { target = unit_lifecycle, key = "create_unit_with_scale", value = function() return nil end },
    { target = logger, key = "warn", value = function(...)
      warns[#warns + 1] = { ... }
    end },
  }, function()
    lu.assertEvalToTrue(entity_pool.acquire("wk", { x = 1 }) == nil, "failed create returns nil")
  end)
  lu.assertEvalToTrue(#warns == 1, "exactly one warn is logged")
  _assert_eq(warns[1][1], "[entity_pool]", "the warn keeps its module prefix")
end

function TestEntityPool:test_returns_nil_and_counts_the_miss_when_the_host_create_yields_nil()
  with_patches({
    { target = unit_lifecycle, key = "create_unit_with_scale", value = function() return nil end },
  }, function()
    lu.assertEvalToTrue(entity_pool.acquire("nk", { x = 0 }) == nil, "acquire should return nil when create fails")
  end)
  local stats = entity_pool.stats()["nk"]
  lu.assertEvalToTrue(stats.miss == 1, "a failed create should still be counted as a miss")
  lu.assertEvalToTrue(stats.live == 0, "a failed create should not increment live")
  lu.assertEvalToTrue(stats.peak == 0, "a failed create should not raise peak")
end

function TestEntityPool:test_keeps_peak_at_the_high_water_mark_after_a_release_lowers_live()
  local created = 0
  with_patches({
    { target = unit_lifecycle, key = "create_unit_with_scale", value = function()
      created = created + 1
      return make_handle("c" .. created, {})
    end },
  }, function()
    local h1 = entity_pool.acquire("pk", { x = 1 })
    entity_pool.acquire("pk", { x = 2 })
    local peak2 = entity_pool.stats()["pk"]
    lu.assertEvalToTrue(peak2.live == 2, "two acquires should make live 2")
    lu.assertEvalToTrue(peak2.peak == 2, "peak should rise to 2")

    entity_pool.release("pk", h1)
    local after = entity_pool.stats()["pk"]
    lu.assertEvalToTrue(after.live == 1, "release should lower live back to 1")
    lu.assertEvalToTrue(after.peak == 2, "peak should stay at the high-water mark of 2")
  end)
end

function TestEntityPool:test_does_not_drive_live_below_zero_when_releasing_an_un_acquired_handle()
  entity_pool.release("rk", make_handle("r", {}))
  local stats = entity_pool.stats()["rk"]
  lu.assertEvalToTrue(stats.live == 0, "releasing without a prior acquire should keep live at 0, not negative")
end

function TestEntityPool:test_keeps_peak_at_the_high_water_mark_when_live_later_rises_below_it()
  local created = 0
  with_patches({
    { target = unit_lifecycle, key = "create_unit_with_scale", value = function()
      created = created + 1
      return make_handle("hw" .. created, {})
    end },
  }, function()
    local h1 = entity_pool.acquire("hwk", { x = 1 })
    local h2 = entity_pool.acquire("hwk", { x = 2 })
    entity_pool.acquire("hwk", { x = 3 })
    lu.assertEvalToTrue(entity_pool.stats()["hwk"].peak == 3, "three live handles should raise peak to 3")

    entity_pool.release("hwk", h1)
    entity_pool.release("hwk", h2)
    entity_pool.acquire("hwk", { x = 4 })

    local stats = entity_pool.stats()["hwk"]
    lu.assertEvalToTrue(stats.live == 2, "re-acquiring one handle should bring live to 2")
    lu.assertEvalToTrue(stats.peak == 3,
      "peak should stay at its high-water mark and not be overwritten while live is below it")
  end)
end

function TestEntityPool:test_hides_the_handle_and_parks_it_at_the_park_position()
  local log = {}
  local handle = make_handle("h", log)
  entity_pool.release("hide_key", handle)

  local by_method = {}
  for _, call in ipairs(log) do by_method[call.m] = call.arg end
  lu.assertEvalToTrue(by_method.set_model_visible == false, "release should hide the handle")
  lu.assertEvalToTrue(by_method.set_position == PARK_POS, "release should move the handle to the park position")

  local stats = entity_pool.stats()["hide_key"]
  lu.assertEvalToTrue(stats ~= nil, "expected bucket entry after release")
  lu.assertEvalToTrue(stats.idle == 1, "released handle should be parked in the idle list")
end

function TestEntityPool:test_parks_handles_until_the_idle_cap_then_destroys_extras()
  local destroyed = {}
  with_patches({
    { target = unit_lifecycle, key = "destroy_unit", value = function(handle)
      destroyed[#destroyed + 1] = handle
    end },
  }, function()
    for i = 1, MAX_IDLE do
      entity_pool.release("ck", make_handle("keep" .. i, {}))
    end
    lu.assertEvalToTrue(#destroyed == 0, "handles up to the idle cap should be parked, not destroyed")
    lu.assertEvalToTrue(entity_pool.stats()["ck"].idle == MAX_IDLE, "idle list should fill to the cap")

    local overflow = make_handle("overflow", {})
    entity_pool.release("ck", overflow)
    lu.assertEvalToTrue(entity_pool.stats()["ck"].idle == MAX_IDLE, "idle list should not grow beyond the cap")
    lu.assertEvalToTrue(#destroyed == 1 and destroyed[1] == overflow,
      "a handle past the idle cap should be destroyed")
  end)
end

function TestEntityPool:test_ignores_nil_unit_key_or_nil_handle()
  entity_pool.release(nil, make_handle("x", {}))
  entity_pool.release("nilguard_key", nil)
  lu.assertEvalToTrue(entity_pool.stats()["nilguard_key"] == nil, "release with a nil handle should not create a bucket")
end

function TestEntityPool:test_creates_and_parks_handles_up_to_the_requested_count()
  local created = {}
  local log = {}
  with_patches({
    { target = unit_lifecycle, key = "create_unit_with_scale", value = function(unit_key, pos, rotation, scale)
      created[#created + 1] = { unit_key = unit_key, pos = pos, rotation = rotation, scale = scale }
      return make_handle("pw" .. #created, log)
    end },
  }, function()
    local sample_pos = { x = 42 }
    entity_pool.prewarm("wk", 3, { r = 1 }, { s = 2 }, sample_pos)
    lu.assertEvalToTrue(#created == 3, "prewarm should create the requested number of handles")
    lu.assertEvalToTrue(created[1].unit_key == "wk", "prewarm create should receive the unit_key")
    lu.assertEvalToTrue(created[1].pos == sample_pos, "prewarm should forward the sample position")
    lu.assertEvalToTrue(created[1].rotation.r == 1, "prewarm should forward the rotation")
    lu.assertEvalToTrue(created[1].scale.s == 2, "prewarm should forward the scale")
  end)

  local stats = entity_pool.stats()["wk"]
  lu.assertEvalToTrue(stats.idle == 3, "prewarmed handles should be parked in the idle list")

  local visible_calls = 0
  local parked_calls = 0
  for _, call in ipairs(log) do
    if call.m == "set_model_visible" and call.arg == false then visible_calls = visible_calls + 1 end
    if call.m == "set_position" and call.arg == PARK_POS then parked_calls = parked_calls + 1 end
  end
  lu.assertEvalToTrue(visible_calls == 3, "each prewarmed handle should be hidden")
  lu.assertEvalToTrue(parked_calls == 3, "each prewarmed handle should be parked at the park position")
end

function TestEntityPool:test_defaults_the_sample_position_to_the_park_position()
  local seen_pos
  with_patches({
    { target = unit_lifecycle, key = "create_unit_with_scale", value = function(_, pos)
      seen_pos = pos
      return make_handle("pd", {})
    end },
  }, function()
    entity_pool.prewarm("dk", 1)
    lu.assertEvalToTrue(seen_pos == PARK_POS, "prewarm without a sample pos should default to the park position")
  end)
end

function TestEntityPool:test_never_fills_past_the_idle_cap()
  with_patches({
    { target = unit_lifecycle, key = "create_unit_with_scale", value = function()
      return make_handle("cap", {})
    end },
  }, function()
    entity_pool.prewarm("capk", MAX_IDLE + 5)
    lu.assertEvalToTrue(entity_pool.stats()["capk"].idle == MAX_IDLE, "prewarm should stop at the idle cap")
  end)
end

function TestEntityPool:test_does_nothing_for_invalid_counts_or_a_nil_key()
  local created = 0
  with_patches({
    { target = unit_lifecycle, key = "create_unit_with_scale", value = function()
      created = created + 1
      return make_handle("z", {})
    end },
  }, function()
    entity_pool.prewarm("zk", 0)
    entity_pool.prewarm("zk", -3)
    entity_pool.prewarm(nil, 3)
  end)
  lu.assertEvalToTrue(created == 0, "invalid prewarm arguments should create nothing")
  lu.assertEvalToTrue(entity_pool.stats()["zk"] == nil, "a zero/negative prewarm should not build a bucket")
end

function TestEntityPool:test_stops_parking_when_the_host_create_yields_nil()
  with_patches({
    { target = unit_lifecycle, key = "create_unit_with_scale", value = function() return nil end },
  }, function()
    entity_pool.prewarm("fk", 4)
    local stats = entity_pool.stats()["fk"]
    lu.assertEvalToTrue(stats.idle == 0, "a failing host create should leave nothing parked")
  end)
end

function TestEntityPool:test_keeps_prewarming_past_a_single_transient_host_create_failure()
  local calls = 0
  with_patches({
    { target = unit_lifecycle, key = "create_unit_with_scale", value = function()
      calls = calls + 1
      if calls == 1 then return nil end
      return make_handle("ok" .. calls, {})
    end },
  }, function()
    entity_pool.prewarm("tfk", 3)
    lu.assertEvalToTrue(entity_pool.stats()["tfk"].idle == 2,
      "a transient create failure should let later prewarm iterations keep parking handles")
  end)
end

function TestEntityPool:test_tops_up_only_the_missing_handles_when_some_are_already_parked()
  with_patches({
    { target = unit_lifecycle, key = "create_unit_with_scale", value = function()
      return make_handle("tu", {})
    end },
  }, function()
    entity_pool.prewarm("tuk", 2)
    lu.assertEvalToTrue(entity_pool.stats()["tuk"].idle == 2, "the first prewarm should park two handles")
    entity_pool.prewarm("tuk", 3)
    lu.assertEvalToTrue(entity_pool.stats()["tuk"].idle == 3,
      "a second prewarm should top up to exactly the requested count, not overshoot")
  end)
end

function TestEntityPool:test_reports_idle_live_peak_and_miss_per_bucket()
  local created = 0
  with_patches({
    { target = unit_lifecycle, key = "create_unit_with_scale", value = function()
      created = created + 1
      return make_handle("s" .. created, {})
    end },
  }, function()
    local h = entity_pool.acquire("sk", { x = 1 })
    entity_pool.release("sk", h)
    local stats = entity_pool.stats()["sk"]
    lu.assertEvalToTrue(stats.idle == 1, "stats should report one idle handle")
    lu.assertEvalToTrue(stats.live == 0, "stats should report live back to 0 after release")
    lu.assertEvalToTrue(stats.peak == 1, "stats should report the peak live of 1")
    lu.assertEvalToTrue(stats.miss == 1, "stats should report one miss from the create")
  end)
end

function TestEntityPool:test_destroys_parked_handles_and_clears_the_idle_lists()
  local destroyed = {}
  with_patches({
    { target = unit_lifecycle, key = "create_unit_with_scale", value = function()
      return make_handle("d" .. (#destroyed + 1), {})
    end },
    { target = unit_lifecycle, key = "destroy_unit", value = function(handle)
      destroyed[#destroyed + 1] = handle
    end },
  }, function()
    entity_pool.prewarm("xk", 2)
    lu.assertEvalToTrue(entity_pool.stats()["xk"].idle == 2, "prewarm should park two handles")

    entity_pool.reset()
    lu.assertEvalToTrue(#destroyed == 2, "reset should destroy every parked handle")
    lu.assertEvalToTrue(entity_pool.stats()["xk"].idle == 0, "reset should empty the idle list")
  end)
end

function TestEntityPool:test_prewarm_fills_the_idle_bucket_hides_and_parks_units_and_respects_max_idle()
  entity_pool.reset()
  local created = 0
  local hidden = 0
  local parked = 0

  with_patches({
    { target = unit_lifecycle, key = "create_unit_with_scale", value = function()
      created = created + 1
      return {
        set_model_visible = function(visible)
          if visible == false then
            hidden = hidden + 1
          end
        end,
        set_position = function()
          parked = parked + 1
        end,
      }
    end },
  }, function()
    entity_pool.prewarm("unit-a", 2, nil, nil, { x = 1, y = 2, z = 3 })
    entity_pool.prewarm(nil, 2)
    entity_pool.prewarm("unit-a", -1)
  end)

  local stats = entity_pool.stats()
  _assert_eq(created, 2, "prewarm should create requested idle units")
  _assert_eq(hidden, 2, "prewarm should hide created units")
  _assert_eq(parked, 2, "prewarm should park created units")
  _assert_eq(stats["unit-a"].idle, 2, "prewarm should fill idle bucket")
  entity_pool.reset()
end

function TestEntityPool:test_acquire_reuses_a_parked_idle_handle_and_refreshes_its_transform()
  entity_pool.reset()
  local created = 0
  local calls = { position = 0, orientation = 0, scale = 0, visible = nil }
  local handle = {
    set_position = function()
      calls.position = calls.position + 1
    end,
    set_orientation = function()
      calls.orientation = calls.orientation + 1
    end,
    set_world_scale = function()
      calls.scale = calls.scale + 1
    end,
    set_model_visible = function(visible)
      calls.visible = visible
    end,
  }

  with_patches({
    { target = unit_lifecycle, key = "create_unit_with_scale", value = function()
      created = created + 1
      return handle
    end },
  }, function()
    entity_pool.prewarm("unit-reuse", 1, nil, nil, { x = 0, y = 0, z = 0 })
    local acquired = entity_pool.acquire("unit-reuse", { x = 1, y = 2, z = 3 }, nil, nil)
    _assert_eq(acquired, handle, "acquire should reuse the parked idle handle")
  end)

  _assert_eq(created, 1, "reuse path must not create a second unit")
  _assert_eq(calls.orientation, 1, "reused handle should be reoriented on acquire")
  _assert_eq(calls.scale, 1, "reused handle should be rescaled on acquire")
  _assert_eq(calls.visible, true, "reused handle should be made visible on acquire")
  local stats = entity_pool.stats()
  _assert_eq(stats["unit-reuse"].idle, 0, "acquire should drain the idle bucket")
  entity_pool.reset()
end


return TestEntityPool
