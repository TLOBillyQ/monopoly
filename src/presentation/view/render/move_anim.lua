local runtime_constants = require("src.core.config.runtime_constants")
local gameplay_rules = require("src.core.config.gameplay_rules")
local gameplay_read_port = require("src.presentation.model.gameplay_read_port")
local runtime_ports = require("src.core.ports.runtime_ports")
local board_feedback = require("src.presentation.view.render.board_feedback_service")
local logger = require("src.core.utils.logger")

local move_anim = {}

local function _debug_log(...)
  if gameplay_rules.move_anim_debug_log_enabled ~= true then
    return
  end
  logger.info("[MoveAnim]", ...)
end

local function _ensure_runtime(board_scene)
  if type(board_scene._move_anim_runtime) ~= "table" then
    board_scene._move_anim_runtime = {
      active_token_by_player_id = {},
    }
  end
  return board_scene._move_anim_runtime
end

local function _build_token(player_id, seq)
  return tostring(player_id) .. ":" .. tostring(seq or "no_seq")
end

local function _set_active_token(board_scene, player_id, token)
  local runtime = _ensure_runtime(board_scene)
  runtime.active_token_by_player_id[player_id] = token
  return token
end

local function _get_active_token(board_scene, player_id)
  local runtime = _ensure_runtime(board_scene)
  return runtime.active_token_by_player_id[player_id]
end

function move_anim.clear_player_token(board_scene, player_id, reason)
  if board_scene == nil or player_id == nil then
    return
  end
  local runtime = _ensure_runtime(board_scene)
  if runtime.active_token_by_player_id[player_id] == nil then
    return
  end
  runtime.active_token_by_player_id[player_id] = nil
  _debug_log(
    "clear_token",
    "player_id=" .. tostring(player_id),
    "reason=" .. tostring(reason or "none")
  )
end

local function _token_matches(board_scene, player_id, token)
  return _get_active_token(board_scene, player_id) == token
end

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

local function _vehicle_helper_method(method_name)
  local vehicle = runtime_ports.resolve_vehicle_helper()
  return vehicle and vehicle[method_name] or nil
end

local function _is_vehicle_mode(anim_ctx, move_enabled, method_name)
  return anim_ctx
    and _is_vehicle_anim(anim_ctx)
    and (runtime_constants.vehicle_move_api_enabled == true) == move_enabled
    and _vehicle_helper_method(method_name)
    and true
    or false
end

local function _is_vehicle_move_mode(anim_ctx)
  return _is_vehicle_mode(anim_ctx, true, "emit_vehicle_move")
end

local function _is_vehicle_jump_mode(anim_ctx)
  return _is_vehicle_mode(anim_ctx, false, "emit_vehicle_set_position")
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

local function _stop_unit_motion(unit)
  if unit == nil then
    return nil
  end
  if type(unit.force_stop_move) == "function" then
    unit.force_stop_move()
    return "force_stop_move"
  end
  if type(unit.ai_command_stop_move) == "function" then
    local zero = 0
    if math and type(math.tofixed) == "function" then
      zero = math.tofixed(0)
    end
    unit.ai_command_stop_move(zero)
    return "ai_command_stop_move"
  end
  return nil
end

local function _stop_unit_anim(unit)
  if unit == nil or type(unit.stop_anim) ~= "function" then
    return nil
  end
  unit.stop_anim()
  return "stop_anim"
end

