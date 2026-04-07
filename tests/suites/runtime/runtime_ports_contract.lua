local support = require("support.runtime_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local runtime_ports = require("src.core.ports.runtime_ports")
local runtime_context = require("src.host.context")
local runtime_install = require("src.app.host_install")
local default_ports = require("src.host.default_ports")
local gameplay_loop_ports = require("src.turn.loop.ports")
local presentation_ports = require("src.ui.ports")

local function _assert_list_contains(list, expected, msg)
  for _, value in ipairs(list or {}) do
    if value == expected then
      return
    end
  end
  error(msg or ("expected list to contain " .. tostring(expected)))
end

local function _assert_one_of(actual, expected_values, msg)
  for _, expected in ipairs(expected_values or {}) do
    if actual == expected then
      return
    end
  end
  error((msg or "unexpected value")
    .. " expected one of {" .. table.concat(expected_values or {}, ",") .. "} actual=" .. tostring(actual))
end

local function _reset_runtime_contract_state()
  runtime_ports.reset_for_tests()
  runtime_context.set_current(nil)
end

local function _set_current_runtime_context(ctx)
  runtime_context.set_current(ctx)
  runtime_ports.configure(default_ports.build(runtime_context))
end

local function _test_runtime_ports_strict_mode_requires_context()
  _reset_runtime_contract_state()
  _with_patches({
    { key = "all_roles", value = { { id = 1 } } },
    { key = "camera_helper", value = { id = "camera_global" } },
  }, function()
    local roles = runtime_ports.resolve_roles()
    local camera = runtime_ports.resolve_camera_helper()
    _assert_eq(type(roles), "table", "strict mode should always return a table")
    _assert_eq(#roles, 0, "strict mode should not read global roles")
    _assert_eq(camera, nil, "strict mode should not read global camera helper")
  end, { skip_runtime_context_refresh = true })
  _reset_runtime_contract_state()
end

local function _test_runtime_ports_resolve_roles_prefers_context_over_globals()
  _reset_runtime_contract_state()
  local ctx = runtime_context.new({})
  ctx.roles = { { id = 2 } }
  ctx.camera_helper = { id = "camera_ctx" }
  ctx.change_skin_helper = { id = "change_skin_ctx" }
  _set_current_runtime_context(ctx)
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

local function _test_runtime_install_survives_game_api_refresh_error()
  _reset_runtime_contract_state()
  _with_patches({
    {
      key = "GameAPI",
      value = {
        random_int = function(min) return min end,
        get_all_valid_roles = function()
          error("boom")
        end,
      },
    },
    { key = "LuaAPI", value = _mock_lua_api() },
  }, function()
    local ok, err = pcall(function()
      runtime_install.install()
    end)
    _assert_eq(ok, true, "runtime_install should ignore GameAPI role refresh errors")
    local ctx = runtime_context.current()
    assert(ctx ~= nil, "runtime_install should still set runtime context")
    local roles = runtime_ports.resolve_roles()
    _assert_eq(type(roles), "table", "runtime_ports should still resolve a table after refresh error")
    _assert_eq(#roles, 0, "runtime_ports should fall back to an empty role list after refresh error")
    _assert_eq(err, nil, "runtime_install should not return an error when refresh fails")
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
  _set_current_runtime_context(ctx)
  _with_patches({}, function()
    local roles = runtime_ports.resolve_roles()
    _assert_eq(#roles, 1, "resolve_roles should refresh empty context roles from GameAPI")
    _assert_eq(roles[1].id, 9, "resolve_roles should return refreshed role id")
    _assert_eq(ctx.roles[1].id, 9, "resolve_roles should write refreshed roles back into context")
  end, { skip_runtime_context_refresh = true })
  _reset_runtime_contract_state()
end

local function _test_game_factory_builds_rng_adapter_from_game_api()
  _reset_runtime_contract_state()
  local calls = {}
  _with_patches({
    { target = GameAPI, key = "random_int", value = function(min, max)
      calls[#calls + 1] = { min = min, max = max }
      return max
    end },
  }, function()
    local game = support.new_game({ ai = {} })
    assert(type(game.rng) == "table", "compose_game should install game.rng")
    assert(type(game.rng.next_int) == "function", "compose_game should expose rng next_int")
    local value = game.rng:next_int(2, 7)
    _assert_eq(value, 7, "game.rng should delegate to GameAPI.random_int")
  end, { skip_runtime_context_refresh = true })
  _assert_eq(#calls, 1, "game.rng should call GameAPI.random_int once")
  _assert_eq(calls[1].min, 2, "game.rng should forward min bound")
  _assert_eq(calls[1].max, 7, "game.rng should forward max bound")
  _reset_runtime_contract_state()
end

local function _test_game_rng_works_after_runtime_ports_reset()
  runtime_ports.reset_for_tests()
  local game = support.new_game({ ai = {} })
  local value = game.rng:next_int(1, 6)
  assert(type(value) == "number", "game.rng:next_int should return a number after ports reset")
  assert(value >= 1 and value <= 6, "game.rng:next_int should return value in [1, 6] after ports reset")
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
  _set_current_runtime_context(ctx)

  local resolved_by_getter = runtime_ports.resolve_role(7)
  _assert_eq(resolved_by_getter, role_with_strict_getter, "resolve_role should match get_roleid result")
  _assert_eq(role_id_call_count, 1, "get_roleid should be called exactly once for resolved role")

  local resolved_by_fallback = runtime_ports.resolve_role(8)
  _assert_eq(resolved_by_fallback, role_with_failing_getter, "resolve_role should fall back to role.id when get_roleid fails")
  _reset_runtime_contract_state()
end

local function _test_runtime_ports_resolve_role_prefers_synthetic_actor_registry()
  _reset_runtime_contract_state()
  local synthetic_unit = {}
  local synthetic_avatar_image_key = 1625605305
  local ctx = runtime_context.new({})
  ctx.roles = { { id = 11 } }
  ctx.synthetic_actor_registry = {
    resolve_actor = function(player_id)
      if player_id == -1 then
        return {
          adapter = {
            id = -1,
            get_roleid = function()
              return -1
            end,
            get_name = function()
              return "AI1"
            end,
            get_ctrl_unit = function()
              return synthetic_unit
            end,
            get_head_icon = function()
              return synthetic_avatar_image_key
            end,
          },
        }
      end
      return nil
    end,
  }
  _set_current_runtime_context(ctx)

  local resolved = runtime_ports.resolve_role(-1)
  assert(resolved ~= nil, "resolve_role should return synthetic adapter")
  _assert_eq(resolved.get_name(), "AI1", "resolve_role should prefer synthetic actor registry")
  _assert_eq(resolved.get_ctrl_unit(), synthetic_unit, "synthetic adapter should expose ctrl_unit")
  _assert_eq(resolved.get_head_icon(), synthetic_avatar_image_key,
    "synthetic adapter should expose startup avatar image key")
  _reset_runtime_contract_state()
end

local function _test_runtime_ports_resolve_role_falls_back_to_game_api_get_role()
  _reset_runtime_contract_state()
  local requested_player_id = nil
  local fallback_role = { id = 42 }
  local ctx = runtime_context.new({
    GameAPI = {
      get_role = function(player_id)
        requested_player_id = player_id
        if player_id == 42 then
          return fallback_role
        end
        return nil
      end,
    },
  })
  ctx.roles = {}
  _set_current_runtime_context(ctx)

  local resolved = runtime_ports.resolve_role(42)
  _assert_eq(requested_player_id, 42, "resolve_role should query GameAPI.get_role when context roles miss")
  _assert_eq(resolved, fallback_role, "resolve_role should fall back to GameAPI.get_role result")
  _reset_runtime_contract_state()
end

local function _test_runtime_ports_resolve_role_returns_nil_for_missing_id_and_skips_adapterless_synthetic_actor()
  _reset_runtime_contract_state()
  local requested_player_id = nil
  local fallback_role = { id = 77 }
  local ctx = runtime_context.new({
    GameAPI = {
      get_role = function(player_id)
        requested_player_id = player_id
        if player_id == 77 then
          return fallback_role
        end
        return nil
      end,
    },
  })
  ctx.roles = {}
  ctx.synthetic_actor_registry = {
    resolve_actor = function(player_id)
      if player_id == 77 then
        return {}
      end
      return nil
    end,
  }
  _set_current_runtime_context(ctx)

  _assert_eq(runtime_ports.resolve_role(nil), nil, "resolve_role should early-return nil for missing player_id")
  local resolved = runtime_ports.resolve_role(77)
  _assert_eq(requested_player_id, 77, "resolve_role should continue to GameAPI when synthetic actor lacks adapter")
  _assert_eq(resolved, fallback_role, "resolve_role should still return GameAPI fallback role")
  _reset_runtime_contract_state()
end

local function _test_gameplay_loop_port_contract_is_grouped_and_stable()
  local contract = gameplay_loop_ports.describe_contract()
  _assert_eq(table.concat(contract.group_names, ","), "modal,anim,ui_sync,debug,clock,state,output",
    "gameplay loop port groups should stay grouped and ordered")
  _assert_eq(contract.port_groups.ui_sync[1], "apply_input_lock", "ui_sync contract should keep apply_input_lock")
  _assert_eq(contract.port_groups.ui_sync[2], "step_choice_timeout", "ui_sync contract should keep timeout step")
  _assert_list_contains(contract.port_groups.ui_sync, "sync_camera_position",
    "ui_sync contract should explicitly expose sync_camera_position")
  _assert_eq(contract.port_groups.output[1], "invalidate_ui_model", "output contract should expose invalidate_ui_model first")
  _assert_eq(contract.port_groups.state[1], "apply_role_control_lock", "state contract should expose role lock")
end

local function _test_presentation_boundary_contract_describes_seams_and_state_allowlists()
  local contract = presentation_ports.describe_boundary_contract()
  _assert_eq(contract.state_seam_modules.runtime_state, "src.ui.state",
    "presentation contract should publish runtime state canonical seam")
  _assert_eq(contract.state_seam_modules.landing_visual_hold, "src.ui.landing_visual_hold",
    "presentation contract should publish landing hold canonical seam")
  _assert_eq(contract.state_seam_modules.host_runtime, "src.ui.host_bridge",
    "presentation contract should publish host runtime canonical seam")
  _assert_list_contains(contract.import_allowlists.host_runtime, "src.ui.host_bridge",
    "presentation contract should allow host bridge canonical path")
  _assert_eq(contract.state_field_allowlists.presentation_runtime[1], "src.app.gameplay_start",
    "presentation contract should pin presentation_runtime ownership")
  _assert_list_contains(contract.state_field_allowlists.presentation_runtime, "src.ui.ports.anim",
    "presentation contract should allow anim port canonical path")
  _assert_eq(contract.state_field_allowlists.gameplay_loop_ports[1], "src.app.gameplay_start",
    "presentation contract should pin gameplay_loop_ports ownership")
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
      name = "game_factory_builds_rng_adapter_from_game_api",
      run = _test_game_factory_builds_rng_adapter_from_game_api,
    },
    {
      name = "game_rng_works_after_runtime_ports_reset",
      run = _test_game_rng_works_after_runtime_ports_reset,
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
      name = "runtime_install_survives_game_api_refresh_error",
      run = _test_runtime_install_survives_game_api_refresh_error,
    },
    {
      name = "runtime_ports_resolve_role_uses_zero_arity_get_roleid_and_id_fallback",
      run = _test_runtime_ports_resolve_role_uses_zero_arity_get_roleid_and_id_fallback,
    },
    {
      name = "runtime_ports_resolve_role_prefers_synthetic_actor_registry",
      run = _test_runtime_ports_resolve_role_prefers_synthetic_actor_registry,
    },
    {
      name = "runtime_ports_resolve_role_falls_back_to_game_api_get_role",
      run = _test_runtime_ports_resolve_role_falls_back_to_game_api_get_role,
    },
    {
      name = "runtime_ports_resolve_role_returns_nil_for_missing_id_and_skips_adapterless_synthetic_actor",
      run = _test_runtime_ports_resolve_role_returns_nil_for_missing_id_and_skips_adapterless_synthetic_actor,
    },
    {
      name = "gameplay_loop_port_contract_is_grouped_and_stable",
      run = _test_gameplay_loop_port_contract_is_grouped_and_stable,
    },
    {
      name = "presentation_boundary_contract_describes_seams_and_state_allowlists",
      run = _test_presentation_boundary_contract_describes_seams_and_state_allowlists,
    },
  },
}
