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
  runtime_ports.set_legacy_fallback_policy({
    roles = true,
    role = true,
    vehicle = true,
    camera = true,
  })
  _with_patches({
    { key = "all_roles", value = { { id = 3 } } },
    { key = "vehicle_helper", value = { id = "vehicle_global" } },
    { key = "camera_helper", value = { id = "camera_global" } },
  }, function()
    local roles = runtime_ports.resolve_roles()
    local vehicle = runtime_ports.resolve_vehicle_helper()
    local camera = runtime_ports.resolve_camera_helper()
    local policy = runtime_ports.legacy_fallback_policy()
    _assert_eq(policy.roles, true, "legacy policy should enable roles fallback")
    _assert_eq(policy.role, true, "legacy policy should enable role fallback")
    _assert_eq(policy.vehicle, true, "legacy policy should enable vehicle helper fallback")
    _assert_eq(policy.camera, true, "legacy policy should enable camera helper fallback")
    _assert_eq(roles[1].id, 3, "legacy policy should read global roles fallback")
    _assert_eq(vehicle.id, "vehicle_global", "legacy policy should read global vehicle helper")
    _assert_eq(camera.id, "camera_global", "legacy policy should read global camera helper")
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

local function _test_runtime_install_legacy_defaults_to_role_only_fallback()
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
    local policy = runtime_ports.legacy_fallback_policy()
    local roles = runtime_ports.resolve_roles()
    local vehicle = runtime_ports.resolve_vehicle_helper()
    local camera = runtime_ports.resolve_camera_helper()
    _assert_eq(policy.roles, true, "legacy install should enable roles fallback by default")
    _assert_eq(policy.role, true, "legacy install should enable role fallback by default")
    _assert_eq(policy.vehicle, false, "legacy install should disable vehicle helper fallback by default")
    _assert_eq(policy.camera, false, "legacy install should disable camera helper fallback by default")
    _assert_eq(roles[1].id, 4, "legacy install should keep controlled roles fallback")
    _assert_eq(vehicle, nil, "legacy install should not enable vehicle helper fallback by default")
    _assert_eq(camera, nil, "legacy install should not enable camera helper fallback by default")
  end)
  _reset_runtime_contract_state()
end

local function _test_runtime_install_legacy_allows_helper_fallback_opt_in()
  _reset_runtime_contract_state()
  _with_patches({
    { key = "all_roles", value = { { id = 5 } } },
    { key = "vehicle_helper", value = { id = "vehicle_global" } },
    { key = "camera_helper", value = { id = "camera_global" } },
    { key = "GameAPI", value = { random_int = function(min) return min end } },
    { key = "SetTimeOut", value = function(_, fn) if fn then fn() end end },
  }, function()
    runtime_install.install({
      context_policy = "legacy",
      skip_context_install = true,
      enable_legacy_helper_fallback = true,
    })
    local policy = runtime_ports.legacy_fallback_policy()
    local roles = runtime_ports.resolve_roles()
    local vehicle = runtime_ports.resolve_vehicle_helper()
    local camera = runtime_ports.resolve_camera_helper()
    _assert_eq(policy.roles, true, "legacy opt-in should keep roles fallback enabled")
    _assert_eq(policy.role, true, "legacy opt-in should keep role fallback enabled")
    _assert_eq(policy.vehicle, true, "legacy opt-in should enable vehicle helper fallback")
    _assert_eq(policy.camera, true, "legacy opt-in should enable camera helper fallback")
    _assert_eq(roles[1].id, 5, "legacy opt-in should keep controlled roles fallback")
    _assert_eq(vehicle.id, "vehicle_global", "legacy opt-in should enable vehicle helper fallback")
    _assert_eq(camera.id, "camera_global", "legacy opt-in should enable camera helper fallback")
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
      name = "runtime_install_legacy_defaults_to_role_only_fallback",
      run = _test_runtime_install_legacy_defaults_to_role_only_fallback,
    },
    {
      name = "runtime_install_legacy_allows_helper_fallback_opt_in",
      run = _test_runtime_install_legacy_allows_helper_fallback_opt_in,
    },
  },
}
