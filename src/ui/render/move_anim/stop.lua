local runtime_ports = require("src.core.ports.runtime_ports")
local debug_mod = require("src.ui.render.move_anim.debug")
local rt = require("src.ui.render.move_anim.runtime")
local seq_builder = require("src.ui.render.move_anim.sequence_builder")

local stop = {}

local function _zero_fixed()
  if math and type(math.tofixed) == "function" then
    return math.tofixed(0)
  end
  return 0
end

local function _append_stop_path(path, step)
  if step == nil then
    return path
  end
  if path == nil then
    return step
  end
  return path .. "+" .. step
end

local function _stop_unit_motion(unit)
  if unit == nil then
    return nil
  end
  if type(unit.force_stop_move) == "function" then
    unit.force_stop_move()
    return "force_stop_move"
  end
  if type(unit.stop_forced_move) == "function" then
    unit.stop_forced_move()
    return "stop_forced_move"
  end
  if type(unit.ai_command_stop_move) == "function" then
    unit.ai_command_stop_move(_zero_fixed())
    return "ai_command_stop_move"
  end
  return nil
end

local function _stop_synthetic_ai_motion(unit, enabled)
  if enabled ~= true or unit == nil then
    return nil
  end
  if type(unit.ai_command_stop_move) == "function" then
    unit.ai_command_stop_move(_zero_fixed())
    return "ai_command_stop_move"
  end
  return nil
end

local function _stop_unit_anim(unit)
  if unit == nil then
    return nil
  end
  local path = nil
  if type(unit.interrupt_multi_animation) == "function" then
    unit.interrupt_multi_animation()
    path = _append_stop_path(path, "interrupt_multi_animation")
  end
  if type(unit.stop_anim) == "function" then
    unit.stop_anim()
    path = _append_stop_path(path, "stop_anim")
  end
  if type(unit.stop_play_body_anim) == "function" then
    unit.stop_play_body_anim()
    path = _append_stop_path(path, "stop_play_body_anim")
  end
  if type(unit.stop_play_upper_anim) == "function" then
    unit.stop_play_upper_anim()
    path = _append_stop_path(path, "stop_play_upper_anim")
  end
  if type(unit.model_stop_animation) == "function" then
    unit.model_stop_animation()
    path = _append_stop_path(path, "model_stop_animation")
  end
  return path
end

local function _set_player_position(scene, player_id, target_pos, anim_ctx)
  local seat_id = seq_builder.resolve_vehicle_seat_id(anim_ctx)
  local vehicle = runtime_ports.resolve_vehicle_helper()
  if seat_id and vehicle and vehicle.emit_vehicle_set_position then
    vehicle.emit_vehicle_set_position(player_id, target_pos)
    return "emit_vehicle_set_position"
  end
  local unit = scene and scene.units_by_player_id and scene.units_by_player_id[player_id] or nil
  assert(unit ~= nil, "missing unit: " .. tostring(player_id))
  assert(unit.set_position ~= nil, "missing unit.set_position: " .. tostring(player_id))
  unit.set_position(target_pos)
  return "set_position"
end

function stop.stop_player_presentation(player_id, unit, opts)
  opts = opts or {}
  local vehicle_stop_path = nil
  if opts.stop_vehicle == true and type(opts.emit_vehicle_stop) == "function" and player_id ~= nil then
    opts.emit_vehicle_stop(player_id)
    vehicle_stop_path = "emit_vehicle_stop"
  end
  local synthetic_actor = seq_builder.is_synthetic_actor(player_id) == true
  local motion_stop_path = _stop_unit_motion(unit)
  return {
    synthetic_actor = synthetic_actor,
    ai_stop_path = _stop_synthetic_ai_motion(unit, opts.stop_synthetic_ai == true and synthetic_actor),
    vehicle_stop_path = vehicle_stop_path,
    motion_stop_path = motion_stop_path,
    anim_stop_path = _stop_unit_anim(unit),
  }
end

function stop.clear_player_token(board_scene, player_id, reason)
  if board_scene == nil or player_id == nil then
    return
  end
  local runtime_state = rt.ensure_runtime(board_scene)
  local active_token = runtime_state.active_token_by_player_id[player_id]
  local active_sequence = runtime_state.active_sequence_by_player_id[player_id]
  if active_token == nil and active_sequence == nil then
    return
  end
  runtime_state.active_token_by_player_id[player_id] = nil
  if active_sequence ~= nil then
    rt.release_sequence_lock(board_scene, player_id, active_sequence, reason or "clear_player_token")
    rt.clear_active_sequence(board_scene, player_id)
  end
  debug_mod.debug_log(
    "clear_token",
    "player_id=" .. tostring(player_id),
    "reason=" .. tostring(reason or "none"),
    "token=" .. tostring(active_token or "nil")
  )
end

function stop.has_active_stop_context(board_scene, player_id)
  if board_scene == nil or player_id == nil then
    return false
  end
  local runtime_state = rt.ensure_runtime(board_scene)
  if runtime_state.active_token_by_player_id[player_id] ~= nil then
    return true
  end
  if runtime_state.active_sequence_by_player_id[player_id] ~= nil then
    return true
  end
  return false
end

function stop.prepare_player_for_snap(board_scene, player_id, anim_ctx, reason)
  stop.clear_player_token(board_scene, player_id, reason or "teleport")
  local unit = board_scene and board_scene.units_by_player_id and board_scene.units_by_player_id[player_id] or nil
  return stop.stop_player_presentation(player_id, unit, {
    stop_vehicle = seq_builder.resolve_vehicle_seat_id(anim_ctx) ~= nil,
    emit_vehicle_stop = seq_builder.vehicle_helper_method("emit_vehicle_stop"),
    stop_synthetic_ai = true,
  })
end

function stop.snap_player_to_index(board_scene, player_id, to_index, anim_ctx, reason)
  local tile = assert(board_scene.tiles[to_index], "missing tile: " .. tostring(to_index))
  local target_pos = tile.get_position()
  _set_player_position(board_scene, player_id, target_pos, anim_ctx)
  seq_builder.publish_follow_target(anim_ctx, player_id, target_pos, reason or "play_sequence_teleport")
  debug_mod.debug_log(
    reason or "play_sequence_teleport",
    "player_id=" .. tostring(player_id),
    "seq=" .. tostring(anim_ctx and anim_ctx.seq or "nil"),
    "to=" .. tostring(to_index)
  )
  return 0
end

function stop.play_teleport(board_scene, anim_ctx)
  assert(anim_ctx ~= nil, "missing anim")
  local player_id = assert(anim_ctx.player_id, "missing player_id")
  local to_index = assert(anim_ctx.to_index, "missing to_index")
  stop.prepare_player_for_snap(board_scene, player_id, anim_ctx, "teleport")
  return stop.snap_player_to_index(board_scene, player_id, to_index, anim_ctx, "play_sequence_teleport")
end

return stop
