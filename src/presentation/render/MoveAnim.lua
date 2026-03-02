local runtime_constants = require("Config.RuntimeConstants")
local gameplay_read_port = require("src.presentation.read_model.GameplayReadPort")
local runtime_ports = require("src.core.RuntimePorts")

local move_anim = {}

local function _zero_vector()
  if math and math.Vector3 then
    return math.Vector3(0.0, 0.0, 0.0)
  end
  return { x = 0.0, y = 0.0, z = 0.0 }
end

local function _calc_step_vector(scene, from_index, to_index)
  local start_tile = scene.tiles[from_index]
  local end_tile = scene.tiles[to_index]
  local pos_s = start_tile.get_position()
  local pos_e = end_tile.get_position()
  local dist = pos_e - pos_s
  local len = dist:length()
  if len <= 0 then
    return _zero_vector(), 0
  end
  local dir = math.Vector3(dist.x / len, dist.y / len, dist.z / len)
  return dir, len
end

local function _calc_walk_step_time(len)
  if len <= 0 then
    return 0
  end
  local walk_speed = runtime_constants.walk_speed or 0
  if walk_speed <= 0 then
    return 0
  end
  return len / walk_speed
end

local function _calc_vehicle_step_time(len)
  if len <= 0 then
    return 0
  end
  local speed = runtime_constants.vehicle_speed or 0
  local accel = runtime_constants.vehicle_accel or 0
  if accel <= 0 or speed <= 0 then
    local safe_speed = speed
    if safe_speed <= 0 then
      safe_speed = 0.001
    end
    return len / safe_speed
  end
  local critical_dist = (speed * speed) / accel
  if len <= critical_dist then
    return 2 * math.sqrt(len / accel)
  end
  return 2 * (speed / accel) + (len - critical_dist) / speed
end

local function _is_vehicle_anim(anim_ctx)
  if anim_ctx == nil then
    return false
  end
  return gameplay_read_port.resolve_vehicle_seat_id(anim_ctx.vehicle_id) ~= nil
end

local function _resolve_emit_vehicle_move(vehicle)
  if not vehicle then
    return nil
  end
  return vehicle.emit_vehicle_move
end

local function _resolve_emit_vehicle_set_position(vehicle)
  if not vehicle then
    return nil
  end
  return vehicle.emit_vehicle_set_position
end

local function _is_vehicle_move_mode(anim_ctx)
  local vehicle = runtime_ports.resolve_vehicle_helper()
  return anim_ctx
    and _is_vehicle_anim(anim_ctx)
    and runtime_constants.vehicle_move_api_enabled == true
    and vehicle
    and _resolve_emit_vehicle_move(vehicle)
    and true
    or false
end

local function _is_vehicle_jump_mode(anim_ctx)
  local vehicle = runtime_ports.resolve_vehicle_helper()
  return anim_ctx
    and _is_vehicle_anim(anim_ctx)
    and runtime_constants.vehicle_move_api_enabled ~= true
    and vehicle
    and _resolve_emit_vehicle_set_position(vehicle)
    and true
    or false
end

local function _calc_step_time(scene, from_index, to_index, anim_ctx)
  local _, len = _calc_step_vector(scene, from_index, to_index)
  if _is_vehicle_anim(anim_ctx) then
    return _calc_vehicle_step_time(len)
  end
  return _calc_walk_step_time(len)
end

function move_anim.step_duration(scene, from_index, to_index, anim_ctx)
  return _calc_step_time(scene, from_index, to_index, anim_ctx)
end

function move_anim.one_step(scene, player_id, from_index, to_index, anim_ctx)
  local step_dir, _ = _calc_step_vector(scene, from_index, to_index)
  local time = move_anim.step_duration(scene, from_index, to_index, anim_ctx)
  if time <= 0 then
    return 0
  end
  if anim_ctx and type(anim_ctx.on_step_lock) == "function" then
    local meta = { player_id = player_id, from = from_index, to = to_index }
    anim_ctx.on_step_lock(false, time, meta)
    runtime_ports.schedule(time, function()
      anim_ctx.on_step_lock(true, time, meta)
    end)
  end
  if _is_vehicle_jump_mode(anim_ctx) then
    local vehicle = runtime_ports.resolve_vehicle_helper()
    local emit_set_position = _resolve_emit_vehicle_set_position(vehicle)
    local end_tile = scene.tiles[to_index]
    local target_pos = end_tile.get_position()
    emit_set_position(player_id, target_pos)
    return time
  end
  if _is_vehicle_move_mode(anim_ctx) then
    local vehicle = runtime_ports.resolve_vehicle_helper()
    local emit_move = _resolve_emit_vehicle_move(vehicle)
    emit_move(player_id, step_dir, time)
    return time
  end
  local unit = scene.units_by_player_id[player_id]
  assert(unit ~= nil and unit.start_move_by_direction ~= nil, "missing unit.start_move_by_direction: " .. tostring(player_id))
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

local function _build_steps(board_scene, from_index, to_index, visited, anim_ctx)
  local steps = {}
  local total_time = 0
  local function _push_step(step_from, step_to)
    if step_from == step_to then
      return
    end
    local step_time = move_anim.step_duration(board_scene, step_from, step_to, anim_ctx)
    if step_time <= 0 then
      return
    end
    local delay = total_time
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

local function _consume_enter_delay(anim_ctx, player_id)
  local vehicle_id = anim_ctx and gameplay_read_port.resolve_vehicle_seat_id(anim_ctx.vehicle_id) or nil
  local vehicle = runtime_ports.resolve_vehicle_helper()
  if vehicle_id == nil then
    return 0
  end
  if not (vehicle and vehicle.consume_enter_delay) then
    return 0
  end
  return vehicle.consume_enter_delay(player_id, vehicle_id) or 0
end

function move_anim.play_sequence(board_scene, anim_ctx)
  assert(anim_ctx ~= nil, "missing anim")
  local player_id = assert(anim_ctx.player_id, "missing player_id")
  local from_index = assert(anim_ctx.from_index, "missing from_index")
  local to_index = assert(anim_ctx.to_index, "missing to_index")
  assert(_resolve_direction(anim_ctx), "missing anim.direction")
  local steps, total_time = _build_steps(board_scene, from_index, to_index, anim_ctx.visited, anim_ctx)
  local enter_delay = 0
  if #steps > 0 then
    enter_delay = _consume_enter_delay(anim_ctx, player_id)
    if enter_delay > 0 then
      total_time = total_time + enter_delay
      for _, step in ipairs(steps) do
        step.delay = step.delay + enter_delay
      end
    end
  end
  for _, step in ipairs(steps) do
    if step.delay <= 0 then
      move_anim.one_step(board_scene, player_id, step.from, step.to, anim_ctx)
    else
      runtime_ports.schedule(step.delay, function()
        move_anim.one_step(board_scene, player_id, step.from, step.to, anim_ctx)
      end)
    end
  end
  return total_time
end

return move_anim
