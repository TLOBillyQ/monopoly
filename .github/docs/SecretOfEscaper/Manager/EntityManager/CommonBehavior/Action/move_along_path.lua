---@param blackboard Blackboard
return function(blackboard)
    if BT.Frameout.frame % 10 ~= 0 then
        return BT.Status.RUNNING
    end
    local entity = blackboard:get("entity") --[[@as Monster]]
    local target = blackboard:get("target") --[[@as LifeEntity]]
    local path = blackboard:get("path") --[[@as Vector3[] ]]
    local current_index = blackboard:get("current_index") --[[@as integer]]
    local current_pos = path[current_index]
    if current_pos then
        local direction = (current_pos - entity.get_position())
        local node_distance = direction:length()
        if node_distance < 1.5 then
            blackboard:set("current_index", current_index + 1)
        end
        direction:normalize()
        entity.start_ai()
        entity.ai_command_start_move(direction, 0.5)
        return BT.Status.RUNNING
    else
        local direction = (target.get_position() - entity.get_position())
        local length = direction:length()
        direction:normalize()
        entity.start_ai()
        entity.ai_command_start_move(direction, 0.5)
        if length < 2.5 then
            return BT.Status.SUCCESS
        end
    end
    return BT.Status.FAILURE
end
