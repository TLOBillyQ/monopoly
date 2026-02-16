local runtime_constants = require("cfg.RuntimeConstants")
local logger = require("core.logger")

local editor = {}

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
    return vehicle_helper.vehicle_id or 4012
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

local function _install_camera_exports(camera_helper)
  ---@export
  ---@desc 获取相机跟随玩家
  ---@return Role
  function get_camera_target()
    local role_id = camera_helper.target_role_id or 1
    local role = GameAPI.get_role(role_id)
    return role
  end
end

function editor.install(ctx)
  assert(ctx ~= nil, "missing runtime context")
  assert(ctx.vehicle_helper ~= nil, "missing context.vehicle_helper")
  assert(ctx.camera_helper ~= nil, "missing context.camera_helper")
  _install_vehicle_exports(ctx.vehicle_helper)
  _install_camera_exports(ctx.camera_helper)
end

return editor
