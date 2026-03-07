local support = require("TestSupport")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local runtime_ports = require("src.core.ports.runtime_ports")
local runtime_context = require("src.core.runtime_facade.runtime_context")
local runtime_install = require("src.app.bootstrap.runtime_install")

local function _reset_runtime_contract_state()
  runtime_ports.reset_for_tests()
  runtime_context.set_current(nil)
end

local function _test_runtime_ports_strict_mode_requires_context()
  _reset_runtime_contract_state()
  _with_patches({
    { key = "all_roles", value = { { id = 1 } } },
    { key = "camera_helper", value = { id = "camera_global" } },
    { key = "change_skin_helper", value = { id = "change_skin_global" } },
  }, function()
    local roles = runtime_ports.resolve_roles()
    local camera = runtime_ports.resolve_camera_helper()
    local change_skin = runtime_ports.resolve_change_skin_helper()
    _assert_eq(type(roles), "table", "strict mode should always return a table")
    _assert_eq(#roles, 0, "strict mode should not read global roles")
    _assert_eq(camera, nil, "strict mode should not read global camera helper")
    _assert_eq(change_skin, nil, "strict mode should not read global change_skin helper")
  end, { skip_runtime_context_refresh = true })
  _reset_runtime_contract_state()
end

local function _test_runtime_ports_resolve_roles_prefers_context_over_globals()
  _reset_runtime_contract_state()
  local ctx = runtime_context.new({})
  ctx.roles = { { id = 2 } }
  ctx.camera_helper = { id = "camera_ctx" }
  ctx.change_skin_helper = { id = "change_skin_ctx" }
  runtime_context.set_current(ctx)
  _with_patches({
    { key = "all_roles", value = { { id = 1 } } },
    { key = "camera_helper", value = { id = "camera_global" } },
    { key = "change_skin_helper", value = { id = "change_skin_global" } },
  }, function()
    local roles = runtime_ports.resolve_roles()
    local camera = runtime_ports.resolve_camera_helper()
    local change_skin = runtime_ports.resolve_change_skin_helper()
    _assert_eq(roles[1].id, 2, "runtime ports should use context roles")
    _assert_eq(camera.id, "camera_ctx", "runtime ports should use context camera helper")
    _assert_eq(change_skin.id, "change_skin_ctx", "runtime ports should use context change_skin helper")
  end, { skip_runtime_context_refresh = true })
  _reset_runtime_contract_state()
end

local function _test_runtime_ports_legacy_apis_are_removed()
  _reset_runtime_contract_state()
  _assert_eq(runtime_ports.set_legacy_fallback_policy, nil, "set_legacy_fallback_policy must be removed")
  _assert_eq(runtime_ports.legacy_fallback_policy, nil, "legacy_fallback_policy must be removed")
  _assert_eq(runtime_ports.install_context_policy, nil, "install_context_policy must be removed")
  _assert_eq(runtime_ports.context_policy, nil, "context_policy must be removed")
  _reset_runtime_contract_state()
end

local function _test_runtime_install_rejects_removed_legacy_options()
  _reset_runtime_contract_state()
  local ok_policy, err_policy = pcall(function()
    runtime_install.install({
      context_policy = "retired",
      skip_context_install = true,
    })
  end)
  _assert_eq(ok_policy, false, "runtime_install must reject removed context_policy option")
  assert(tostring(err_policy):find("context_policy option removed", 1, true) ~= nil,
    "runtime_install should report removed context_policy option")

  local ok_helper, err_helper = pcall(function()
    local opts = {
      skip_context_install = true,
    }
    opts["enable_legacy_helper_fallback"] = true
    runtime_install.install({
      skip_context_install = opts.skip_context_install,
      ["enable_legacy_helper_fallback"] = opts["enable_legacy_helper_fallback"],
    })
  end)
  _assert_eq(ok_helper, false, "runtime_install must reject removed helper fallback option")
  assert(tostring(err_helper):find("enable_legacy_helper_fallback option removed", 1, true) ~= nil,
    "runtime_install should report removed helper fallback option")
  _reset_runtime_contract_state()
end

local function _test_runtime_install_skip_context_install_is_allowed()
  _reset_runtime_contract_state()
  local ok = pcall(function()
    runtime_install.install({
      skip_context_install = true,
    })
  end)
  _assert_eq(ok, true, "skip_context_install should be allowed in strict-only runtime install")
  _assert_eq(runtime_context.current(), nil, "skip_context_install should keep runtime context nil")
  _reset_runtime_contract_state()
end

local function _mock_lua_api()
  return {
    call_delay_time = function(_, fn)
      if fn then
        fn()
      end
    end,
    global_register_custom_event = function() end,
    global_register_trigger_event = function() end,
    unit_register_custom_event = function() end,
    unit_register_trigger_event = function() end,
    global_send_custom_event = function() end,
  }
end

local function _test_runtime_install_builds_context_and_ports()
  _reset_runtime_contract_state()
  _with_patches({
    {
      key = "GameAPI",
      value = {
        random_int = function(min) return min end,
        get_all_valid_roles = function()
          return { { id = 4 } }
        end,
      },
    },
    { key = "LuaAPI", value = _mock_lua_api() },
  }, function()
    runtime_install.install()
    local ctx = runtime_context.current()
    local roles = runtime_ports.resolve_roles()
    local camera = runtime_ports.resolve_camera_helper()
    local change_skin = runtime_ports.resolve_change_skin_helper()
    assert(ctx ~= nil, "runtime_install should set runtime context")
    _assert_eq(roles[1].id, 4, "runtime_install should resolve roles from runtime context")
    assert(camera ~= nil, "runtime_install should provide camera helper from runtime context")
    assert(change_skin ~= nil, "runtime_install should provide change skin helper from runtime context")
  end)
  _reset_runtime_contract_state()
end

local function _test_runtime_ports_resolve_roles_refreshes_empty_context_from_game_api()
  _reset_runtime_contract_state()
  local ctx = runtime_context.new({
    GameAPI = {
      get_all_valid_roles = function()
        return { { id = 9 } }
      end,
    },
  })
  ctx.roles = {}
  runtime_context.set_current(ctx)
  _with_patches({}, function()
    local roles = runtime_ports.resolve_roles()
    _assert_eq(#roles, 1, "resolve_roles should refresh empty context roles from GameAPI")
    _assert_eq(roles[1].id, 9, "resolve_roles should return refreshed role id")
    _assert_eq(ctx.roles[1].id, 9, "resolve_roles should write refreshed roles back into context")
  end, { skip_runtime_context_refresh = true })
  _reset_runtime_contract_state()
end

local function _test_runtime_ports_resolve_role_uses_zero_arity_get_roleid_and_id_fallback()
  _reset_runtime_contract_state()
  local role_id_call_count = 0
  local role_with_strict_getter = {
    id = 11,
    get_roleid = function(arg)
      role_id_call_count = role_id_call_count + 1
      assert(arg == nil, "get_roleid should be called without args")
      return 7
    end,
  }
  local role_with_failing_getter = {
    id = 8,
    get_roleid = function()
      error("get_roleid failure")
    end,
  }

  local ctx = runtime_context.new({})
  ctx.roles = { role_with_strict_getter, role_with_failing_getter }
  runtime_context.set_current(ctx)

  local resolved_by_getter = runtime_ports.resolve_role(7)
  _assert_eq(resolved_by_getter, role_with_strict_getter, "resolve_role should match get_roleid result")
  _assert_eq(role_id_call_count, 1, "get_roleid should be called exactly once for resolved role")

  local resolved_by_fallback = runtime_ports.resolve_role(8)
  _assert_eq(resolved_by_fallback, role_with_failing_getter, "resolve_role should fall back to role.id when get_roleid fails")
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
      name = "runtime_ports_resolve_roles_refreshes_empty_context_from_game_api",
      run = _test_runtime_ports_resolve_roles_refreshes_empty_context_from_game_api,
    },
    {
      name = "runtime_ports_legacy_apis_are_removed",
      run = _test_runtime_ports_legacy_apis_are_removed,
    },
    {
      name = "runtime_install_rejects_removed_legacy_options",
      run = _test_runtime_install_rejects_removed_legacy_options,
    },
    {
      name = "runtime_install_skip_context_install_is_allowed",
      run = _test_runtime_install_skip_context_install_is_allowed,
    },
    {
      name = "runtime_install_builds_context_and_ports",
      run = _test_runtime_install_builds_context_and_ports,
    },
    {
      name = "runtime_ports_resolve_role_uses_zero_arity_get_roleid_and_id_fallback",
      run = _test_runtime_ports_resolve_role_uses_zero_arity_get_roleid_and_id_fallback,
    },
  },
}