local function _stop_active_sequence(board_scene, player_id, anim_ctx, token)
  if not _token_matches(board_scene, player_id, token) then
    _debug_log(
      "finish_skip_stale_token",
      "player_id=" .. tostring(player_id),
      "seq=" .. tostring(anim_ctx and anim_ctx.seq or "nil"),
      "token=" .. tostring(token)
    )
    return
  end
  local vehicle_stop_path = nil
  if _is_vehicle_anim(anim_ctx) then
    local emit_vehicle_stop = _vehicle_helper_method("emit_vehicle_stop")
    if emit_vehicle_stop then
      emit_vehicle_stop(player_id)
      vehicle_stop_path = "emit_vehicle_stop"
    end
  end
  local unit = board_scene and board_scene.units_by_player_id and board_scene.units_by_player_id[player_id] or nil
  local motion_stop_path = _stop_unit_motion(unit)
  local anim_stop_path = _stop_unit_anim(unit)
  _debug_log(
    "finish_stop",
    "player_id=" .. tostring(player_id),
    "seq=" .. tostring(anim_ctx and anim_ctx.seq or "nil"),
    "token=" .. tostring(token),
    "vehicle_stop=" .. tostring(vehicle_stop_path or "none"),
    "motion_stop=" .. tostring(motion_stop_path or "none"),
    "anim_stop=" .. tostring(anim_stop_path or "none")
  )
  move_anim.clear_player_token(board_scene, player_id, "sequence_finished")
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
    _vehicle_helper_method("emit_vehicle_set_position")(player_id, scene.tiles[to_index].get_position())
    return time
  end
  if _is_vehicle_move_mode(anim_ctx) then
    _vehicle_helper_method("emit_vehicle_move")(player_id, step_dir, time)
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

local function _format_visited(visited)
  if type(visited) ~= "table" or #visited == 0 then
    return "nil"
  end
  local out = {}
  for i, value in ipairs(visited) do
    out[i] = tostring(value)
  end
  return table.concat(out, ",")
end

function move_anim.play_sequence(board_scene, anim_ctx)
  assert(anim_ctx ~= nil, "missing anim")
  local player_id = assert(anim_ctx.player_id, "missing player_id")
  local from_index = assert(anim_ctx.from_index, "missing from_index")
  local to_index = assert(anim_ctx.to_index, "missing to_index")
  assert(_resolve_direction(anim_ctx), "missing anim.direction")
  local steps, total_time = _build_steps(board_scene, from_index, to_index, anim_ctx.visited, anim_ctx)
  local token = nil
  if total_time > 0 then
    token = _set_active_token(board_scene, player_id, _build_token(player_id, anim_ctx.seq))
  end
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
  _debug_log(
    "play_sequence_start",
    "player_id=" .. tostring(player_id),
    "seq=" .. tostring(anim_ctx.seq or "nil"),
    "from=" .. tostring(from_index),
    "to=" .. tostring(to_index),
    "step_count=" .. tostring(#steps),
    "total_time=" .. tostring(total_time),
    "visited=" .. _format_visited(anim_ctx.visited),
    "token=" .. tostring(token or "nil")
  )
  local function _run_step(step)
    if token ~= nil and not _token_matches(board_scene, player_id, token) then
      _debug_log(
        "step_skip_stale_token",
        "player_id=" .. tostring(player_id),
        "seq=" .. tostring(anim_ctx.seq or "nil"),
        "from=" .. tostring(step.from),
        "to=" .. tostring(step.to),
        "token=" .. tostring(token)
      )
      return
    end
    _debug_log(
      "step_execute",
      "player_id=" .. tostring(player_id),
      "seq=" .. tostring(anim_ctx.seq or "nil"),
      "from=" .. tostring(step.from),
      "to=" .. tostring(step.to),
      "delay=" .. tostring(step.delay),
      "step_time=" .. tostring(move_anim.step_duration(board_scene, step.from, step.to, anim_ctx)),
      "vehicle=" .. tostring(_is_vehicle_anim(anim_ctx))
    )
    if anim_ctx and anim_ctx.state then
      board_feedback.play_step_tile_sound(anim_ctx.state, player_id, step.to)
    end
    move_anim.one_step(board_scene, player_id, step.from, step.to, anim_ctx)
  end
  for _, step in ipairs(steps) do
    _debug_log(
      "step_schedule",
      "player_id=" .. tostring(player_id),
      "seq=" .. tostring(anim_ctx.seq or "nil"),
      "from=" .. tostring(step.from),
      "to=" .. tostring(step.to),
      "delay=" .. tostring(step.delay)
    )
    if step.delay <= 0 then
      _run_step(step)
    else
      runtime_ports.schedule(step.delay, function() _run_step(step) end)
    end
  end
  if token ~= nil then
    runtime_ports.schedule(total_time, function()
      _stop_active_sequence(board_scene, player_id, anim_ctx, token)
    end)
  end
  return total_time
end

return move_anim
