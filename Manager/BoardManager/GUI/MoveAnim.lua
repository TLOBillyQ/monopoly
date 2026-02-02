require "Globals.Macro"

local rad_to_deg = math.rad_to_deg or math.deg or function(radians)
    return radians * 180 / math.pi
end

local MovementManager = {}

function MovementManager.one_step(player_id, v3_dir, start_tile_id, end_tile_id)
    local start_tile = G.tiles[start_tile_id]
    local end_tile = G.tiles[end_tile_id]

    local pos_s = start_tile.get_position()
    local pos_e = end_tile.get_position()
    local dist = pos_e - pos_s
    local len = dist:length()

    local time = len / WALK_SPEED
    local dir = v3_dir
    dir = math.Vector3(dist.x / len, dist.y / len, dist.z / len)

    local unit = G.unit[player_id]
    if unit.set_direction then
        unit.set_direction(dir)
    elseif unit.set_orientation then
        local dx = dir.x
        local dz = dir.z
        if dx ~= 0 or dz ~= 0 then
            local yaw_radians = 0.0
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
            unit.set_orientation(math.Quaternion(0.0, rad_to_deg(yaw_radians), 0.0))
        end
    end

    unit.start_move_by_direction(dir, time)
    return time
end

return MovementManager
