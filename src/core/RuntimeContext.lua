local runtime_constants = require("Config.RuntimeConstants")
local logger = require("src.core.Logger")
require("Config.RuntimeRefs")

local runtime_context = {}

local current_context = nil
local last_camera_target_role_id = nil
local last_camera_target_role_ok = nil

local function _build_vehicle_helper()
  local helper = {
    player_id = nil,
    vehicle_id = nil,
    move_direction = nil,
    move_time = nil,
  }

  helper.forward_eca_event_enter = function(role_id, vehicle_id)
    helper.player_id = role_id
    helper.vehicle_id = vehicle_id
    TriggerCustomEvent(runtime_constants.eca_event.vehicle.enter, {})
  end

  helper.forward_eca_event_exit = function(role_id)
    helper.player_id = role_id
    TriggerCustomEvent(runtime_constants.eca_event.vehicle.exit, {})
  end

  helper.forward_eca_event_move = function(role_id, dir, time)
    helper.player_id = role_id
    helper.move_direction = dir
    helper.move_time = time
    TriggerCustomEvent(runtime_constants.eca_event.vehicle.move, {})
  end

  helper.forward_eca_event_stop = function(role_id)
    helper.player_id = role_id
    TriggerCustomEvent(runtime_constants.eca_event.vehicle.stop, {})
  end

  return helper
end

function runtime_context.new(env)
  return {
    env = env or {},
    roles = nil,
    vehicle_helper = nil,
    camera_helper = nil,
  }
end

function runtime_context.set_current(ctx)
  current_context = ctx
  return ctx
end

function runtime_context.current()
  return current_context
end

function runtime_context.refresh_roles(ctx)
  assert(ctx ~= nil and ctx.env ~= nil, "missing runtime context")
  local game_api = ctx.env.GameAPI
  if game_api and game_api.get_all_valid_roles then
    ctx.roles = game_api.get_all_valid_roles()
  else
    ctx.roles = {}
  end
  return ctx.roles
end

function runtime_context.install_globals(ctx)
  assert(ctx ~= nil and ctx.env ~= nil, "missing runtime context")
  local env = ctx.env

  if env.GameAPI ~= nil then
    GameAPI = env.GameAPI
  end
  if env.LuaAPI ~= nil then
    LuaAPI = env.LuaAPI
  end

  assert(LuaAPI ~= nil, "missing LuaAPI")
  SetTimeOut = LuaAPI.call_delay_time
  RegisterCustomEvent = LuaAPI.global_register_custom_event
  RegisterTriggerEvent = LuaAPI.global_register_trigger_event
  UnitCustomEvent = LuaAPI.unit_register_custom_event
  UnitTriggerEvent = LuaAPI.unit_register_trigger_event
  TriggerCustomEvent = LuaAPI.global_send_custom_event

  if not ctx.vehicle_helper then
    ctx.vehicle_helper = _build_vehicle_helper()
  end
  if not ctx.camera_helper then
    ctx.camera_helper = { target_role_id = 1 }
  end

  vehicle_helper = ctx.vehicle_helper
  camera_helper = ctx.camera_helper

  if not ctx.roles then
    runtime_context.refresh_roles(ctx)
  end
  all_roles = ctx.roles
  ALLROLES = ctx.roles

  -- Export ECA helper functions for Eggy Editor
  ---@export
  ---@desc 获取执行载具命令的玩家
  ---@return Role
  function get_vehicle_player()
    local role_id = vehicle_helper.player_id or 1
    return GameAPI.get_role(role_id)
  end

  ---@export
  ---@desc 获取载具移动方向
  ---@return Vector3
  function get_vehicle_move_direction()
    return vehicle_helper.move_direction or runtime_constants.v3_left
  end

  ---@export
  ---@desc 获取载具移动时间
  ---@return Fixed
  function get_vehicle_move_time()
    return vehicle_helper.move_time or 0
  end

  ---@export
  ---@desc 获取刷载具的ID
  ---@return integer
  function get_spawn_vehicle_id()
    return vehicle_helper.vehicle_id or 4012
  end

  ---@export
  ---@desc 获取相机跟随玩家
  ---@return Role
  function get_camera_target()
    local role_id = camera_helper.target_role_id or 1
    local role = GameAPI.get_role(role_id)
    local role_ok = role ~= nil
    if role_id ~= last_camera_target_role_id or role_ok ~= last_camera_target_role_ok then
      last_camera_target_role_id = role_id
      last_camera_target_role_ok = role_ok
      logger.info(
        "[Eggy]",
        "相机目标查询:",
        "role_id",
        tostring(role_id),
        "role_ok",
        tostring(role_ok)
      )
    end
    return role
  end
end

return runtime_context
