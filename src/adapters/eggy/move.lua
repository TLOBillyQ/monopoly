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


    G.unit[player_id].start_move_by_direction(v3_dir, time)
end

return MovementManager
