local context_helpers = require("support.regression.runtime_context_helpers")
local runtime_context = require("core.context")
local gameplay_rules = require("cfg.GameplayRules")

local function test_runtime_context_get_vehicle_player_no_fallback()
  context_helpers.with_runtime_context_globals(function()
    local role2 = { name = "role2" }
    local game_api = {
      get_role = function(role_id)
        if role_id == 2 then
          return role2
        end
        return nil
      end,
      get_all_valid_roles = function()
        return { role2 }
      end,
    }
    context_helpers.build_runtime_context(game_api, context_helpers.mock_lua_api())
    vehicle_helper.player_id = 99
    local role = get_vehicle_player()
    assert(role == nil, "get_vehicle_player should return nil when role missing")
  end)
end

local function test_runtime_context_forward_stop_skips_invalid_role()
  context_helpers.with_runtime_context_globals(function()
    local stop_events = 0
    local game_api = {
      get_role = function(role_id)
        if role_id == 1 then
          return { id = 1 }
        end
        return nil
      end,
      get_all_valid_roles = function()
        return { { id = 1 } }
      end,
    }
    context_helpers.with_vehicle_enabled(function()
      context_helpers.build_runtime_context(game_api, context_helpers.mock_lua_api(function(event_name)
        if event_name == "stop_vehicle_forward" then
          stop_events = stop_events + 1
        end
      end))
      local invalid_ok = vehicle_helper.forward_eca_event_stop(2)
      local valid_ok = vehicle_helper.forward_eca_event_stop(1)
      assert(invalid_ok == false, "forward stop should reject invalid role")
      assert(valid_ok == true, "forward stop should allow valid role")
      assert(stop_events == 1, "forward stop should only emit event for valid role")
    end)
  end)
end

local function test_runtime_context_split_install_stages()
  context_helpers.with_runtime_context_globals(function()
    local role1 = { id = 1, get_roleid = function() return 1 end }
    local game_api = {
      get_role = function(role_id)
        if role_id == 1 then
          return role1
        end
        return nil
      end,
      get_all_valid_roles = function()
        return { role1 }
      end,
    }
    local lua_api = context_helpers.mock_lua_api()
    local ctx = runtime_context.new({
      GameAPI = game_api,
      LuaAPI = lua_api,
    })

    runtime_context.install_environment(ctx)
    assert(SetTimeOut == lua_api.call_delay_time, "install_environment should bind SetTimeOut")
    assert(type(get_vehicle_player) ~= "function", "install_environment should not export helpers")

    runtime_context.install_runtime_helpers(ctx)
    assert(vehicle_helper ~= nil, "install_runtime_helpers should expose vehicle_helper")
    assert(camera_helper ~= nil, "install_runtime_helpers should expose camera_helper")

    runtime_context.install_editor_exports(ctx)
    vehicle_helper.player_id = 1
    local role = get_vehicle_player()
    assert(role == role1, "install_editor_exports should expose get_vehicle_player")
  end)
end

local function test_runtime_context_install_environment_fails_fast()
  context_helpers.with_runtime_context_globals(function()
    local ctx = runtime_context.new({
      GameAPI = {},
      LuaAPI = {
        call_delay_time = function() end,
        global_register_custom_event = function() end,
        global_register_trigger_event = function() end,
        unit_register_custom_event = function() end,
        unit_register_trigger_event = function() end,
      },
    })
    local ok, err = pcall(function()
      runtime_context.install_environment(ctx)
    end)
    assert(ok == false, "install_environment should fail when LuaAPI is incomplete")
    assert(tostring(err):find("missing LuaAPI.global_send_custom_event") ~= nil,
      "install_environment should report missing LuaAPI.global_send_custom_event")
  end)
end


return {
  test_runtime_context_get_vehicle_player_no_fallback,
  test_runtime_context_forward_stop_skips_invalid_role,
  test_runtime_context_split_install_stages,
  test_runtime_context_install_environment_fails_fast,
}
