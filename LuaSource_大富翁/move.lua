local MovementManager = {}

function MovementManager.one_step(player_id, dir, tile_start, tile_end)
    local v3_dir = V3_LEFT
    if dir == DIR_LEFT then
        v3_dir = V3_LEFT
    elseif dir == DIR_RIGHT then
        v3_dir = V3_RIGHT
    elseif dir == DIR_UP then
        v3_dir = V3_UP
    elseif dir == DIR_DOWN then
        v3_dir = V3_DOWN
    end

    local pos_s = G.tiles[tile_start].get_position()
    local pos_f = G.tiles[tile_end].get_position()
    local dist = pos_f - pos_s
    local len = dist:length()
    local time = len / MOVE_SPEED

    local unit = GameAPI.get_role(player_id).get_ctrl_unit()
    local target = unit.get_position() + v3_dir * len
    unit.start_move_to_pos_with_threshold(target, time, MOVE_THRESHOLD)
end

return MovementManager
