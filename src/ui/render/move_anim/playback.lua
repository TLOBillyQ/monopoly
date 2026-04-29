local runtime_ports = require("src.core.ports.runtime_ports")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local board_feedback = require("src.ui.render.board_feedback.service")
local debug_mod = require("src.ui.render.move_anim.debug")
local rt = require("src.ui.render.move_anim.runtime")
local seq_builder = require("src.ui.render.move_anim.sequence_builder")
local stop = require("src.ui.render.move_anim.stop")

local playback = {}

local function _should_skip_stop_active_sequence(board_scene, player_id, anim_ctx, token)
  if rt.token_matches(board_scene, player_id, token) then
    return false
  end
  debug_mod.debug_log(
    "finish_skip_stale_token",
    "player_id=" .. tostring(player_id),
    "seq=" .. tostring(anim_ctx and anim_ctx.seq or "nil"),
    "token=" .. tostring(token)
  )
  return true
end

function playback.step_duration(scene, from_index, to_index, anim_ctx)
  return seq_builder.calc_step_time(scene, from_index, to_index, anim_ctx)
end

function playback.one_step(scene, player_id, from_index, to_index, anim_ctx)
  local step_dir, _ = seq_builder.calc_step_vector(scene, from_index, to_index)
  local time = playback.step_duration(scene, from_index, to_index, anim_ctx)
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
  if seq_builder.is_vehicle_jump_mode(anim_ctx) then
    local target_pos = scene.tiles[to_index].get_position()
    seq_builder.vehicle_helper_method("emit_vehicle_set_position")(player_id, target_pos)
    seq_builder.publish_follow_target(anim_ctx, player_id, target_pos, "move_anim_vehicle_jump")
    return time
  end
  if seq_builder.is_vehicle_move_mode(anim_ctx) then
    local target_pos = scene.tiles[to_index].get_position()
    seq_builder.vehicle_helper_method("emit_vehicle_move")(player_id, step_dir, time)
    seq_builder.publish_follow_target(anim_ctx, player_id, target_pos, "move_anim_vehicle_move")
    return time
  end
  local unit = scene.units_by_player_id[player_id]
  assert(unit ~= nil, "missing unit: " .. tostring(player_id))
  assert(unit.start_move_by_direction ~= nil, "missing unit.start_move_by_direction: " .. tostring(player_id))
  unit.start_move_by_direction(step_dir, time)
  seq_builder.publish_follow_target(anim_ctx, player_id, scene.tiles[to_index].get_position(), "move_anim_step")
  return time
end

local function _stop_active_sequence(board_scene, player_id, anim_ctx, token)
  if _should_skip_stop_active_sequence(board_scene, player_id, anim_ctx, token) then
    return
  end
  local unit = board_scene and board_scene.units_by_player_id and board_scene.units_by_player_id[player_id] or nil
  local stop_result = stop.stop_player_presentation(player_id, unit, {
    stop_vehicle = seq_builder.is_vehicle_anim(anim_ctx),
    emit_vehicle_stop = seq_builder.vehicle_helper_method("emit_vehicle_stop"),
    stop_synthetic_ai = true,
  })
  local active_sequence = rt.get_active_sequence(board_scene, player_id)
  debug_mod.debug_log(
    "finish_stop",
    "player_id=" .. tostring(player_id),
    "seq=" .. tostring(anim_ctx and anim_ctx.seq or "nil"),
    "token=" .. tostring(token),
    "vehicle_stop=" .. tostring(stop_result.vehicle_stop_path or "none"),
    "motion_stop=" .. tostring(stop_result.motion_stop_path or "none"),
    "anim_stop=" .. tostring(stop_result.anim_stop_path or "none")
  )
  rt.release_sequence_lock(board_scene, player_id, active_sequence, "sequence_finished")
  stop.clear_player_token(board_scene, player_id, "sequence_finished")
end

function playback.play_sequence(board_scene, anim_ctx, anim_ref)
  local self_ref = anim_ref or playback
  assert(anim_ctx ~= nil, "missing anim")
  local player_id = assert(anim_ctx.player_id, "missing player_id")
  local from_index = assert(anim_ctx.from_index, "missing from_index")
  local to_index = assert(anim_ctx.to_index, "missing to_index")
  assert(seq_builder.resolve_direction(anim_ctx), "missing anim.direction")
  local steps, total_time = seq_builder.build_steps(
    board_scene, from_index, to_index, anim_ctx.visited, anim_ctx, self_ref.step_duration
  )
  local token = nil
  if #steps > 0 then
    local enter_delay = seq_builder.consume_enter_delay(anim_ctx, player_id)
    if enter_delay > 0 then
      total_time = total_time + enter_delay
      for _, step in ipairs(steps) do
        step.delay = step.delay + enter_delay
      end
    end
  end
  if total_time > 0
    and not seq_builder.is_vehicle_anim(anim_ctx) then
    local unit = board_scene and board_scene.units_by_player_id
      and board_scene.units_by_player_id[player_id] or nil
    if unit and unit.add_modifier_by_key then
      local modifier = unit.add_modifier_by_key(runtime_constants.speed_boost_modifier_key, {})
      if modifier and modifier.set_remain_duration then
        modifier.set_remain_duration(total_time + 0.5)
      end
    end
  end
  if total_time > 0 then
    token = rt.build_token(player_id, anim_ctx.seq)
    rt.set_active_token(board_scene, player_id, token)
    local entry = {
      token = token,
      player_id = player_id,
      from_index = from_index,
      to_index = to_index,
      seq = anim_ctx.seq,
      total_time = total_time,
      anim_ctx = anim_ctx,
      lock_released = false,
    }
    rt.set_active_sequence(board_scene, player_id, entry)
    if type(anim_ctx.on_sequence_lock) == "function" then
      anim_ctx.on_sequence_lock(false, total_time, rt.sequence_meta(entry))
    end
  end
  debug_mod.debug_log(
    "play_sequence_start",
    "player_id=" .. tostring(player_id),
    "seq=" .. tostring(anim_ctx.seq or "nil"),
    "from=" .. tostring(from_index),
    "to=" .. tostring(to_index),
    "step_count=" .. tostring(#steps),
    "total_time=" .. tostring(total_time),
    "visited=" .. seq_builder.format_visited(anim_ctx.visited),
    "token=" .. tostring(token or "nil")
  )
  local function _run_step(step)
    if token ~= nil and not rt.token_matches(board_scene, player_id, token) then
      debug_mod.debug_log(
        "step_skip_stale_token",
        "player_id=" .. tostring(player_id),
        "seq=" .. tostring(anim_ctx.seq or "nil"),
        "from=" .. tostring(step.from),
        "to=" .. tostring(step.to),
        "token=" .. tostring(token)
      )
      return
    end
    debug_mod.debug_log(
      "step_execute",
      "player_id=" .. tostring(player_id),
      "seq=" .. tostring(anim_ctx.seq or "nil"),
      "from=" .. tostring(step.from),
      "to=" .. tostring(step.to),
      "delay=" .. tostring(step.delay),
      "step_time=" .. tostring(self_ref.step_duration(board_scene, step.from, step.to, anim_ctx)),
      "vehicle=" .. tostring(seq_builder.is_vehicle_anim(anim_ctx))
    )
    if anim_ctx and anim_ctx.state then
      board_feedback.play_step_tile_sound(anim_ctx.state, player_id, step.to)
    end
    self_ref.one_step(board_scene, player_id, step.from, step.to, anim_ctx)
  end
  for _, step in ipairs(steps) do
    debug_mod.debug_log(
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

return playback
