local runtime_constants = require("src.core.config.runtime_constants")
local logger = require("src.core.utils.logger")
local vehicle_catalog = require("src.core.config.vehicle_catalog")
local number_utils = require("src.core.utils.number_utils")

local runtime_editor_exports = {}
local game_api_key = "Game" .. "API"

local function _resolve_game_api(ctx)
  local env = ctx and ctx.env or nil
  return env and env[game_api_key] or nil
end

local function _resolve_synthetic_camera_target(ctx, role_id)
  local registry = ctx and ctx.synthetic_actor_registry or nil
  if not (registry and type(registry.resolve_actor) == "function") then
    return nil
  end
  local actor = registry.resolve_actor(role_id)
  if actor == nil then
    return nil
  end
  return actor.unit
end

local function _resolve_role_camera_target(ctx, role_id)
  local game_api = _resolve_game_api(ctx)
  if not (game_api and game_api.get_role) then
    return nil
  end
  local ok_role, role = pcall(game_api.get_role, role_id)
  if not ok_role or role == nil or type(role.get_ctrl_unit) ~= "function" then
    return nil
  end
  local ok_unit, unit = pcall(role.get_ctrl_unit)
  if not ok_unit then
    return nil
  end
  return unit
end

local function _install_vehicle_exports(vehicle_helper)
  ---@export
  ---@desc 获取执行载具命令的玩家
  ---@return Role
  function get_vehicle_player()
    local role_id = vehicle_helper.player_id
    local role = vehicle_helper.resolve_role and vehicle_helper.resolve_role(role_id) or nil
    if role ~= nil then
      return role
    end
    logger.warn("[Eggy]", "vehicle player unresolved", tostring(role_id))
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
    local first = vehicle_catalog.list()[1]
    return vehicle_helper.vehicle_id or (first and first.id) or 0
  end

  ---@export
  ---@desc 获取载具设置位置X
  ---@return Fixed
  function get_vehicle_set_position_x()
    local pos = vehicle_helper.set_position
    return pos and pos.x or 0
  end

  ---@export
  ---@desc 获取载具设置位置Y
  ---@return Fixed
  function get_vehicle_set_position_y()
    local pos = vehicle_helper.set_position
    return pos and pos.y or 0
  end

  ---@export
  ---@desc 获取载具设置位置Z
  ---@return Fixed
  function get_vehicle_set_position_z()
    local pos = vehicle_helper.set_position
    return pos and pos.z or 0
  end
end

local function _install_camera_exports(ctx, camera_helper)
  ---@export
  ---@desc 获取相机跟随目标单位
  ---@return Creature
  function get_camera_target()
    local role_id = number_utils.to_integer(camera_helper.target_role_id)
    if role_id == nil then
      return nil
    end
    local unit = _resolve_synthetic_camera_target(ctx, role_id)
    if unit ~= nil then
      return unit
    end
    return _resolve_role_camera_target(ctx, role_id)
  end
end

local function _install_change_skin_exports(ctx, change_skin_helper)
  ---@export
  ---@desc 获取换肤皮肤ID
  ---@return integer
  function get_skin_id()
    return number_utils.to_integer(change_skin_helper.skin_id) or 0
  end

  ---@export
  ---@desc 获取换肤目标玩家
  ---@return Role
  function get_change_skin_role()
    local role_id = number_utils.to_integer(change_skin_helper.target_role_id)
    if role_id == nil then
      return nil
    end
    local game_api = _resolve_game_api(ctx)
    if not (game_api and game_api.get_role) then
      return nil
    end
    local ok, role = pcall(game_api.get_role, role_id)
    if not ok then
      return nil
    end
    return role
  end
end

function runtime_editor_exports.install(ctx)
  assert(ctx ~= nil, "missing runtime context")
  assert(ctx.vehicle_helper ~= nil, "missing context.vehicle_helper")
  assert(ctx.camera_helper ~= nil, "missing context.camera_helper")
  assert(ctx.change_skin_helper ~= nil, "missing context.change_skin_helper")
  _install_vehicle_exports(ctx.vehicle_helper)
  _install_camera_exports(ctx, ctx.camera_helper)
  _install_change_skin_exports(ctx, ctx.change_skin_helper)
end

return runtime_editor_exports
