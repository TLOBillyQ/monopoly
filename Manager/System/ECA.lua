require "Globals.Macro"

---@export
---@desc 获取执行载具命令的玩家
---@return Role
function get_vehicle_player()
    local role_id = VehicleManager.player_id or 1
    return GameAPI.get_role(role_id)
end

---@export
---@desc 获取载具移动方向
---@return Vector3
function get_vehicle_move_direction()
    return VehicleManager.move_direction or V3_LEFT
end

---@export
---@desc 获取载具移动时间
---@return Fixed
function get_vehicle_move_time()
    return VehicleManager.move_time or 0
end

---@export
---@desc 获取刷载具的ID
---@return integer
function get_spawn_vehicle_id()
    return VehicleManager.vehicle_id or 4001
end

---@export
---@desc 被转发的界面事件
---@return string
function get_forward_ui_event()
    return UIManager.eca_event or ""
end

UIManager.forward_eca_event = function(event)
    UIManager.eca_event = event
    LuaAPI.global_send_custom_event(FORWARD_ECA_EVENT_UI, {})
end

VehicleManager = {}

VehicleManager.forward_eca_event_enter = function(role_id, vehicle_id)
    VehicleManager.player_id = role_id
    VehicleManager.vehicle_id = vehicle_id
    LuaAPI.global_send_custom_event(ECA_EVENT.VEHICLE.enter, {})
end
VehicleManager.forward_eca_event_exit = function(role_id)
    VehicleManager.player_id = role_id
    LuaAPI.global_send_custom_event(ECA_EVENT.VEHICLE.exit, {})
end

VehicleManager.forward_eca_event_move = function(role_id, dir, time)
    VehicleManager.player_id = role_id
    VehicleManager.move_direction = dir
    VehicleManager.move_time = time
    LuaAPI.global_send_custom_event(ECA_EVENT.VEHICLE.move, {})
end

-- 不太需要，当move到时间后，就相当于stop了
VehicleManager.forward_eca_event_stop = function(role_id)
    VehicleManager.player_id = role_id
    LuaAPI.global_send_custom_event(ECA_EVENT.VEHICLE.stop, {})
end

