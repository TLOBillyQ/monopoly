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
    return time -- TODO: 确定每步等待时间
end

function movement_manager.one_step(scene, player_id, dir, from_index, to_index)
    local step_dir, time = _calc_step(scene, from_index, to_index)

    local unit = scene.units_by_player_id[player_id]
    --if unit.set_direction then
    --    unit.set_direction(step_dir)
    -- elseif unit.set_orientation then
    --     local dx = step_dir.x
    --     local dz = step_dir.z
    --     if dx ~= 0 or dz ~= 0 then
    --         local yaw_radians = 0.0
    --         if dz > 0 then
    --             yaw_radians = math.atan(dx / dz)
    --         elseif dz < 0 then
    --             if dx >= 0 then
    --                 yaw_radians = math.atan(dx / dz) + math.pi
    --             else
    --                 yaw_radians = math.atan(dx / dz) - math.pi
    --             end
    --         elseif dx > 0 then
    --             yaw_radians = math.pi / 2
    --         elseif dx < 0 then
    --             yaw_radians = -math.pi / 2
    --         end
    --         unit.set_orientation(math.Quaternion(0.0, rad_to_deg(yaw_radians), 0.0))
    --     end
    --end
   
    unit.start_move_by_direction(step_dir, time)
    return time
end

local function _resolve_direction(anim_ctx)
  if anim_ctx.direction then
    return anim_ctx.direction
  end
  if anim_ctx.steps and anim_ctx.steps < 0 then
    return runtime_constants.v3_right
  end
  if anim_ctx.steps and anim_ctx.steps > 0 then
    return runtime_constants.v3_left
  end
  return nil
end

local function _build_steps(board_scene, from_index, to_index, visited)
  local steps = {}
  local total_time = 0
  local function _push_step(step_from, step_to)
    if step_from == step_to then
      return
    end
    local delay = total_time
    local step_time = movement_manager.step_duration(board_scene, step_from, step_to)
    total_time = total_time + step_time
    steps[#steps + 1] = { from = step_from, to = step_to, delay = delay }
  end

  if not visited or #visited <= 1 then
    if from_index ~= to_index then
      _push_step(from_index, to_index)
    end
  else
    local step_from = from_index
    for i = 1, #visited do
      local step_to = visited[i]
      _push_step(step_from, step_to)
      step_from = step_to
    end
  end

  return steps, total_time
end

function movement_manager.play_sequence(board_scene, anim_ctx)
  assert(anim_ctx ~= nil, "missing anim")
  local player_id = assert(anim_ctx.player_id, "missing player_id")
  local from_index = assert(anim_ctx.from_index, "missing from_index")
  local to_index = assert(anim_ctx.to_index, "missing to_index")
  local dir = assert(_resolve_direction(anim_ctx), "missing anim.direction")
  local steps, total_time = _build_steps(board_scene, from_index, to_index, anim_ctx.visited)
  for _, step in ipairs(steps) do
    if step.delay <= 0 then
      movement_manager.one_step(board_scene, player_id, dir, step.from, step.to)
    else
      SetTimeOut(step.delay, function()
        movement_manager.one_step(board_scene, player_id, dir, step.from, step.to)
      end)
    end
  end
  return total_time
end

return movement_manager
