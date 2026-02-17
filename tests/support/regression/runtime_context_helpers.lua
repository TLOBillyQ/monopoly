local support = require("support.regression_support")

local runtime_context = require("core.context")
local gameplay_rules = require("cfg.GameplayRules")

local M = {}

local function mock_lua_api(send_custom_event)
  return {
    call_delay_time = function() end,
    global_register_custom_event = function() end,
    global_register_trigger_event = function() end,
    unit_register_custom_event = function() end,
    unit_register_trigger_event = function() end,
    global_send_custom_event = send_custom_event or function() end,
  }
end

local function with_runtime_context_globals(fn)
  support.with_patches({
    { key = "GameAPI", value = nil },
    { key = "LuaAPI", value = nil },
    { key = "SetTimeOut", value = nil },
    { key = "RegisterCustomEvent", value = nil },
    { key = "RegisterTriggerEvent", value = nil },
    { key = "UnitCustomEvent", value = nil },
    { key = "UnitTriggerEvent", value = nil },
    { key = "TriggerCustomEvent", value = nil },
    { key = "vehicle_helper", value = nil },
    { key = "camera_helper", value = nil },
    { key = "all_roles", value = nil },
    { key = "ALLROLES", value = nil },
    { key = "get_vehicle_player", value = nil },
    { key = "get_vehicle_move_direction", value = nil },
    { key = "get_vehicle_move_time", value = nil },
    { key = "get_spawn_vehicle_id", value = nil },
    { key = "get_vehicle_set_position_x", value = nil },
    { key = "get_vehicle_set_position_y", value = nil },
    { key = "get_vehicle_set_position_z", value = nil },
    { key = "get_camera_target", value = nil },
  }, fn)
end

local function with_timestamp_stub(fn)
  local now = 0
  local game_api = GameAPI or {}
  return support.with_patches({
    { key = "GameAPI", value = game_api },
    { target = game_api, key = "get_timestamp", value = function()
      now = now + 1
      return now
    end },
    { target = game_api, key = "get_timestamp_diff", value = function(a, b)
      return a - b
    end },
  }, fn)
end

local function with_vehicle_enabled(fn)
  support.with_patches({
    { target = gameplay_rules, key = "vehicle_enabled", value = true },
  }, fn)
end

local function build_runtime_context(game_api, lua_api)
  local ctx = runtime_context.new({
    GameAPI = game_api,
    LuaAPI = lua_api,
  })
  runtime_context.install_globals(ctx)
  return ctx
end

M.mock_lua_api = mock_lua_api
M.with_runtime_context_globals = with_runtime_context_globals
M.with_timestamp_stub = with_timestamp_stub
M.with_vehicle_enabled = with_vehicle_enabled
M.build_runtime_context = build_runtime_context

return M
