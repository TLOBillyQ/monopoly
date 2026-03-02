local support = require("TestSupport")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local runtime_ports = require("src.core.RuntimePorts")
local runtime_context = require("src.core.RuntimeContext")

local function _reset_runtime_contract_state()
  runtime_ports.reset_for_tests()
  runtime_context.set_current(nil)
end

local function _test_runtime_ports_resolve_roles_fallback_works_without_context()
  _reset_runtime_contract_state()
  _with_patches({
    { target = runtime_context, key = "current", value = function() return nil end },
    { key = "all_roles", value = { { id = 1 } } },
  }, function()
    local roles = runtime_ports.resolve_roles()
    _assert_eq(type(roles), "table", "fallback roles should resolve when context is absent")
    _assert_eq(roles[1].id, 1, "roles should fallback to all_roles when context is absent")
  end)
  _reset_runtime_contract_state()
end

local function _test_runtime_ports_resolve_roles_prefers_context_over_globals()
  _reset_runtime_contract_state()
  local ctx = runtime_context.new({})
  ctx.roles = { { id = 2 } }
  runtime_context.set_current(ctx)
  _with_patches({
    { key = "all_roles", value = { { id = 1 } } },
  }, function()
    local roles = runtime_ports.resolve_roles()
    _assert_eq(roles[1].id, 2, "runtime ports should prefer context roles when context exists")
  end)
  _reset_runtime_contract_state()
end

local function _test_runtime_ports_resolve_helpers_prefer_context_over_globals()
  _reset_runtime_contract_state()
  local ctx = runtime_context.new({})
  ctx.vehicle_helper = { id = "vehicle_ctx" }
  ctx.camera_helper = { id = "camera_ctx" }
  runtime_context.set_current(ctx)
  _with_patches({
    { key = "vehicle_helper", value = { id = "vehicle_global" } },
    { key = "camera_helper", value = { id = "camera_global" } },
  }, function()
    local vehicle = runtime_ports.resolve_vehicle_helper()
    local camera = runtime_ports.resolve_camera_helper()
    _assert_eq(vehicle.id, "vehicle_ctx", "vehicle helper should prefer context binding")
    _assert_eq(camera.id, "camera_ctx", "camera helper should prefer context binding")
  end)
  _reset_runtime_contract_state()
end

local function _test_runtime_ports_resolve_roles_falls_back_to_game_api_when_needed()
  _reset_runtime_contract_state()
  _with_patches({
    { target = runtime_context, key = "current", value = function() return nil end },
    { key = "all_roles", value = nil },
    { key = "ALLROLES", value = nil },
    { key = "GameAPI", value = {
      get_all_valid_roles = function()
        return { { id = 3 } }
      end,
    } },
  }, function()
    local roles = runtime_ports.resolve_roles()
    _assert_eq(roles[1].id, 3, "roles should fallback to GameAPI when context/global roles are missing")
  end)
  _reset_runtime_contract_state()
end

return {
  name = "runtime_ports_contract",
  tests = {
    {
      name = "runtime_ports_resolve_roles_fallback_works_without_context",
      run = _test_runtime_ports_resolve_roles_fallback_works_without_context
    },
    {
      name = "runtime_ports_resolve_roles_prefers_context_over_globals",
      run = _test_runtime_ports_resolve_roles_prefers_context_over_globals
    },
    {
      name = "runtime_ports_resolve_helpers_prefer_context_over_globals",
      run = _test_runtime_ports_resolve_helpers_prefer_context_over_globals
    },
    {
      name = "runtime_ports_resolve_roles_falls_back_to_game_api_when_needed",
      run = _test_runtime_ports_resolve_roles_falls_back_to_game_api_when_needed
    },
  },
}
