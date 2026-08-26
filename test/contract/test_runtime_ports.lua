local lu = require("luaunit")

local shared = require("test.support.shared_support")

local runtime_ports = require("src.foundation.ports.runtime_ports")
local runtime_context = require("src.host.context")
local runtime_install = require("src.app.host_install")
local default_ports = require("src.host.default_ports")
local gameplay_loop_ports = require("src.turn.loop.ports")
local presentation_ports = require("src.ui.ports")

local function reset_runtime_contract_state()
  runtime_ports.reset_for_tests()
  runtime_context.set_current(nil)
end

local function set_current_runtime_context(ctx)
  runtime_context.set_current(ctx)
  runtime_ports.configure(default_ports.build(runtime_context))
end

local function list_contains(list, expected)
  for _, value in ipairs(list or {}) do
    if value == expected then
      return true
    end
  end
  return false
end

local function mock_lua_api()
  return {
    call_delay_time = function(_, fn)
      if fn then
        fn()
      end
    end,
    global_register_custom_event = function() end,
    global_register_trigger_event = function() end,
    global_unregister_trigger_event = function() end,
    unit_register_custom_event = function() end,
    unit_register_trigger_event = function() end,
    global_send_custom_event = function() end,
  }
end

TestRuntimePorts = {}

function TestRuntimePorts:setUp()
  reset_runtime_contract_state()
end

function TestRuntimePorts:tearDown()
  reset_runtime_contract_state()
end

