LootEscaper.some_one_dead = function()
    local over = true
    for _, role in ipairs(ALLROLES) do
        local player = PlayerManager.find_player_by_role(role)
        local health_system = player.health_system
        if not health_system.is_dead then
            over = false
            break
        end
    end
    if over then
        local obj = LootEscaper.LootChestManager
        for _, chest in ipairs(obj.chest_list) do
            chest:destroy()
        end
        obj.ui_tipper.text = "寻宝失败，全员阵亡"
        obj.ui_tipper.text_color = 0xff8800
        for _, role in ipairs(ALLROLES) do
            local unit = role.get_ctrl_unit()
            role.show_tips("全员阵亡，对局结束！", 3.0)
            local player = PlayerManager.find_player_by_role(role)
            for _, item in ipairs(unit.get_equipment_list_by_slot_type(Enums.EquipmentSlotType.BACKPACK)) do
                item.destroy_equipment()
            end
            player:save_data()
        end
        SetFrameOut(90, function(frameout)
            MapManager.enter_level("lobby")
        end, 1, false)
    end
end

LootEscaper.some_one_leave = function()
    local alive_players = {}
    for _, role in ipairs(ALLROLES) do
        local player = PlayerManager.find_player_by_role(role)
        local health_system = player.health_system
        if not health_system.is_dead then
            table.insert(alive_players, player)
        end
    end
    local over = true
    for _, player in ipairs(alive_players) do
        if not player.custom_data.leave then
            over = false
        end
    end
    if over then
        for _, role in ipairs(ALLROLES) do
            local unit = role.get_ctrl_unit()
            role.show_tips("撤离成功，对局结束！", 3.0)
            local player = PlayerManager.find_player_by_role(role)
            for _, ability in ipairs(unit.get_abilities()) do
                unit.remove_ability_by_key(ability.get_key())
            end
            for _, item in ipairs(unit.get_equipment_list_by_slot_type(Enums.EquipmentSlotType.BACKPACK)) do
                local code = item.get_kv_by_type(Enums.ValueType.Str, "code") --[[@as ItemCode]]
                player.inventory:append(code)
                item.destroy_equipment()
            end
            player:save_data()
        end
        SetFrameOut(90, function(frameout)
            MapManager.enter_level("lobby")
        end, 1, false)
    end
end