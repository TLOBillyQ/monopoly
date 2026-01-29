---@param blackboard Blackboard
return function(blackboard)
    local entity = blackboard:get("entity") --[[@as Monster]]
    local distance = math.maxval
    local target = nil
    for _, role in ipairs(ALLROLES) do
        local unit = role.get_ctrl_unit()
        local player = PlayerManager.find_player_by_role(role)
        local health_system = player.health_system
        local real_distance = (unit.get_position() - entity.get_position()):length()
        if real_distance < distance and not health_system.is_dead then
            distance = real_distance
            target = unit
        end
    end
    if target == nil then
        return BT.Status.RUNNING
    else
        blackboard:set("target", target)
        return BT.Status.SUCCESS
    end
end
