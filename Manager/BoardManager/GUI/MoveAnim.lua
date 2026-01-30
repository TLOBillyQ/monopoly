require "Manager.System.Macro"

local rad_to_deg = math.rad_to_deg or math.deg or function(radians)
    return radians * 180 / math.pi
end

local MovementManager = {}

function MovementManager.one_step(player_id, v3_dir, start_tile_id, end_tile_id)
    if not (G and G.tiles and G.unit and G.unit[player_id]) then
        return
    end

    local start_tile = G.tiles[start_tile_id]
    local end_tile = G.tiles[end_tile_id]
    if not (start_tile and end_tile and start_tile.get_position and end_tile.get_position) then
        return
    end

    local pos_s = start_tile.get_position()
    local pos_e = end_tile.get_position()
    local dist = pos_e - pos_s 
    local len = dist:length()
    if len <= 0 then
        return
    end

    local time = len / WALK_SPEED
    local dir = v3_dir
    if not dir and dist.x and dist.y and dist.z and math.Vector3 then
        dir = math.Vector3(dist.x / len, dist.y / len, dist.z / len)
    end
    if not dir then
        return
    end

    local unit = G.unit[player_id]
    if not unit or not unit.start_move_by_direction then
        return
    end
    if unit.set_direction then
        unit.set_direction(dir)
    elseif unit.set_orientation then
        local dx = dir.x
        local dz = dir.z
        if dx ~= 0 or dz ~= 0 then
            local yaw_radians = 0
            if dz > 0 then
                yaw_radians = math.atan(dx / dz)
            elseif dz < 0 then
                if dx >= 0 then
                    yaw_radians = math.atan(dx / dz) + math.pi
                else
                    yaw_radians = math.atan(dx / dz) - math.pi
                end
            elseif dx > 0 then
                yaw_radians = math.pi / 2
            elseif dx < 0 then
                yaw_radians = -math.pi / 2
            end
            unit.set_orientation(math.Quaternion(0, rad_to_deg(yaw_radians), 0))
        end
    end

    unit.start_move_by_direction(dir, time)
    return time
end

return MovementManager
