local leave_space_key = 2067396094
local leave_space = GameAPI.get_unit(leave_space_key) --[[@as CustomTriggerSpace]]
LuaAPI.global_register_trigger_event(
{ EVENT.ANY_LIFEENTITY_TRIGGER_SPACE, Enums.TriggerSpaceEventType.ENTER, leave_space.get_id() }, function(_, _, data)
    if not LootEscaper.could_leave then
        return
    end
    local unit = data.event_unit --[[@as Character]]
    local role = unit.get_role()
    local player = PlayerManager.find_player_by_role(role)
    local ability = unit.add_ability_to_slot(2, 1073774700) --撤离
    LuaAPI.unit_register_trigger_event(ability, { EVENT.ABILITY_CAST_BEGIN }, function()
        player.show_tips("恭喜你成功撤离，等待队友撤离！", 3.0)
        player.enter_watch_mode(false, false)
        player.custom_data.leave = true
        LootEscaper.some_one_leave()
        for _, item in ipairs(unit.get_equipment_list_by_slot_type(Enums.EquipmentSlotType.BACKPACK)) do
            local code = item.get_kv_by_type(Enums.ValueType.Str, "code") --[[@as ItemCode]]
            player.inventory:append(code)
            item.destroy_equipment()
        end
        player:save_data()
    end)
end)
LuaAPI.global_register_trigger_event(
{ EVENT.ANY_LIFEENTITY_TRIGGER_SPACE, Enums.TriggerSpaceEventType.LEAVE, leave_space.get_id() }, function(_, _, data)
    local unit = data.event_unit --[[@as Character]]
    unit.remove_ability_by_key(1073774700) --撤离
end)
