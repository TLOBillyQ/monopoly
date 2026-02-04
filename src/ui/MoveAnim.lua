local runtime_constants = require("Config.RuntimeConstants")

local rad_to_deg = math.rad_to_deg or math.deg or function(radians)
    return radians * 180 / math.pi
end

local movement_manager = {}

local function _calc_step(scene, from_index, to_index)
    local start_tile = scene.tiles[from_index]
    local end_tile = scene.tiles[to_index]

    local pos_s = start_tile.get_position()
    local pos_e = end_tile.get_position()
    local dist = pos_e - pos_s
    local len = dist:length()
    local time = len / runtime_constants.walk_speed
    local dir = math.Vector3(dist.x / len, dist.y / len, dist.z / len)
    return dir, time
end

function movement_manager.step_duration(scene, from_index, to_index)
    local _, time = _calc_step(scene, from_index, to_index)
    return time
end

function movement_manager.one_step(scene, player_id, dir, from_index, to_index)
    local step_dir, time = _calc_step(scene, from_index, to_index)

    local unit = scene.units_by_player_id[player_id]
    if unit.set_direction then
        unit.set_direction(step_dir)
    elseif unit.set_orientation then
        local dx = step_dir.x
        local dz = step_dir.z
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

    unit.force_start_move(step_dir, time)
    return time
end

return movement_manager
