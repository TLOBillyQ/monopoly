---@diagnostic disable: undefined-global, undefined-field
local luassert = assert

local function _make_mock_lifecycle()
  local mock = {
    create_calls = 0,
    destroy_calls = 0,
    created = {},
    destroyed = {},
    _seq = 0,
  }

  function mock.create_unit_with_scale(unit_key, pos, _rotation, _scale)
    mock.create_calls = mock.create_calls + 1
    mock._seq = mock._seq + 1
    local handle = {
      _key = unit_key,
      _pos = pos,
      _visible = true,
      _seq = mock._seq,
      visible_calls = {},
      position_calls = {},
      rotation_calls = {},
      scale_calls = {},
    }
    function handle.set_model_visible(v)
      handle.visible_calls[#handle.visible_calls + 1] = v
      handle._visible = v
    end
    function handle.set_position(p)
      handle.position_calls[#handle.position_calls + 1] = p
      handle._pos = p
    end
    function handle.set_orientation(r)
      handle.rotation_calls[#handle.rotation_calls + 1] = r
    end
    function handle.set_world_scale(s)
      handle.scale_calls[#handle.scale_calls + 1] = s
    end
    mock.created[#mock.created + 1] = handle
    return handle
  end

  function mock.destroy_unit(handle)
    mock.destroy_calls = mock.destroy_calls + 1
    mock.destroyed[#mock.destroyed + 1] = handle
  end

  return mock
end

local function _load_pool_with_mock(mock)
  local original_units = package.loaded["src.host.units"]
  local original_pool = package.loaded["src.host.entity_pool"]
  package.loaded["src.host.units"] = mock
  package.loaded["src.host.entity_pool"] = nil
  local ok, pool = pcall(require, "src.host.entity_pool")
  package.loaded["src.host.units"] = original_units
  package.loaded["src.host.entity_pool"] = original_pool
  assert(ok, pool)
  return pool
end

local function _make_pos(x, y, z)
  if math and math.Vector3 then
    return math.Vector3(x or 0.0, y or 0.0, z or 0.0)
  end
  return { x = x or 0.0, y = y or 0.0, z = z or 0.0 }
end

local function _make_rot()
  if math and math.Quaternion then
    return math.Quaternion(0.0, 0.0, 0.0)
  end
  return { x = 0.0, y = 0.0, z = 0.0 }
end

local function _make_scale()
  if math and math.Vector3 then
    return math.Vector3(1.0, 1.0, 1.0)
  end
  return { x = 1.0, y = 1.0, z = 1.0 }
end

local function _make_non_table_handle(methods)
  local handle = coroutine.create(function() end)
  local original_mt = debug.getmetatable(handle)
  debug.setmetatable(handle, {
    __index = methods,
  })
  return handle, original_mt
end

describe("TestHostEntityPool", function()
  local logger = require("src.foundation.log")
  local original_print, original_warn, thread_probe, original_thread_mt

  before_each(function()
    original_print = _G.print
    original_warn = logger.warn
    thread_probe = coroutine.create(function() end)
    original_thread_mt = debug.getmetatable(thread_probe)
  end)

  after_each(function()
    _G.print = original_print
    logger.warn = original_warn
    debug.setmetatable(thread_probe, original_thread_mt)
  end)

  it("test_acquire_creates_unit_on_cold_miss", function()
  local mock = _make_mock_lifecycle()
  local pool = _load_pool_with_mock(mock)
  local pos = _make_pos(1.0, 0.0, 2.0)

  local handle = pool.acquire("robot_id", pos, _make_rot(), _make_scale())

  luassert.is_not_nil(handle, "acquire should return a handle")
  luassert.is.equal(1, mock.create_calls, "cold acquire must call create_unit_with_scale once")
  luassert.is.equal(0, mock.destroy_calls, "cold acquire must not destroy anything")
  end)

  it("test_acquire_with_nil_args_warns_and_returns_nil", function()
  -- #339 留痕(ADR 0046):nil 入参不得零留痕跳过——warn 带上下文,
  -- 行为保持——仍返回 nil 且不触碰生命周期。
  local mock = _make_mock_lifecycle()
  local pool = _load_pool_with_mock(mock)
  local pos = _make_pos(1.0, 0.0, 2.0)

  local lines = {}
  _G.print = function(...)
    local parts = {}
    for index = 1, select("#", ...) do
      parts[#parts + 1] = tostring(select(index, ...))
    end
    lines[#lines + 1] = table.concat(parts, " ")
  end

  local h1 = pool.acquire(nil, pos, _make_rot(), _make_scale())
  local h2 = pool.acquire("robot_id", nil, _make_rot(), _make_scale())

  _G.print = original_print
  local output = table.concat(lines, "\n")
  luassert.is_nil(h1, "nil unit_key must yield nil")
  luassert.is_nil(h2, "nil pos must yield nil")
  luassert.is.equal(0, mock.create_calls, "nil args must not create units")
  luassert.truthy(output:find("[entity_pool]", 1, true) ~= nil,
    "nil acquire must warn under [entity_pool]; got: " .. output)
  luassert.truthy(output:find("[entity_pool] acquire with nil unit_key", 1, true) ~= nil,
    "the nil unit_key warn must carry the [entity_pool] prefix on its own line; got: " .. output)
  luassert.truthy(output:find("[entity_pool] acquire with nil pos", 1, true) ~= nil,
    "the nil pos warn must carry the [entity_pool] prefix on its own line; got: " .. output)
  end)

  it("test_release_then_acquire_reuses_handle_without_extra_create", function()
  local mock = _make_mock_lifecycle()
  local pool = _load_pool_with_mock(mock)
  local pos = _make_pos(1.0, 0.0, 2.0)

  local h1 = pool.acquire("robot_id", pos, _make_rot(), _make_scale())
  pool.release("robot_id", h1)
  local h2 = pool.acquire("robot_id", pos, _make_rot(), _make_scale())

  luassert.is.equal(1, mock.create_calls, "second acquire must reuse idle handle (no extra create)")
  luassert.is.same(h1, h2, "reused handle must be identical object")
  luassert.is.equal(0, mock.destroy_calls, "release under max_idle must not destroy")
  end)

  it("test_release_calls_set_model_visible_false_on_handle", function()
  local mock = _make_mock_lifecycle()
  local pool = _load_pool_with_mock(mock)
  local pos = _make_pos(0.0, 0.0, 0.0)

  local h = pool.acquire("robot_id", pos, _make_rot(), _make_scale())
  pool.release("robot_id", h)

  local last_visible = h.visible_calls[#h.visible_calls]
  luassert.is.equal(false, last_visible, "release must set_model_visible(false)")
  end)

  it("test_acquire_calls_set_model_visible_true_when_reusing_idle_handle", function()
  local mock = _make_mock_lifecycle()
  local pool = _load_pool_with_mock(mock)
  local pos = _make_pos(0.0, 0.0, 0.0)

  local h = pool.acquire("robot_id", pos, _make_rot(), _make_scale())
  pool.release("robot_id", h)
  pool.acquire("robot_id", pos, _make_rot(), _make_scale())

  local last_visible = h.visible_calls[#h.visible_calls]
  luassert.is.equal(true, last_visible, "re-acquire must set_model_visible(true) on recycled handle")
  end)

  it("test_release_and_re_acquire_call_methods_on_non_table_host_handles", function()
  local mock = _make_mock_lifecycle()
  local calls = {}
  local handle, original_mt = _make_non_table_handle({
    set_model_visible = function(v)
      calls[#calls + 1] = { name = "visible", value = v }
    end,
    set_position = function(p)
      calls[#calls + 1] = { name = "position", value = p }
    end,
    set_orientation = function(r)
      calls[#calls + 1] = { name = "rotation", value = r }
    end,
    set_world_scale = function(s)
      calls[#calls + 1] = { name = "scale", value = s }
    end,
  })
  function mock.create_unit_with_scale(_unit_key, _pos, _rotation, _scale)
    mock.create_calls = mock.create_calls + 1
    return handle
  end
  local pool = _load_pool_with_mock(mock)
  local spawn_pos = _make_pos(0.0, 0.0, 0.0)
  local reuse_pos = _make_pos(1.0, 2.0, 3.0)
  local rotation = _make_rot()
  local scale = _make_scale()

  local h1 = pool.acquire("host_handle_id", spawn_pos, rotation, scale)
  pool.release("host_handle_id", h1)
  local h2 = pool.acquire("host_handle_id", reuse_pos, rotation, scale)
  debug.setmetatable(handle, original_mt)

  luassert.is.equal(handle, h2, "pool should reuse the same non-table host handle")
  luassert.is.equal(1, mock.create_calls, "re-acquire should reuse the non-table host handle")
  luassert.is.equal("visible", calls[1].name, "release should hide pooled host handles")
  luassert.is.equal(false, calls[1].value, "release should call set_model_visible(false)")
  luassert.is.equal("position", calls[2].name, "release should park pooled host handles")
  luassert.is.equal("position", calls[3].name, "re-acquire should move pooled host handles")
  luassert.is.same(reuse_pos, calls[3].value, "re-acquire should move to the requested position")
  luassert.is.equal("rotation", calls[4].name, "re-acquire should refresh rotation")
  luassert.is.equal("scale", calls[5].name, "re-acquire should refresh scale")
  luassert.is.equal("visible", calls[6].name, "re-acquire should show pooled host handles")
  luassert.is.equal(true, calls[6].value, "re-acquire should call set_model_visible(true)")
  end)

  it("test_overflow_release_destroys_handle_when_idle_bucket_is_full", function()
  local mock = _make_mock_lifecycle()
  local pool = _load_pool_with_mock(mock)
  local pos = _make_pos(0.0, 0.0, 0.0)
  local max_idle = require("src.config.gameplay.runtime_constants").entity_pool_max_idle

  local handles = {}
  for i = 1, max_idle + 1 do
    handles[i] = pool.acquire("robot_id_overflow", pos, _make_rot(), _make_scale())
  end
  for _, h in ipairs(handles) do
    pool.release("robot_id_overflow", h)
  end

  luassert.is.equal(1, mock.destroy_calls,
    "overflow release (idle count exceeds max_idle) must destroy exactly one handle")
  end)

  it("test_prewarm_fills_idle_bucket_without_consuming_from_it", function()
  local mock = _make_mock_lifecycle()
  local pool = _load_pool_with_mock(mock)
  local pos = _make_pos(0.0, 0.0, 0.0)

  pool.prewarm("robot_id", 3, _make_rot(), _make_scale(), pos)

  luassert.is.equal(3, mock.create_calls, "prewarm must create the requested number of handles")

  local stats = pool.stats()
  local s = stats["robot_id"]
  luassert.is_not_nil(s, "stats must report robot_id bucket after prewarm")
  luassert.is.equal(3, s.idle, "prewarm must park handles in idle bucket")
  luassert.is.equal(0, s.live, "prewarm must not increment live count")
  end)

  it("test_prewarm_does_not_exceed_max_idle", function()
  local mock = _make_mock_lifecycle()
  local pool = _load_pool_with_mock(mock)
  local max_idle = require("src.config.gameplay.runtime_constants").entity_pool_max_idle
  local pos = _make_pos(0.0, 0.0, 0.0)

  pool.prewarm("robot_id", max_idle + 5, _make_rot(), _make_scale(), pos)

  luassert.is.equal(max_idle, mock.create_calls, "prewarm must not exceed max_idle")
  end)

  it("test_prewarm_does_not_create_if_idle_already_sufficient", function()
  local mock = _make_mock_lifecycle()
  local pool = _load_pool_with_mock(mock)
  local pos = _make_pos(0.0, 0.0, 0.0)

  pool.prewarm("robot_id", 2, _make_rot(), _make_scale(), pos)
  local calls_after_first = mock.create_calls
  pool.prewarm("robot_id", 2, _make_rot(), _make_scale(), pos)

  luassert.is.equal(calls_after_first, mock.create_calls,
    "second prewarm for same count must not create additional handles")
  end)

  it("test_stats_reports_live_peak_and_miss_accurately", function()
  local mock = _make_mock_lifecycle()
  local pool = _load_pool_with_mock(mock)
  local pos = _make_pos(0.0, 0.0, 0.0)

  local h1 = pool.acquire("robot_id", pos, _make_rot(), _make_scale())
  local h2 = pool.acquire("robot_id", pos, _make_rot(), _make_scale())
  pool.release("robot_id", h1)

  local stats = pool.stats()
  local s = stats["robot_id"]
  luassert.is_not_nil(s)
  luassert.is.equal(1, s.live, "live should be 1 after releasing one of two")
  luassert.is.equal(2, s.peak, "peak should track max concurrent live count")
  luassert.is.equal(2, s.miss, "miss should count cold creates")
  pool.release("robot_id", h2)
  end)

  it("test_reset_destroys_all_idle_handles", function()
  local mock = _make_mock_lifecycle()
  local pool = _load_pool_with_mock(mock)
  local pos = _make_pos(0.0, 0.0, 0.0)

  local h1 = pool.acquire("robot_id", pos, _make_rot(), _make_scale())
  local h2 = pool.acquire("robot_id", pos, _make_rot(), _make_scale())
  pool.release("robot_id", h1)
  pool.release("robot_id", h2)
  pool.reset()

  luassert.is.equal(2, mock.destroy_calls, "reset must destroy all idle handles")
  end)

  it("test_acquire_returns_nil_and_warns_on_create_failure", function()
  local mock = _make_mock_lifecycle()
  function mock.create_unit_with_scale(_unit_key, _pos, _rotation, _scale)
    mock.create_calls = mock.create_calls + 1
    return nil
  end
  local warn_count = 0
  local real_logger = require("src.foundation.log")
  local real_warn = real_logger.warn
  real_logger.warn = function(...)
    warn_count = warn_count + 1
    return real_warn(...)
  end

  local pool = _load_pool_with_mock(mock)
  local handle = pool.acquire("bad_id", _make_pos(0, 0, 0), _make_rot(), _make_scale())

  real_logger.warn = real_warn
  luassert.is_nil(handle, "acquire must return nil when create_unit_with_scale returns nil")
  luassert.is.equal(1, warn_count, "acquire must warn once on create failure")
  end)

  it("test_buckets_are_keyed_per_unit_key", function()
  local mock = _make_mock_lifecycle()
  local pool = _load_pool_with_mock(mock)
  local pos = _make_pos(0.0, 0.0, 0.0)

  local ha = pool.acquire("key_a", pos, _make_rot(), _make_scale())
  pool.release("key_a", ha)

  local hb = pool.acquire("key_b", pos, _make_rot(), _make_scale())

  luassert.is.equal(2, mock.create_calls, "key_b must not reuse key_a idle handle")
  luassert.is_not.same(ha, hb, "handles from different keys must be distinct")
  end)
end)
