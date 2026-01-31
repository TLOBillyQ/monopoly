---@param blackboard Blackboard
return function(blackboard)
    local target = blackboard:get("target") --[[@as LifeEntity]]
    local target_last_pos = blackboard:get("target_last_pos") --[[@as Vector3?]]
    if target_last_pos then
        local distance = (target.get_position() - target_last_pos):length()
        if distance > 8.0 then
            blackboard:remove("path")
            blackboard:remove("current_index")
            blackboard:remove("target_last_pos")
            LuaAPI.global_send_custom_event("重新生成路径", {})
            return true
        end
        return false
    end
    return false
end
