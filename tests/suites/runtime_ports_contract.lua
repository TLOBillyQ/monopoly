local support = require("TestSupport")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local runtime_ports = require("src.core.RuntimePorts")
local runtime_context = require("src.core.RuntimeContext")
local runtime_install = require("src.app.bootstrap.RuntimeInstall")

local function _reset_runtime_contract_state()
  runtime_ports.reset_for_tests()
  runtime_context.set_current(nil)
end

local function _test_runtime_ports_strict_mode_requires_context()
  _reset_runtime_contract_state()
  _with_patches({
    { key = "all_roles", value = { { id = 1 } } },
    { key = "vehicle_helper", value = { id = "vehicle_global" } },
    { key = "camera_helper", value = { id = "camera_global" } },
  }, function()
    local roles = runtime_ports.resolve_roles()
    local vehicle = runtime_ports.resolve_vehicle_helper()
    local camera = runtime_ports.resolve_camera_helper()
    _assert_eq(type(roles), "table", "strict mode should always return a table")
    _assert_eq(#roles, 0, "strict mode should not read global roles by default")
    _assert_eq(vehicle, nil, "strict mode should not read global vehicle helper by default")
    _assert_eq(camera, nil, "strict mode should not read global camera helper by default")
  end)
  _reset_runtime_contract_state()
end

local function _test_runtime_ports_resolve_roles_prefers_context_over_globals()
  _reset_runtime_contract_state()
  local ctx = runtime_context.new({})
  ctx.roles = { { id = 2 } }
  ctx.vehicle_helper = { id = "vehicle_ctx" }
  ctx.camera_helper = { id = "camera_ctx" }
  runtime_context.set_current(ctx)
  _with_patches({
    { key = "all_roles", value = { { id = 1 } } },
    { key = "vehicle_helper", value = { id = "vehicle_global" } },
    { key = "camera_helper", value = { id = "camera_global" } },
  }, function()
    local roles = runtime_ports.resolve_roles()
    local vehicle = runtime_ports.resolve_vehicle_helper()
    local camera = runtime_ports.resolve_camera_helper()
    _assert_eq(roles[1].id, 2, "runtime ports should prefer context roles when context exists")
    _assert_eq(vehicle.id, "vehicle_ctx", "runtime ports should prefer context vehicle helper")
    _assert_eq(camera.id, "camera_ctx", "runtime ports should prefer context camera helper")
  end)
  _reset_runtime_contract_state()
end

local function _test_runtime_ports_legacy_fallback_is_explicit()
  _reset_runtime_contract_state()
  runtime_ports.set_legacy_global_fallback_enabled(true)
  _with_patches({
    { key = "all_roles", value = { { id = 3 } } },
    { key = "vehicle_helper", value = { id = "vehicle_global" } },
    { key = "camera_helper", value = { id = "camera_global" } },
  }, function()
    local roles = runtime_ports.resolve_roles()
    local vehicle = runtime_ports.resolve_vehicle_helper()
    local camera = runtime_ports.resolve_camera_helper()
    _assert_eq(roles[1].id, 3, "legacy mode should read global roles fallback")
    _assert_eq(vehicle.id, "vehicle_global", "legacy mode should read global vehicle helper")
    _assert_eq(camera.id, "camera_global", "legacy mode should read global camera helper")
  end)
  _reset_runtime_contract_state()
end

local function _test_runtime_install_strict_rejects_missing_context_install()
  _reset_runtime_contract_state()
  local ok, err = pcall(function()
    runtime_install.install({
      context_policy = "strict",
      skip_context_install = true,
    })
  end)
  _assert_eq(ok, false, "strict install should reject missing context")
  assert(tostring(err):find("runtime context is required", 1, true) ~= nil,
    "strict install should raise missing context error")
  _reset_runtime_contract_state()
end

local function _test_runtime_install_legacy_allows_controlled_degrade()
  _reset_runtime_contract_state()
  _with_patches({
    { key = "all_roles", value = { { id = 4 } } },
    { key = "vehicle_helper", value = { id = "vehicle_global" } },
    { key = "camera_helper", value = { id = "camera_global" } },
    { key = "GameAPI", value = { random_int = function(min) return min end } },
    { key = "SetTimeOut", value = function(_, fn) if fn then fn() end end },
  }, function()
    runtime_install.install({
      context_policy = "legacy",
      skip_context_install = true,
    })
    local roles = runtime_ports.resolve_roles()
    local vehicle = runtime_ports.resolve_vehicle_helper()
    local camera = runtime_ports.resolve_camera_helper()
    _assert_eq(runtime_ports.legacy_global_fallback_enabled(), true,
      "legacy install should enable explicit global fallback mode")
    _assert_eq(roles[1].id, 4, "legacy install should keep controlled roles fallback")
    _assert_eq(vehicle.id, "vehicle_global", "legacy install should keep controlled vehicle fallback")
    _assert_eq(camera.id, "camera_global", "legacy install should keep controlled camera fallback")
  end)
  _reset_runtime_contract_state()
end

return {
  name = "runtime_ports_contract",
  tests = {
    {
      name = "runtime_ports_strict_mode_requires_context",
      run = _test_runtime_ports_strict_mode_requires_context,
    },
    {
      name = "runtime_ports_resolve_roles_prefers_context_over_globals",
      run = _test_runtime_ports_resolve_roles_prefers_context_over_globals,
    },
    {
      name = "runtime_ports_legacy_fallback_is_explicit",
      run = _test_runtime_ports_legacy_fallback_is_explicit,
    },
    {
      name = "runtime_install_strict_rejects_missing_context_install",
      run = _test_runtime_install_strict_rejects_missing_context_install,
    },
    {
      name = "runtime_install_legacy_allows_controlled_degrade",
      run = _test_runtime_install_legacy_allows_controlled_degrade,
    },
  },
}
