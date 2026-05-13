---@diagnostic disable: undefined-global, undefined-field, need-check-nil
local shared = require("spec.support.shared_support")

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
    unit_register_custom_event = function() end,
    unit_register_trigger_event = function() end,
    global_send_custom_event = function() end,
  }
end

describe("runtime_ports_contract", function()
  before_each(function()
    reset_runtime_contract_state()
  end)

  after_each(function()
    reset_runtime_contract_state()
  end)

  it("runtime_ports_strict_mode_requires_context", function()
    local camera_global = { id = "camera_global" }
    shared.with_patches({
      { key = "all_roles", value = { { id = 1 } } },
      { key = "camera_helper", value = camera_global },
    }, function()
      local roles = runtime_ports.resolve_roles()
      local camera = runtime_ports.resolve_camera_helper()
      assert.equals("table", type(roles), "strict mode should always return a table")
      assert.equals(0, #roles, "strict mode should not read global roles")
      assert.is_true(camera ~= camera_global, "strict mode should not read global camera helper")
    end, { skip_runtime_context_refresh = true })
  end)

  it("runtime_ports_resolve_roles_prefers_context_over_globals", function()
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
      assert.equals(2, roles[1].id, "runtime ports should use context roles")
      assert.equals("camera_ctx", camera.id, "runtime ports should use context camera helper")
    end, { skip_runtime_context_refresh = true })
  end)

  it("runtime_ports_legacy_apis_are_removed", function()
    assert.is_nil(runtime_ports.set_legacy_fallback_policy, "set_legacy_fallback_policy must be removed")
    assert.is_nil(runtime_ports.legacy_fallback_policy, "legacy_fallback_policy must be removed")
    assert.is_nil(runtime_ports.install_context_policy, "install_context_policy must be removed")
    assert.is_nil(runtime_ports.context_policy, "context_policy must be removed")
  end)

  it("runtime_install_rejects_removed_legacy_options", function()
    local ok_policy, err_policy = pcall(function()
      runtime_install.install({
        context_policy = "retired",
        skip_context_install = true,
      })
    end)
    assert.is_false(ok_policy, "runtime_install must reject removed context_policy option")
    assert.is_true(tostring(err_policy):find("context_policy option removed", 1, true) ~= nil,
      "runtime_install should report removed context_policy option")

    local ok_helper, err_helper = pcall(function()
      runtime_install.install({
        skip_context_install = true,
        enable_legacy_helper_fallback = true,
      })
    end)
    assert.is_false(ok_helper, "runtime_install must reject removed helper fallback option")
    assert.is_true(tostring(err_helper):find("enable_legacy_helper_fallback option removed", 1, true) ~= nil,
      "runtime_install should report removed helper fallback option")
  end)

  it("runtime_install_skip_context_install_is_allowed", function()
    local ok = pcall(function()
      runtime_install.install({
        skip_context_install = true,
      })
    end)
    assert.is_true(ok, "skip_context_install should be allowed in strict-only runtime install")
    assert.is_nil(runtime_context.current(), "skip_context_install should keep runtime context nil")
  end)

  it("runtime_install_builds_context_and_ports", function()
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
      assert.is_not_nil(ctx, "runtime_install should set runtime context")
      assert.equals(4, roles[1].id, "runtime_install should resolve roles from runtime context")
      assert.is_not_nil(camera, "runtime_install should provide camera helper from runtime context")
    end)
  end)

  it("runtime_install_survives_game_api_refresh_error", function()
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
      assert.is_true(ok, "runtime_install should ignore GameAPI role refresh errors")
      local ctx = runtime_context.current()
      assert.is_not_nil(ctx, "runtime_install should still set runtime context")
      local roles = runtime_ports.resolve_roles()
      assert.equals("table", type(roles), "runtime_ports should still resolve a table after refresh error")
      assert.equals(0, #roles, "runtime_ports should fall back to an empty role list after refresh error")
      assert.is_nil(err, "runtime_install should not return an error when refresh fails")
    end)
  end)

  it("runtime_ports_resolve_roles_refreshes_empty_context_from_game_api", function()
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
      assert.equals(1, #roles, "resolve_roles should refresh empty context roles from GameAPI")
      assert.equals(9, roles[1].id, "resolve_roles should return refreshed role id")
      assert.equals(9, ctx.roles[1].id, "resolve_roles should write refreshed roles back into context")
    end, { skip_runtime_context_refresh = true })
  end)

  it("game_factory_builds_rng_adapter_from_game_api", function()
    local calls = {}
    shared.with_patches({
      { target = GameAPI, key = "random_int", value = function(min, max)
        calls[#calls + 1] = { min = min, max = max }
        return max
      end },
    }, function()
      local game = shared.new_game({ ai = {} })
      assert.is_true(type(game.rng) == "table", "compose_game should install game.rng")
      assert.is_true(type(game.rng.next_int) == "function", "compose_game should expose rng next_int")
      local value = game.rng:next_int(2, 7)
      assert.equals(7, value, "game.rng should delegate to GameAPI.random_int")
    end, { skip_runtime_context_refresh = true })
    assert.equals(1, #calls, "game.rng should call GameAPI.random_int once")
    assert.equals(2, calls[1].min, "game.rng should forward min bound")
    assert.equals(7, calls[1].max, "game.rng should forward max bound")
  end)

  it("game_rng_works_after_runtime_ports_reset", function()
    runtime_ports.reset_for_tests()
    local game = shared.new_game({ ai = {} })
    local value = game.rng:next_int(1, 6)
    assert.is_true(type(value) == "number", "game.rng:next_int should return a number after ports reset")
    assert.is_true(value >= 1 and value <= 6, "game.rng:next_int should return value in [1, 6] after ports reset")
  end)

  it("runtime_ports_resolve_role_uses_zero_arity_get_roleid_and_id_fallback", function()
    local role_id_call_count = 0
    local role_with_strict_getter = {
      id = 11,
      get_roleid = function(arg)
        role_id_call_count = role_id_call_count + 1
        assert.is_nil(arg, "get_roleid should be called without args")
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
    assert.equals(role_with_strict_getter, resolved_by_getter, "resolve_role should match get_roleid result")
    assert.equals(1, role_id_call_count, "get_roleid should be called exactly once for resolved role")

    local resolved_by_fallback = runtime_ports.resolve_role(8)
    assert.equals(role_with_failing_getter, resolved_by_fallback,
      "resolve_role should fall back to role.id when get_roleid fails")
  end)

  it("runtime_ports_resolve_role_prefers_synthetic_actor_registry", function()
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
    assert.is_not_nil(resolved, "resolve_role should return synthetic adapter")
    assert.equals("AI1", resolved.get_name(), "resolve_role should prefer synthetic actor registry")
    assert.equals(synthetic_unit, resolved.get_ctrl_unit(), "synthetic adapter should expose ctrl_unit")
    assert.equals(synthetic_avatar_image_key, resolved.get_head_icon(),
      "synthetic adapter should expose startup avatar image key")
  end)

  it("runtime_ports_resolve_role_falls_back_to_game_api_get_role", function()
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
    assert.equals(42, requested_player_id, "resolve_role should query GameAPI.get_role when context roles miss")
    assert.equals(fallback_role, resolved, "resolve_role should fall back to GameAPI.get_role result")
  end)

  it("runtime_ports_resolve_role_returns_nil_for_missing_id_and_skips_adapterless_synthetic_actor", function()
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

    assert.is_nil(runtime_ports.resolve_role(nil), "resolve_role should early-return nil for missing player_id")
    local resolved = runtime_ports.resolve_role(77)
    assert.equals(77, requested_player_id, "resolve_role should continue to GameAPI when synthetic actor lacks adapter")
    assert.equals(fallback_role, resolved, "resolve_role should still return GameAPI fallback role")
  end)

  it("gameplay_loop_port_contract_is_grouped_and_stable", function()
    local contract = gameplay_loop_ports.describe_contract()
    assert.equals("modal,anim,ui_sync,debug,clock,state,output", table.concat(contract.group_names, ","),
      "gameplay loop port groups should stay grouped and ordered")
    assert.equals("apply_input_lock", contract.port_groups.ui_sync[1],
      "ui_sync contract should keep apply_input_lock")
    assert.equals("step_choice_timeout", contract.port_groups.ui_sync[2],
      "ui_sync contract should keep timeout step")
    assert.is_true(list_contains(contract.port_groups.ui_sync, "sync_camera_position"),
      "ui_sync contract should explicitly expose sync_camera_position")
    assert.equals("invalidate_ui_model", contract.port_groups.output[1],
      "output contract should expose invalidate_ui_model first")
    assert.equals("apply_role_control_lock", contract.port_groups.state[1],
      "state contract should expose role lock")
  end)

  it("presentation_boundary_contract_describes_seams_and_state_allowlists", function()
    local contract = presentation_ports.describe_boundary_contract()
    assert.equals("src.ui.state.runtime", contract.state_seam_modules.runtime_state,
      "presentation contract should publish runtime state canonical seam")
    assert.equals("src.ui.visual_hold", contract.state_seam_modules.landing_visual_hold,
      "presentation contract should publish landing hold canonical seam")
    assert.equals("src.ui.host_bridge", contract.state_seam_modules.host_runtime,
      "presentation contract should publish host runtime canonical seam")
    assert.is_true(list_contains(contract.import_allowlists.host_runtime, "src.ui.host_bridge"),
      "presentation contract should allow host bridge canonical path")
    assert.equals("src.app.gameplay_start", contract.state_field_allowlists.presentation_runtime[1],
      "presentation contract should pin presentation_runtime ownership")
    assert.is_true(list_contains(contract.state_field_allowlists.presentation_runtime, "src.ui.ports.anim"),
      "presentation contract should allow anim port canonical path")
    assert.equals("src.app.gameplay_start", contract.state_field_allowlists.gameplay_loop_ports[1],
      "presentation contract should pin gameplay_loop_ports ownership")
  end)
end)
