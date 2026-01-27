local MovementManager = {}

local DIR_TO_V3 = {
    [DIR_LEFT] = V3_LEFT,
    [DIR_RIGHT] = V3_RIGHT,
    [DIR_UP] = V3_UP,
    [DIR_DOWN] = V3_DOWN,
    left = V3_LEFT,
    right = V3_RIGHT,
    up = V3_UP,
    down = V3_DOWN,
}

function MovementManager.one_step(player_id, dir, tile_start, tile_end)
    local role = GameAPI.get_role(player_id)
    if not role then
        return
    end
    local unit = role.get_ctrl_unit()
    if not unit then
        return
    end
    local tile_s = G.tiles[tile_start]
    local tile_f = G.tiles[tile_end]
    if not (tile_s and tile_f) then
        return
    end

    local pos_s = tile_s.get_position()
    local pos_f = tile_f.get_position()
    local dist = pos_f - pos_s
    local len = dist:length()
    if len <= 0 then
        return
    end
    local time = len / MOVE_SPEED
    local v3_dir = DIR_TO_V3[dir]
    if not v3_dir then
        v3_dir = dist * (1 / len)
    end

    local target = pos_f + (unit.get_position() - pos_s)
    if LuaAPI.has_component and LuaAPI.has_component(unit, "VehicleComp") and unit.vehicle_start_move then
        unit.vehicle_start_move(v3_dir, time)
    else
        unit.start_move_to_pos_with_threshold(target, time, MOVE_THRESHOLD)
    end
end

return MovementManager
