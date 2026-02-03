require "src.runtime.Macro"


vehicle_helper = {
    player_id = nil,
    vehicle_id = nil,
    move_direction = nil,
    move_time = nil,
}

vehicle_helper.forward_eca_event_enter = function(role_id, vehicle_id)
    vehicle_helper.player_id = role_id
    vehicle_helper.vehicle_id = vehicle_id
    TriggerCustomEvent(eca_event.vehicle.enter, {})
end
vehicle_helper.forward_eca_event_exit = function(role_id)
    vehicle_helper.player_id = role_id
    TriggerCustomEvent(eca_event.vehicle.exit, {})
end

vehicle_helper.forward_eca_event_move = function(role_id, dir, time)
    vehicle_helper.player_id = role_id
    vehicle_helper.move_direction = dir
    vehicle_helper.move_time = time
    TriggerCustomEvent(eca_event.vehicle.move, {})
end

-- 不太需要，当move到时间后，就相当于stop了
vehicle_helper.forward_eca_event_stop = function(role_id)
    vehicle_helper.player_id = role_id
    TriggerCustomEvent(eca_event.vehicle.stop, {})
end

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
    return vehicle_helper.move_direction or v3_left
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
    return vehicle_helper.vehicle_id or 4001
end


camera_helper = {
    target_role_id = nil,
}

---@export
---@desc 获取相机跟随玩家
---@return Role
function get_camera_target()
    local role_id = camera_helper.target_role_id or 1
    return GameAPI.get_role(role_id)
end
