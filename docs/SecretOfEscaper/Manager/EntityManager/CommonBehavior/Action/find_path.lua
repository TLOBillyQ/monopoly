---@param blackboard Blackboard
return function(blackboard)
    local entity = blackboard:get("entity") --[[@as Monster]]
    local target = blackboard:get("target") --[[@as LifeEntity]]
    local is_direct = true
    GameAPI.raycast_unit(entity.get_position(), target.get_position(), { 4, 8, 128, 256, 512, 1024, 32768 },
        function(_, _, _)
            is_direct = false
        end)
    if is_direct then
        local path = { target.get_position() }
        blackboard:set("path", path)
        blackboard:set("current_index", 1)
        blackboard:set("target_last_pos", target.get_position())
        return
    end
    local PathFinder = blackboard:get("PathFinder") --[[@as NavMesh.Path]]
    local Mesh = blackboard:get("Mesh") --[[@as NavMesh.Mesh]]
    local path = PathFinder.query("astar", Mesh, entity.get_position(), target.get_position()) --[[@as Vector3[]? ]]
    local entity_position = entity.get_position()
    table.insert(path, 1, entity_position + math.Vector3(0, 0.5, 0))
    path = PathFinder.simplified(path)
    table.remove(path, 1)
    if #path <= 2 then
        path = { target.get_position() }
    end
    blackboard:set("path", path)
    blackboard:set("current_index", 1)
    blackboard:set("target_last_pos", target.get_position())
    return BT.Status.SUCCESS
end
