local support = require("TestSupport")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local runtime_compat = require("src.core.RuntimeCompat")
local runtime_context = require("src.core.RuntimeContext")

local function _test_runtime_compat_fallback_works_without_context()
  runtime_compat.reset_for_tests()
  _with_patches({
    { target = runtime_context, key = "current", value = function() return nil end },
    { key = "all_roles", value = { { id = 1 } } },
  }, function()
    local roles = runtime_compat.get_roles()
    _assert_eq(type(roles), "table", "fallback roles should resolve when context is absent")
    local hits = runtime_compat.get_fallback_hits()
    _assert_eq(hits.roles, 1, "roles fallback hit should be counted")
  end)
  runtime_compat.reset_for_tests()
end

local function _test_runtime_compat_strict_context_first_blocks_global_fallback()
  runtime_compat.reset_for_tests()
  runtime_compat.configure({ strict_context_first = true })
  _with_patches({
    { target = runtime_context, key = "current", value = function() return {} end },
    { key = "all_roles", value = { { id = 1 } } },
    { key = "vehicle_helper", value = { test = true } },
    { key = "camera_helper", value = { test = true } },
  }, function()
    _assert_eq(runtime_compat.get_roles(), nil, "strict context-first should not fallback to all_roles when context exists")
    _assert_eq(runtime_compat.get_vehicle_helper(), nil,
      "strict context-first should not fallback to vehicle_helper when context exists")
    _assert_eq(runtime_compat.get_camera_helper(), nil,
      "strict context-first should not fallback to camera_helper when context exists")
    local hits = runtime_compat.get_fallback_hits()
    _assert_eq(hits.roles, 0, "roles fallback count should remain zero in strict context-first mode")
    _assert_eq(hits.vehicle_helper, 0, "vehicle fallback count should remain zero in strict context-first mode")
    _assert_eq(hits.camera_helper, 0, "camera fallback count should remain zero in strict context-first mode")
  end)
  runtime_compat.reset_for_tests()
end

local function _test_runtime_compat_default_strict_context_first_blocks_fallback_on_context_hit()
  runtime_compat.reset_for_tests()
  _with_patches({
    { target = runtime_context, key = "current", value = function()
      return {}
    end },
    { key = "all_roles", value = { { id = 1 } } },
    { key = "vehicle_helper", value = { test = true } },
    { key = "camera_helper", value = { test = true } },
  }, function()
    _assert_eq(runtime_compat.get_roles(), nil, "default strict context-first should block roles fallback when context exists")
    _assert_eq(runtime_compat.get_vehicle_helper(), nil,
      "default strict context-first should block vehicle fallback when context exists")
    _assert_eq(runtime_compat.get_camera_helper(), nil,
      "default strict context-first should block camera fallback when context exists")
    local hits = runtime_compat.get_fallback_hits()
    _assert_eq(hits.roles, 0, "roles fallback count should remain zero under default strict mode")
    _assert_eq(hits.vehicle_helper, 0, "vehicle fallback count should remain zero under default strict mode")
    _assert_eq(hits.camera_helper, 0, "camera fallback count should remain zero under default strict mode")
  end)
  runtime_compat.reset_for_tests()
end

local function _test_runtime_compat_context_hit_does_not_increment_fallback_hits()
  runtime_compat.reset_for_tests()
  _with_patches({
    { target = runtime_context, key = "current", value = function()
      return {
        roles = { { id = 2 } },
        vehicle_helper = { id = "vehicle_ctx" },
        camera_helper = { id = "camera_ctx" },
      }
    end },
    { key = "all_roles", value = { { id = 1 } } },
    { key = "vehicle_helper", value = { id = "vehicle_global" } },
    { key = "camera_helper", value = { id = "camera_global" } },
  }, function()
    local roles = runtime_compat.get_roles()
    local vehicle = runtime_compat.get_vehicle_helper()
    local camera = runtime_compat.get_camera_helper()
    _assert_eq(roles[1].id, 2, "context roles should win over global fallback")
    _assert_eq(vehicle.id, "vehicle_ctx", "context vehicle helper should win over global fallback")
    _assert_eq(camera.id, "camera_ctx", "context camera helper should win over global fallback")
    local hits = runtime_compat.get_fallback_hits()
    _assert_eq(hits.roles, 0, "roles fallback should remain zero when context hits")
    _assert_eq(hits.vehicle_helper, 0, "vehicle fallback should remain zero when context hits")
    _assert_eq(hits.camera_helper, 0, "camera fallback should remain zero when context hits")
  end)
  runtime_compat.reset_for_tests()
end

return {
  name = "runtime_compat_contract",
  tests = {
    { name = "runtime_compat_fallback_works_without_context", run = _test_runtime_compat_fallback_works_without_context },
    {
      name = "runtime_compat_strict_context_first_blocks_global_fallback",
      run = _test_runtime_compat_strict_context_first_blocks_global_fallback
    },
    {
      name = "runtime_compat_context_hit_does_not_increment_fallback_hits",
      run = _test_runtime_compat_context_hit_does_not_increment_fallback_hits
    },
    {
      name = "runtime_compat_default_strict_context_first_blocks_fallback_on_context_hit",
      run = _test_runtime_compat_default_strict_context_first_blocks_fallback_on_context_hit
    },
  },
}
