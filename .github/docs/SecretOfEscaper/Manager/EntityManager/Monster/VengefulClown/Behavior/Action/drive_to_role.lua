---@param blackboard Blackboard
return function(blackboard)
    local entity = blackboard:get("entity") --[[@as VengefulClown]]
    local ability = entity.get_ability_by_slot(2)
    local target = blackboard:get("target") --[[@as LifeEntity]]
    if target == nil then
        return BT.Status.FAILURE
    else
        blackboard:set("BanInterrupt", true)
        ability.set_kv_by_type(Enums.ValueType.LifeEntity, "target", target)
        SetFrameOut(10, function(frameout)
            local PathFinder = blackboard:get("PathFinder")
            local Mesh = blackboard:get("Mesh")
            local path = PathFinder.query("astar", Mesh, entity.get_position(), target.get_position()) --[[@as Vector3[]? ]]
            ability.set_kv_by_type(Enums.ValueType.ListVector3, "points", path)
        end, 3 * 4)
        ability.begin_cast()

        local collide_someone = nil
        local _break_handler = nil
        local _done_handler = nil
        collide_someone = LuaAPI.unit_register_trigger_event(
            entity.ctrl_unit,
            { EVENT.SPEC_LIFEENTITY_CONTACT_END },
            function(_, _, data)
                local contactor = data.unit2 --[[@as LifeEntity]]
                if contactor.is_character() then
                    ability.set_kv_by_type(Enums.ValueType.LifeEntity, "damage_target", contactor)
                    ability.break_cast()
                end
                LuaAPI.unit_unregister_custom_event(entity.ctrl_unit, collide_someone)
            end
        )
        _done_handler = LuaAPI.unit_register_trigger_event(ability, { EVENT.ABILITY_CAST_END }, function()
            blackboard:set("BanInterrupt", nil)
            LuaAPI.unit_unregister_trigger_event(ability, _done_handler)
            LuaAPI.unit_unregister_trigger_event(ability, _break_handler)
            LuaAPI.unit_unregister_custom_event(entity.ctrl_unit, collide_someone)
            local damage_target = ability.get_kv_by_type(Enums.ValueType.LifeEntity, "damage_target") --[[@as LifeEntity]]
            if GlobalAPI.is_not_none(damage_target) and damage_target.is_character() then
                local role = damage_target.get_role()
                local player = PlayerManager.find_player_by_role(role)
                local health_system = player.health_system
                health_system:damage(1)
            end
        end)
        _break_handler = LuaAPI.unit_register_trigger_event(ability, { EVENT.ABILITY_CAST_BREAK }, function()
            blackboard:set("BanInterrupt", nil)
            LuaAPI.unit_unregister_trigger_event(ability, _done_handler)
            LuaAPI.unit_unregister_trigger_event(ability, _break_handler)
            LuaAPI.unit_unregister_custom_event(entity.ctrl_unit, collide_someone)
            local damage_target = ability.get_kv_by_type(Enums.ValueType.LifeEntity, "damage_target") --[[@as LifeEntity]]
            if GlobalAPI.is_not_none(damage_target) and damage_target.is_character() then
                local role = damage_target.get_role()
                local player = PlayerManager.find_player_by_role(role)
                local health_system = player.health_system
                health_system:damage(1)
            end
        end)
        return BT.Status.RUNNING
    end
end
