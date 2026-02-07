local runtime_constants = require("Config.RuntimeConstants")
local logger = require("src.core.Logger")

local last_camera_target_role_id = nil
local last_camera_target_role_ok = nil

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
