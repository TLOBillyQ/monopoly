---@param blackboard Blackboard
return function(blackboard)
    local path = blackboard:get("path")
    if path then
        return true
    end
    return false
end