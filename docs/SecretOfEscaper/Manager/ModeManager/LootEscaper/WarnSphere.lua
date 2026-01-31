---警戒圈
for _, role in ipairs(ALLROLES) do
    local key = 1074028644
    local unit = role.get_ctrl_unit()
    local player = PlayerManager.find_player_by_role(role)
    local area = GameAPI.create_customtriggerspace(key, unit.get_position(), math.Quaternion(0, 0, 0),
        math.Vector3(0, 0, 0), role)
    unit.add_child(area)
    LuaAPI.global_register_trigger_event(
        {
            EVENT.ANY_LIFEENTITY_TRIGGER_SPACE,
            Enums.TriggerSpaceEventType.ENTER, area.get_id()
        },
        function(_, _, data)
            local trigger_monster = data.event_unit --[[@as LifeEntity]]
            if not trigger_monster.is_character() then
                if player.custom_data.warn_sfx then
                    GlobalAPI.destroy_sfx(player.custom_data.warn_sfx)
                    player.custom_data.warn_sfx = nil
                end
                if player.custom_data.warn_screen_sfx then
                    GlobalAPI.destroy_sfx(player.custom_data.warn_screen_sfx)
                    player.custom_data.warn_screen_sfx = nil
                end
                player.custom_data.warn_sfx = GameAPI.create_sfx_with_socket(
                    21063,
                    unit,
                    Enums.ModelSocket.socket_head,
                    0.1,
                    -1.0,
                    Enums.BindType.BIND_TYPE_ALL
                )
                player.custom_data.warn_screen_sfx = player.play_screen_sfx(20202, -1.0)
            end
        end
    )


    LuaAPI.global_register_trigger_event(
        {
            EVENT.ANY_LIFEENTITY_TRIGGER_SPACE,
            Enums.TriggerSpaceEventType.LEAVE, area.get_id()
        },
        function(_, _, data)
            local trigger_monster = data.event_unit --[[@as LifeEntity]]
            if not trigger_monster.is_character() then
                if player.custom_data.warn_sfx then
                    GlobalAPI.destroy_sfx(player.custom_data.warn_sfx)
                    player.custom_data.warn_sfx = nil
                end
                if player.custom_data.warn_screen_sfx then
                    GlobalAPI.destroy_sfx(player.custom_data.warn_screen_sfx)
                    player.custom_data.warn_screen_sfx = nil
                end
            end
        end
    )
end
