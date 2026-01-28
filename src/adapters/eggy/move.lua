require "src.adapters.eggy.macro"

local MovementManager = {}

function MovementManager.one_step(player_id, v3_dir, tile_start, tile_end)
    local tile_s = G.tiles[tile_start]
    local tile_e = G.tiles[tile_end]

    local pos_s = tile_s.get_position()
    local pos_e = tile_e.get_position()
    local dist = pos_e - pos_s
    local len = dist:length()
    print("Length:", len)
    if len <= 0 then
        return
    end

    local time = len / WALK_SPEED

    local unit = G.unit[player_id]
    if unit.set_direction then
        unit.set_direction(v3_dir)
    elseif unit.set_orientation then
        local dx = v3_dir.x
        local dz = v3_dir.z
        if dx ~= 0 or dz ~= 0 then
            unit.set_orientation(math.Quaternion(0, math.rad_to_deg(math.atan2(dx, dz)), 0))
        end
    end

    unit.start_move_by_direction(v3_dir, time)
end

return MovementManager
