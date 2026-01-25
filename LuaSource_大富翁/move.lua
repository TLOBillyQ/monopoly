local move = {}

-- TIME_ONE_STEP = 1.5
-- LENTH_ONE_STEP = 10.5


TIME_ONE_STEP = 1.0
LENTH_ONE_STEP = 7.0

function move.one_step(dir, p_id)
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

    local unit = GameAPI.get_role(p_id).get_ctrl_unit()
    local pos = unit.get_position()
    local target = pos + v3_dir * LENTH_ONE_STEP
    unit.start_move_to_pos_with_threshold(target, TIME_ONE_STEP, 0.5)

    return unit
end

function move.start_to_finish(p_id, start, finish)
    local t_s = G.tiles[start]
    local t_f = G.tiles[finish]
    local unit = GameAPI.get_role(p_id).get_ctrl_unit()
    local pos_s = t_s.get_position()
    local pos_f = t_f.get_position()
    unit.set_position(pos_f)
end

return move
