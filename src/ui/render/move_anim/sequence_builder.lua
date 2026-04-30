local runtime_constants = require("src.config.gameplay.runtime_constants")
local gameplay_read_port = require("src.ui.view.gameplay_read_port")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local runtime_state = require("src.ui.state.runtime")

local sequence_builder = {}

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

local function _resolve_safe_vehicle_speed(speed)
  if speed > 0 then
    return speed
  end
  return 0.001
end

local function _calc_vehicle_accel_step_time(len, speed, accel)
  local critical_dist = (speed * speed) / accel
  if len <= critical_dist then
    return 2 * math.sqrt(len / accel)
  end
  return 2 * (speed / accel) + (len - critical_dist) / speed
end

local function _calc_vehicle_step_time(len)
  if len <= 0 then
    return 0
  end
  local speed = runtime_constants.vehicle_speed or 0
  local accel = runtime_constants.vehicle_accel or 0
  if accel <= 0 or speed <= 0 then
    return len / _resolve_safe_vehicle_speed(speed)
  end
  return _calc_vehicle_accel_step_time(len, speed, accel)
end

function sequence_builder.is_vehicle_anim(anim_ctx)
  if anim_ctx == nil then
    return false
  end
  return gameplay_read_port.resolve_vehicle_seat_id(anim_ctx.vehicle_id) ~= nil
end

function sequence_builder.resolve_vehicle_seat_id(anim_ctx)
  if anim_ctx == nil then
    return nil
  end
  return gameplay_read_port.resolve_vehicle_seat_id(anim_ctx.vehicle_id)
end

function sequence_builder.vehicle_helper_method(method_name)
  local vehicle = runtime_ports.resolve_vehicle_helper()
  return vehicle and vehicle[method_name] or nil
end

local function _is_vehicle_mode(anim_ctx, move_enabled, method_name)
  if not anim_ctx or not sequence_builder.is_vehicle_anim(anim_ctx) then
    return false
  end
  if (runtime_constants.vehicle_move_api_enabled == true) ~= move_enabled then
    return false
  end
  return sequence_builder.vehicle_helper_method(method_name) ~= nil
end

function sequence_builder.is_vehicle_move_mode(anim_ctx)
  return _is_vehicle_mode(anim_ctx, true, "emit_vehicle_move")
end

function sequence_builder.is_vehicle_jump_mode(anim_ctx)
  return _is_vehicle_mode(anim_ctx, false, "emit_vehicle_set_position")
end

function sequence_builder.calc_step_vector(scene, from_index, to_index)
  return _calc_step_vector(scene, from_index, to_index)
end

function sequence_builder.calc_step_time(scene, from_index, to_index, anim_ctx)
  local _, len = _calc_step_vector(scene, from_index, to_index)
  if sequence_builder.is_vehicle_anim(anim_ctx) then
    return _calc_vehicle_step_time(len)
  end
  return _calc_walk_step_time(len)
end

function sequence_builder.resolve_role(player_id)
  if player_id == nil then
    return nil
  end
  local ok, role = pcall(runtime_ports.resolve_role, player_id)
  if not ok then
    return nil
  end
  return role
end

function sequence_builder.is_synthetic_actor(player_id)
  local role = sequence_builder.resolve_role(player_id)
  return role and role.is_synthetic_actor == true or false
end

function sequence_builder.resolve_direction(anim_ctx)
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

function sequence_builder.build_steps(board_scene, from_index, to_index, visited, anim_ctx, step_duration_fn)
  local steps = {}
  local total_time = 0
  local function _push_step(step_from, step_to)
    if step_from == step_to then
      return
    end
    local step_time = step_duration_fn(board_scene, step_from, step_to, anim_ctx)
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

function sequence_builder.consume_enter_delay(anim_ctx, player_id)
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

function sequence_builder.format_visited(visited)
  if type(visited) ~= "table" or #visited == 0 then
    return "nil"
  end
  local out = {}
  for i, value in ipairs(visited) do
    out[i] = tostring(value)
  end
  return table.concat(out, ",")
end

function sequence_builder.publish_follow_target(anim_ctx, player_id, position, source)
  local state = anim_ctx and anim_ctx.state or nil
  if state == nil or player_id == nil or position == nil then
    return false
  end
  return runtime_state.set_follow_target_position(state, player_id, position, {
    source = source,
    seq = anim_ctx and anim_ctx.seq or nil,
  })
end

return sequence_builder
