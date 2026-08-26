local luax = require("test.support.luax")
local P = require("test.support.shared_support")
local _assert_eq = P.assert_eq
local overlay_runtime = require("src.ui.render.anim.overlay_runtime")

local function _new_host_spy(overrides)
  local calls = {}
  local hr = {
    create_unit_group = function(group_id, pos)
      calls[#calls + 1] = { "create_unit_group", group_id, pos }
      return "group_handle"
    end,
    create_unit_with_scale = function(unit_id, pos)
      calls[#calls + 1] = { "create_unit_with_scale", unit_id, pos }
      return "unit_handle"
    end,
    destroy_unit = function(handle)
      calls[#calls + 1] = { "destroy_unit", handle }
    end,
    destroy_unit_with_children = function(handle, recurse)
      calls[#calls + 1] = { "destroy_unit_with_children", handle, recurse }
    end,
    schedule = function(duration, fn)
      calls[#calls + 1] = { "schedule", duration, fn }
    end,
  }
  for key, value in pairs(overrides or {}) do
    hr[key] = value
  end
  return hr, calls
end

TestOverlayRuntimeTransient = {}

function TestOverlayRuntimeTransient:test_requires_a_position_for_both_group_and_unit_paths()
  -- 精确消息钉(kills _spawn_unit_group/_spawn_unit 两条 "missing pos" -> nil)。
  local hr = _new_host_spy()
  luax.has_error(function()
    overlay_runtime.spawn_transient("group_a", nil, nil, 0, { host_runtime = hr })
  end, "missing pos")
  luax.has_error(function()
    overlay_runtime.spawn_transient(nil, "unit_a", nil, 0, { host_runtime = hr })
  end, "missing pos")
end

function TestOverlayRuntimeTransient:test_spawns_group_and_destroys_immediately_without_duration()
  local hr, calls = _new_host_spy()
  overlay_runtime.spawn_transient("group_a", nil, { x = 1 }, 0, { host_runtime = hr })
  _assert_eq(calls[1][1], "create_unit_group", "should spawn the unit group")
  _assert_eq(calls[2][1], "destroy_unit_with_children", "group entry should destroy with children")
  _assert_eq(calls[2][2], "group_handle", "should destroy the spawned handle")
  _assert_eq(calls[2][3], true, "should destroy children recursively")
end

function TestOverlayRuntimeTransient:test_schedules_group_destroy_for_positive_duration()
  local hr, calls = _new_host_spy()
  overlay_runtime.spawn_transient("group_a", nil, { x = 1 }, 1.5, { host_runtime = hr })
  _assert_eq(calls[2][1], "schedule", "positive duration should defer destroy")
  _assert_eq(calls[2][2], 1.5, "should schedule with the requested duration")
  calls[2][3]()
  _assert_eq(calls[3][1], "destroy_unit_with_children", "deferred destroy should run on fire")
end

function TestOverlayRuntimeTransient:test_skips_destroy_when_group_spawn_fails()
  local hr, calls = _new_host_spy({ create_unit_group = function() return nil end })
  overlay_runtime.spawn_transient("group_a", nil, { x = 1 }, 0, { host_runtime = hr })
  _assert_eq(#calls, 0, "failed group spawn should not destroy or schedule")
end

function TestOverlayRuntimeTransient:test_spawns_unit_and_destroys_immediately_without_duration()
  local hr, calls = _new_host_spy()
  overlay_runtime.spawn_transient(nil, "unit_a", { x = 2 }, nil, { host_runtime = hr })
  _assert_eq(calls[1][1], "create_unit_with_scale", "should spawn the unit")
  _assert_eq(calls[2][1], "destroy_unit", "unit entry should destroy plainly")
  _assert_eq(calls[2][2], "unit_handle", "should destroy the spawned handle")
end

function TestOverlayRuntimeTransient:test_skips_destroy_when_unit_spawn_fails()
  local hr, calls = _new_host_spy({
    acquire_unit = function() return nil end,
  })
  overlay_runtime.spawn_transient(nil, "unit_a", { x = 2 }, 0, { host_runtime = hr })
  _assert_eq(#calls, 0, "failed unit spawn should not destroy or schedule")
end

function TestOverlayRuntimeTransient:test_releases_pooled_unit_back_to_the_pool()
  local released = nil
  local hr, calls = _new_host_spy({
    acquire_unit = function(unit_id)
      return "pooled_" .. unit_id
    end,
    release_unit = function(unit_id, handle)
      released = { unit_id, handle }
    end,
  })
  overlay_runtime.spawn_transient(nil, "unit_a", { x = 2 }, 0, { host_runtime = hr })
  _assert_eq(released ~= nil, true, "pooled transient unit should be released, not destroyed")
  _assert_eq(released[1], "unit_a", "release should carry the unit id")
  _assert_eq(released[2], "pooled_unit_a", "release should return the acquired handle")
  _assert_eq(#calls, 0, "no destroy call should reach the host for a pooled unit")
end

function TestOverlayRuntimeTransient:test_does_nothing_without_group_or_unit_id()
  local hr, calls = _new_host_spy()
  overlay_runtime.spawn_transient(nil, nil, { x = 3 }, 0, { host_runtime = hr })
  _assert_eq(#calls, 0, "missing ids should be a no-op")
end

function TestOverlayRuntimeTransient:test_spawn_transient_without_deps_falls_back_to_host_ports()
  -- L154 `deps and deps.scene or nil` 的 and->or:deps 缺省时不得索引 nil,
  -- 必须回落到 host_runtime_ports 继续生成。
  local spawned = 0
  local destroyed = 0
  P.with_patches({
    { target = require("src.ui.seams.host_runtime"), key = "create_unit_group", value = function()
      spawned = spawned + 1
      return "fallback_handle"
    end },
    { target = require("src.ui.seams.host_runtime"), key = "destroy_unit_with_children", value = function()
      destroyed = destroyed + 1
    end },
  }, function()
    overlay_runtime.spawn_transient("group_a", nil, { x = 1 }, 0)
  end)
  _assert_eq(spawned, 1, "deps-less transient spawn must fall back to the host ports")
  _assert_eq(destroyed, 1, "the fallback entry must still be destroyed")
end


return TestOverlayRuntimeTransient
