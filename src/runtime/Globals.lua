require "src.runtime.Macro"
require "src.runtime.Refs"

SetTimeOut = LuaAPI.call_delay_time

RegisterCustomEvent = LuaAPI.global_register_custom_event
RegisterTriggerEvent = LuaAPI.global_register_trigger_event

UnitCustomEvent = LuaAPI.unit_register_custom_event
UnitTriggerEvent = LuaAPI.unit_register_trigger_event

TriggerCustomEvent = LuaAPI.global_send_custom_event
all_roles = GameAPI.get_all_valid_roles()
ALLROLES = all_roles
