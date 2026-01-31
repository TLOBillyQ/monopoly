---@param blackboard Blackboard
return function(blackboard)
    local entity = blackboard:get("entity") --[[@as VengefulClown]]
    local ability = entity.get_ability_by_slot(1)
    local target = blackboard:get("target") --[[@as LifeEntity]]
    if target == nil then
        return BT.Status.FAILURE
    else
        local direction = (target.get_position() - entity.get_position())
        direction:normalize()
        entity.set_direction(direction)
        ability.begin_cast(direction)
        entity:stop_behavior()
        local temp_id = GameAPI.random_int(0, 100000000)
        ability.set_kv_by_type(Enums.ValueType.Int, "id", temp_id)
        ability.set_kv_by_type(Enums.ValueType.Character, "target", nil)
        local handler = nil --[[@as integer]]
        handler = LuaAPI.global_register_custom_event(("draw_a_knife_by_clown_%d"):format(temp_id), function()
            local damage_target = ability.get_kv_by_type(Enums.ValueType.Character, "target")

            ---有目标则扣血
            if GlobalAPI.is_not_none(damage_target) then
                local role = damage_target.get_role()
                local player = PlayerManager.find_player_by_role(role)
                player.health_system:damage(1)
            end
            LuaAPI.global_unregister_custom_event(handler)
        end)
        ---开车
        local _done_handler = nil --[[@as integer]]
        _done_handler = LuaAPI.unit_register_trigger_event(ability, { EVENT.ABILITY_CAST_END }, function()
            local _ability = entity.get_ability_by_slot(2)
            entity:start_behavior()
            if not _ability.is_in_cd() then
                LuaAPI.global_send_custom_event("进入小丑开车范围", {})
            end
            LuaAPI.unit_unregister_trigger_event(ability, _done_handler)
        end)
    end
end
