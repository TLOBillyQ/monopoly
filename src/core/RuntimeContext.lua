local runtime_constants = require("Config.RuntimeConstants")
local logger = require("src.core.Logger")
require("Config.RuntimeRefs")

local runtime_context = {}

local current_context = nil
local last_camera_target_role_id = nil
local last_camera_target_role_ok = nil

local function _build_vehicle_helper()
  local function _safe_get_role(role_id)
    if role_id == nil then
      return nil
    end
    if not (GameAPI and GameAPI.get_role) then
      return nil
    end
    local ok, role = pcall(GameAPI.get_role, role_id)
    if not ok then
      return nil
    end
    return role
  end

  local function _first_valid_role()
    local roles = all_roles
    if type(roles) == "table" then
      for _, role in ipairs(roles) do
        if role ~= nil then
          return role
        end
      end
    end
    if GameAPI and GameAPI.get_all_valid_roles then
      local ok, valid_roles = pcall(GameAPI.get_all_valid_roles)
      if ok and type(valid_roles) == "table" then
        for _, role in ipairs(valid_roles) do
          if role ~= nil then
            return role
          end
        end
      end
    end
    for role_id = 1, 8 do
      local role = _safe_get_role(role_id)
      if role ~= nil then
        return role
      end
    end
    return nil
  end

  local helper = {
    player_id = nil,
    vehicle_id = nil,
    move_direction = nil,
    move_time = nil,
    set_position = nil,
    active_vehicle_by_player = {},
    needs_enter_wait_by_player = {},
  }

  helper.resolve_role = function(role_id)
    return _safe_get_role(role_id)
  end

  helper.resolve_any_role = function()
    return _first_valid_role()
  end

  helper.forward_eca_event_enter = function(role_id, vehicle_id)
    helper.player_id = role_id
    helper.vehicle_id = vehicle_id
    if role_id ~= nil then
      helper.active_vehicle_by_player[role_id] = vehicle_id
      helper.needs_enter_wait_by_player[role_id] = true
    end
    TriggerCustomEvent(runtime_constants.eca_event.vehicle.enter, {})
  end

  helper.forward_eca_event_exit = function(role_id)
    helper.player_id = role_id
    if role_id ~= nil then
      helper.active_vehicle_by_player[role_id] = nil
      helper.needs_enter_wait_by_player[role_id] = nil
    end
    TriggerCustomEvent(runtime_constants.eca_event.vehicle.exit, {})
  end

  helper.forward_eca_event_move = function(role_id, dir, time)
    helper.player_id = role_id
    helper.move_direction = dir
    helper.move_time = time
    TriggerCustomEvent(runtime_constants.eca_event.vehicle.move, {})
  end

  helper.forward_eca_event_stop = function(role_id)
    local role = helper.resolve_role(role_id)
    if role == nil then
      logger.warn("[Eggy]", "skip vehicle stop: invalid role_id", tostring(role_id))
      return false
    end
    helper.player_id = role_id
    TriggerCustomEvent(runtime_constants.eca_event.vehicle.stop, {})
    return true
  end

  helper.forward_eca_event_set_position = function(role_id, pos)
    helper.player_id = role_id
    helper.set_position = pos
    TriggerCustomEvent(runtime_constants.eca_event.vehicle.set_position, {})
  end

  helper.consume_enter_delay = function(role_id, vehicle_id)
    if role_id == nil or vehicle_id == nil then
      return 0
    end
    local active_vehicle = helper.active_vehicle_by_player[role_id]
    if active_vehicle ~= vehicle_id then
      helper.forward_eca_event_enter(role_id, vehicle_id)
    end
    if helper.needs_enter_wait_by_player[role_id] then
      helper.needs_enter_wait_by_player[role_id] = nil
      return runtime_constants.vehicle_enter_delay or 0
    end
    return 0
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
    local role_id = vehicle_helper.player_id
    local role = vehicle_helper.resolve_role and vehicle_helper.resolve_role(role_id) or nil
    if role ~= nil then
      return role
    end
    local fallback_role = vehicle_helper.resolve_any_role and vehicle_helper.resolve_any_role() or nil
    if fallback_role ~= nil then
      if role_id ~= nil then
        logger.warn("[Eggy]", "vehicle player unresolved, fallback role used", tostring(role_id))
      end
      return fallback_role
    end
    logger.warn("[Eggy]", "vehicle player unresolved and no fallback role", tostring(role_id))
    return nil
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
  ---@desc 获取载具位置设置目标X
  ---@return Fixed
  function get_vehicle_set_position_x()
    local pos = vehicle_helper.set_position
    return pos and pos.x or 0
  end

  ---@export
  ---@desc 获取载具位置设置目标Y
  ---@return Fixed
  function get_vehicle_set_position_y()
    local pos = vehicle_helper.set_position
    return pos and pos.y or 0
  end

  ---@export
  ---@desc 获取载具位置设置目标Z
  ---@return Fixed
  function get_vehicle_set_position_z()
    local pos = vehicle_helper.set_position
    return pos and pos.z or 0
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
