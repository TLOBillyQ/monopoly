---@param blackboard Blackboard
return function(blackboard)
    local entity = blackboard:get("entity") --[[@as Monster]]
    local ability = entity.get_ability_by_slot(2)
    return not ability.is_in_cd()
end
