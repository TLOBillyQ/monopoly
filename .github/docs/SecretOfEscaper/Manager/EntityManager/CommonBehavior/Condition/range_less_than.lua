---@param blackboard Blackboard
---@param params {threshold: Fixed}
return function(blackboard, params)
    local entity = blackboard:get("entity") --[[@as Monster]]
    local target = blackboard:get("target") --[[@as LifeEntity]]
    local distance = (target.get_position() - entity.get_position()):length()
    return distance < params.threshold
end
