require "src.adapters.eggy.macro"

local rad_to_deg = math.rad_to_deg or math.deg or function(radians)
    return radians * 180 / math.pi
end

local MovementManager = {}

function MovementManager.one_step(player_id, v3_dir, tile_start, tile_end)
    if not (G and G.tiles and G.unit and G.unit[player_id]) then
        return
    end

    local tile_s = G.tiles[tile_start]
    local tile_e = G.tiles[tile_end]
    if not (tile_s and tile_e and tile_s.get_position and tile_e.get_position) then
        return
    end

    local pos_s = tile_s.get_position()
    local pos_e = tile_e.get_position()
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
    if not unit.start_move_by_direction then
        return
    end
    if unit.set_direction then
        unit.set_direction(dir)
    elseif unit.set_orientation then
        local dx = dir.x
        local dz = dir.z
        if dx ~= 0 or dz ~= 0 then
            unit.set_orientation(math.Quaternion(0, rad_to_deg(math.atan2(dx, dz)), 0))
        end
    end

    unit.start_move_by_direction(dir, time)
    return time
end

return MovementManager
