require "src.runtime.Macro"
require "src.runtime.Refs"

SetTimeOut = LuaAPI.call_delay_time

RegisterCustomEvent = LuaAPI.global_register_custom_event
RegisterTriggerEvent = LuaAPI.global_register_trigger_event

UnitCustomEvent = LuaAPI.unit_register_custom_event
UnitTriggerEvent = LuaAPI.unit_register_trigger_event

TriggerCustomEvent = LuaAPI.global_send_custom_event

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

camera_helper = {
    target_role_id = 1,
}

all_roles = GameAPI.get_all_valid_roles()
ALLROLES = all_roles