function TestRuntimePorts:test_runtime_ports_strict_mode_requires_context()
  local camera_global = { id = "camera_global" }
  shared.with_patches({
    { key = "all_roles", value = { { id = 1 } } },
    { key = "camera_helper", value = camera_global },
  }, function()
    local roles = runtime_ports.resolve_roles()
    local camera = runtime_ports.resolve_camera_helper()
    lu.assertEquals(type(roles), "table", "strict mode should always return a table")
    lu.assertEquals(#roles, 0, "strict mode should not read global roles")
    lu.assertTrue(camera ~= camera_global, "strict mode should not read global camera helper")
  end, { skip_runtime_context_refresh = true })
end

function TestRuntimePorts:test_runtime_ports_resolve_roles_prefers_context_over_globals()
  local ctx = runtime_context.new({})
  ctx.roles = { { id = 2 } }
  ctx.camera_helper = { id = "camera_ctx" }
  set_current_runtime_context(ctx)

  shared.with_patches({
    { key = "all_roles", value = { { id = 1 } } },
    { key = "camera_helper", value = { id = "camera_global" } },
  }, function()
    local roles = runtime_ports.resolve_roles()
    local camera = runtime_ports.resolve_camera_helper()
    lu.assertEquals(roles[1].id, 2, "runtime ports should use context roles")
    lu.assertEquals(camera.id, "camera_ctx", "runtime ports should use context camera helper")
  end, { skip_runtime_context_refresh = true })
end

function TestRuntimePorts:test_runtime_ports_legacy_apis_are_removed()
  lu.assertNil(runtime_ports.set_legacy_fallback_policy, "set_legacy_fallback_policy must be removed")
  lu.assertNil(runtime_ports.legacy_fallback_policy, "legacy_fallback_policy must be removed")
  lu.assertNil(runtime_ports.install_context_policy, "install_context_policy must be removed")
  lu.assertNil(runtime_ports.context_policy, "context_policy must be removed")
end

function TestRuntimePorts:test_runtime_install_rejects_removed_legacy_options()
  local ok_policy, err_policy = pcall(function()
    runtime_install.install({
      context_policy = "retired",
      skip_context_install = true,
    })
  end)
  lu.assertFalse(ok_policy, "runtime_install must reject removed context_policy option")
  lu.assertTrue(tostring(err_policy):find("context_policy option removed", 1, true) ~= nil,
    "runtime_install should report removed context_policy option")

  local ok_helper, err_helper = pcall(function()
    runtime_install.install({
      skip_context_install = true,
      enable_legacy_helper_fallback = true,
    })
  end)
  lu.assertFalse(ok_helper, "runtime_install must reject removed helper fallback option")
  lu.assertTrue(tostring(err_helper):find("enable_legacy_helper_fallback option removed", 1, true) ~= nil,
    "runtime_install should report removed helper fallback option")
end

function TestRuntimePorts:test_runtime_install_skip_context_install_is_allowed()
  local ok = pcall(function()
    runtime_install.install({
      skip_context_install = true,
    })
  end)
  lu.assertTrue(ok, "skip_context_install should be allowed in strict-only runtime install")
  lu.assertNil(runtime_context.current(), "skip_context_install should keep runtime context nil")
end

function TestRuntimePorts:test_runtime_install_builds_context_and_ports()
  shared.with_patches({
    {
      key = "GameAPI",
      value = {
        random_int = function(min) return min end,
        get_all_valid_roles = function()
          return { { id = 4 } }
        end,
      },
    },
    { key = "LuaAPI", value = mock_lua_api() },
  }, function()
    runtime_install.install()
    local ctx = runtime_context.current()
    local roles = runtime_ports.resolve_roles()
    local camera = runtime_ports.resolve_camera_helper()
    lu.assertNotNil(ctx, "runtime_install should set runtime context")
    lu.assertEquals(roles[1].id, 4, "runtime_install should resolve roles from runtime context")
    lu.assertNotNil(camera, "runtime_install should provide camera helper from runtime context")
  end)
end

function TestRuntimePorts:test_runtime_install_survives_game_api_refresh_error()
  shared.with_patches({
    {
      key = "GameAPI",
      value = {
        random_int = function(min) return min end,
        get_all_valid_roles = function()
          error("boom")
        end,
      },
    },
    { key = "LuaAPI", value = mock_lua_api() },
  }, function()
    local ok, err = pcall(function()
      runtime_install.install()
    end)
    lu.assertTrue(ok, "runtime_install should ignore GameAPI role refresh errors")
    local ctx = runtime_context.current()
    lu.assertNotNil(ctx, "runtime_install should still set runtime context")
    local roles = runtime_ports.resolve_roles()
    lu.assertEquals(type(roles), "table", "runtime_ports should still resolve a table after refresh error")
    lu.assertEquals(#roles, 0, "runtime_ports should fall back to an empty role list after refresh error")
    lu.assertNil(err, "runtime_install should not return an error when refresh fails")
  end)
end

function TestRuntimePorts:test_runtime_ports_resolve_roles_refreshes_empty_context_from_game_api()
  local ctx = runtime_context.new({
    GameAPI = {
      get_all_valid_roles = function()
        return { { id = 9 } }
      end,
    },
  })
  ctx.roles = {}
  set_current_runtime_context(ctx)

  shared.with_patches({}, function()
    local roles = runtime_ports.resolve_roles()
    lu.assertEquals(#roles, 1, "resolve_roles should refresh empty context roles from GameAPI")
    lu.assertEquals(roles[1].id, 9, "resolve_roles should return refreshed role id")
    lu.assertEquals(ctx.roles[1].id, 9, "resolve_roles should write refreshed roles back into context")
  end, { skip_runtime_context_refresh = true })
end

function TestRuntimePorts:test_game_factory_builds_rng_adapter_from_game_api()
  local calls = {}
  shared.with_patches({
    { target = GameAPI, key = "random_int", value = function(min, max)
      calls[#calls + 1] = { min = min, max = max }
      return max
    end },
  }, function()
    local game = shared.new_game({ ai = {} })
    lu.assertTrue(type(game.rng) == "table", "compose_game should install game.rng")
    lu.assertTrue(type(game.rng.next_int) == "function", "compose_game should expose rng next_int")
    local value = game.rng:next_int(2, 7)
    lu.assertEquals(value, 7, "game.rng should delegate to GameAPI.random_int")
  end, { skip_runtime_context_refresh = true })
  lu.assertEquals(#calls, 1, "game.rng should call GameAPI.random_int once")
  lu.assertEquals(calls[1].min, 2, "game.rng should forward min bound")
  lu.assertEquals(calls[1].max, 7, "game.rng should forward max bound")
end

function TestRuntimePorts:test_game_rng_works_after_runtime_ports_reset()
  runtime_ports.reset_for_tests()
  local game = shared.new_game({ ai = {} })
  local value = game.rng:next_int(1, 6)
  lu.assertTrue(type(value) == "number", "game.rng:next_int should return a number after ports reset")
  lu.assertTrue(value >= 1 and value <= 6, "game.rng:next_int should return value in [1, 6] after ports reset")
end

function TestRuntimePorts:test_runtime_ports_resolve_role_uses_zero_arity_get_roleid_and_id_fallback()
  local role_id_call_count = 0
  local role_with_strict_getter = {
    id = 11,
    get_roleid = function(arg)
      role_id_call_count = role_id_call_count + 1
      lu.assertNil(arg, "get_roleid should be called without args")
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
  set_current_runtime_context(ctx)

  local resolved_by_getter = runtime_ports.resolve_role(7)
  lu.assertEquals(resolved_by_getter, role_with_strict_getter, "resolve_role should match get_roleid result")
  lu.assertEquals(role_id_call_count, 1, "get_roleid should be called exactly once for resolved role")

  local resolved_by_fallback = runtime_ports.resolve_role(8)
  lu.assertEquals(resolved_by_fallback, role_with_failing_getter,
    "resolve_role should fall back to role.id when get_roleid fails")
end

function TestRuntimePorts:test_runtime_ports_resolve_role_prefers_synthetic_actor_registry()
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
  set_current_runtime_context(ctx)

  local resolved = runtime_ports.resolve_role(-1)
  lu.assertNotNil(resolved, "resolve_role should return synthetic adapter")
  lu.assertEquals(resolved.get_name(), "AI1", "resolve_role should prefer synthetic actor registry")
  lu.assertEquals(resolved.get_ctrl_unit(), synthetic_unit, "synthetic adapter should expose ctrl_unit")
  lu.assertEquals(resolved.get_head_icon(), synthetic_avatar_image_key,
    "synthetic adapter should expose startup avatar image key")
end

function TestRuntimePorts:test_runtime_ports_resolve_role_falls_back_to_game_api_get_role()
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
  set_current_runtime_context(ctx)

  local resolved = runtime_ports.resolve_role(42)
  lu.assertEquals(requested_player_id, 42, "resolve_role should query GameAPI.get_role when context roles miss")
  lu.assertEquals(resolved, fallback_role, "resolve_role should fall back to GameAPI.get_role result")
end

function TestRuntimePorts:test_runtime_ports_resolve_role_returns_nil_for_missing_id_and_skips_adapterless_synthetic_actor()
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
  set_current_runtime_context(ctx)

  lu.assertNil(runtime_ports.resolve_role(nil), "resolve_role should early-return nil for missing player_id")
  local resolved = runtime_ports.resolve_role(77)
  lu.assertEquals(requested_player_id, 77, "resolve_role should continue to GameAPI when synthetic actor lacks adapter")
  lu.assertEquals(resolved, fallback_role, "resolve_role should still return GameAPI fallback role")
end

function TestRuntimePorts:test_gameplay_loop_port_contract_is_grouped_and_stable()
  local contract = gameplay_loop_ports.describe_contract()
  lu.assertEquals(table.concat(contract.group_names, ","), "modal,anim,ui_sync,debug,clock,state,output",
    "gameplay loop port groups should stay grouped and ordered")
  lu.assertEquals(contract.port_groups.ui_sync[1], "apply_input_lock",
    "ui_sync contract should keep apply_input_lock")
  lu.assertEquals(contract.port_groups.ui_sync[2], "step_choice_timeout",
    "ui_sync contract should keep timeout step")
  lu.assertTrue(list_contains(contract.port_groups.ui_sync, "sync_camera_position"),
    "ui_sync contract should explicitly expose sync_camera_position")
  lu.assertEquals(contract.port_groups.output[1], "invalidate_ui_model",
    "output contract should expose invalidate_ui_model first")
  lu.assertEquals(contract.port_groups.state[1], "apply_role_control_lock",
    "state contract should expose role lock")
end

function TestRuntimePorts:test_presentation_boundary_contract_describes_seams_and_state_allowlists()
  local contract = presentation_ports.describe_boundary_contract()
  lu.assertEquals(contract.state_seam_modules.runtime_state, "src.ui.state.runtime",
    "presentation contract should publish runtime state canonical seam")
  lu.assertEquals(contract.state_seam_modules.visual_hold, "src.ui.visual_hold",
    "presentation contract should publish visual hold canonical seam")
  lu.assertEquals(contract.state_seam_modules.host_runtime, "src.ui.seams.host_runtime",
    "presentation contract should publish host runtime canonical seam")
  lu.assertTrue(list_contains(contract.import_allowlists.host_runtime, "src.ui.seams.host_runtime"),
    "presentation contract should allow host runtime port canonical path")
  lu.assertEquals(contract.state_field_allowlists.presentation_runtime[1], "src.app.gameplay_start",
    "presentation contract should pin presentation_runtime ownership")
  lu.assertTrue(list_contains(contract.state_field_allowlists.presentation_runtime, "src.ui.ports.anim"),
    "presentation contract should allow anim port canonical path")
  lu.assertEquals(contract.state_field_allowlists.gameplay_loop_ports[1], "src.app.gameplay_start",
    "presentation contract should pin gameplay_loop_ports ownership")
end


return TestRuntimePorts
