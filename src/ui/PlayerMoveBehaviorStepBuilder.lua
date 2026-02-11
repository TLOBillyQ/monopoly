local runtime_constants = require("Config.RuntimeConstants")
local logger = require("src.core.Logger")

local step_builder = {}

local function _vec3(x, y, z)
  if math and math.Vector3 then
    return math.Vector3(x, y, z)
  end
  return { x = x, y = y, z = z }
end

local function _zero_vector()
  return _vec3(0.0, 0.0, 0.0)
end

function step_builder.resolve_tile_pos(scene, tile_index)
  local tile = scene.tiles[tile_index]
  assert(tile ~= nil and tile.get_position ~= nil, "missing tile: " .. tostring(tile_index))
  return tile.get_position()
end

local function _calc_step_vector(scene, from_index, to_index)
  local start_pos = step_builder.resolve_tile_pos(scene, from_index)
  local end_pos = step_builder.resolve_tile_pos(scene, to_index)
  local dist = end_pos - start_pos
  local len = dist:length()
  if len <= 0 then
    return _zero_vector(), 0, end_pos
  end
  return _vec3(dist.x / len, dist.y / len, dist.z / len), len, end_pos
end

local function _calc_walk_step_time(len)
  if len <= 0 then
    return 0
  end
  local speed = runtime_constants.walk_speed or 0
  if speed <= 0 then
    return 0
  end
  return len / speed
end

local function _calc_vehicle_step_time(len)
  if len <= 0 then
    return 0
  end
  local speed = runtime_constants.vehicle_speed or 0
  local accel = runtime_constants.vehicle_accel or 0
  if speed <= 0 or accel <= 0 then
    local safe_speed = speed > 0 and speed or 0.001
    return len / safe_speed
  end
  local critical_dist = (speed * speed) / accel
  if len <= critical_dist then
    return 2 * math.sqrt(len / accel)
  end
  return 2 * (speed / accel) + (len - critical_dist) / speed
end

function step_builder.is_vehicle_anim(anim_ctx)
  return anim_ctx and anim_ctx.vehicle_id ~= nil
end

function step_builder.is_vehicle_move_mode(anim_ctx)
  return anim_ctx
    and step_builder.is_vehicle_anim(anim_ctx)
    and runtime_constants.vehicle_move_api_enabled == true
    and vehicle_helper
    and vehicle_helper.forward_eca_event_move
    and true
    or false
end

function step_builder.is_vehicle_jump_mode(anim_ctx)
  return anim_ctx
    and step_builder.is_vehicle_anim(anim_ctx)
    and runtime_constants.vehicle_move_api_enabled ~= true
    and vehicle_helper
    and vehicle_helper.forward_eca_event_set_position
    and true
    or false
end

local function _calc_step_time_by_len(len, anim_ctx)
  if step_builder.is_vehicle_anim(anim_ctx) then
    return _calc_vehicle_step_time(len)
  end
  return _calc_walk_step_time(len)
end

local function _calc_step_time(scene, from_index, to_index, anim_ctx)
  local _, len = _calc_step_vector(scene, from_index, to_index)
  return _calc_step_time_by_len(len, anim_ctx)
end

function step_builder.consume_enter_delay(player_id, anim_ctx)
  if not step_builder.is_vehicle_anim(anim_ctx) then
    return 0
  end
  if not (vehicle_helper and vehicle_helper.consume_enter_delay) then
    return 0
  end
  return vehicle_helper.consume_enter_delay(player_id, anim_ctx.vehicle_id) or 0
end

function step_builder.build_steps(scene, from_index, to_index, visited, anim_ctx)
  local steps = {}
  local total = 0
  local function _push_step(step_from, step_to)
    if step_from == step_to then
      return
    end
    local dir, len, target_pos = _calc_step_vector(scene, step_from, step_to)
    local duration = _calc_step_time_by_len(len, anim_ctx)
    if duration <= 0 then
      logger.warn(
        "[Eggy] invalid bt move step duration",
        "player_id=", tostring(anim_ctx and anim_ctx.player_id),
        "from=", tostring(step_from),
        "to=", tostring(step_to),
        "len=", tostring(len),
        "walk_speed=", tostring(runtime_constants.walk_speed),
        "duration=", tostring(duration)
      )
      return
    end
    steps[#steps + 1] = {
      from = step_from,
      to = step_to,
      dir = dir,
      duration = duration,
      target_pos = target_pos,
    }
    total = total + duration
  end
  if not visited or #visited <= 1 then
    _push_step(from_index, to_index)
  else
    local step_from = from_index
    for _, step_to in ipairs(visited) do
      _push_step(step_from, step_to)
      step_from = step_to
    end
  end
  return steps, total
end

return step_builder
