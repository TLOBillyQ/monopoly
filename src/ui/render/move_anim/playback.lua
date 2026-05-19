local timing = require("src.config.gameplay.timing")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local board_feedback = require("src.ui.render.board_feedback.service")
local debug_mod = require("src.ui.render.move_anim.debug")
local rt = require("src.ui.render.move_anim.runtime")
local seq_builder = require("src.ui.render.move_anim.sequence_builder")
local stop = require("src.ui.render.move_anim.stop")

local playback = {}
local _stop_synthetic_ai_opts = { stop_synthetic_ai = true }

local function _should_skip_stop_active_sequence(board_scene, player_id, anim_ctx, token)
  if rt.token_matches(board_scene, player_id, token) then
    return false
  end
  if debug_mod.enabled() then
    debug_mod.debug_log(
      "finish_skip_stale_token",
      "player_id=" .. tostring(player_id),
      "seq=" .. tostring(anim_ctx and anim_ctx.seq or "nil"),
      "token=" .. tostring(token)
    )
  end
  return true
end

playback.step_duration = seq_builder.calc_step_time

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
  local stop_result = stop.stop_player_presentation(player_id, unit, _stop_synthetic_ai_opts)
  local active_sequence = rt.get_active_sequence(board_scene, player_id)
  if debug_mod.enabled() then
    debug_mod.debug_log(
      "finish_stop",
      "player_id=" .. tostring(player_id),
      "seq=" .. tostring(anim_ctx and anim_ctx.seq or "nil"),
      "token=" .. tostring(token),
      "motion_stop=" .. tostring(stop_result.motion_stop_path or "none"),
      "anim_stop=" .. tostring(stop_result.anim_stop_path or "none")
    )
  end
  rt.release_sequence_lock(board_scene, player_id, active_sequence, "sequence_finished")
  stop.clear_player_token(board_scene, player_id, "sequence_finished")
end

local function _apply_modifier_to_unit(unit, total_time)
  if not (unit and unit.add_modifier_by_key) then return end
  local modifier = unit.add_modifier_by_key(runtime_constants.speed_boost_modifier_key, {})
  if modifier and modifier.set_remain_duration then
    modifier.set_remain_duration(total_time + timing.move_anim_tail_padding_seconds)
  end
end

local function _apply_speed_boost(board_scene, player_id, total_time)
  if total_time <= 0 then return end
  local unit = board_scene and board_scene.units_by_player_id
    and board_scene.units_by_player_id[player_id] or nil
  _apply_modifier_to_unit(unit, total_time)
end

local function _setup_sequence_token(board_scene, player_id, anim_ctx, from_index, to_index, total_time)
  if total_time <= 0 then return nil end
  local token = rt.build_token(player_id, anim_ctx.seq)
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
  return token
end

local function _log_sequence_start(player_id, anim_ctx, steps, total_time, token)
  if debug_mod.enabled() then
    debug_mod.debug_log(
      "play_sequence_start",
      "player_id=" .. tostring(player_id),
      "seq=" .. tostring(anim_ctx.seq or "nil"),
      "from=" .. tostring(anim_ctx.from_index),
      "to=" .. tostring(anim_ctx.to_index),
      "step_count=" .. tostring(#steps),
      "total_time=" .. tostring(total_time),
      "visited=" .. seq_builder.format_visited(anim_ctx.visited),
      "token=" .. tostring(token or "nil")
    )
  end
end

local function _log_step_schedule(player_id, anim_ctx, step)
  if debug_mod.enabled() then
    debug_mod.debug_log(
      "step_schedule",
      "player_id=" .. tostring(player_id),
      "seq=" .. tostring(anim_ctx.seq or "nil"),
      "from=" .. tostring(step.from),
      "to=" .. tostring(step.to),
      "delay=" .. tostring(step.delay)
    )
  end
end

local function _log_step_skip(player_id, anim_ctx, step, token)
  if debug_mod.enabled() then
    debug_mod.debug_log(
      "step_skip_stale_token",
      "player_id=" .. tostring(player_id),
      "seq=" .. tostring(anim_ctx and anim_ctx.seq or "nil"),
      "from=" .. tostring(step.from),
      "to=" .. tostring(step.to),
      "token=" .. tostring(token)
    )
  end
end

local function _log_step_execute(player_id, anim_ctx, self_ref, board_scene, step)
  if debug_mod.enabled() then
    debug_mod.debug_log(
      "step_execute",
      "player_id=" .. tostring(player_id),
      "seq=" .. tostring(anim_ctx and anim_ctx.seq or "nil"),
      "from=" .. tostring(step.from),
      "to=" .. tostring(step.to),
      "delay=" .. tostring(step.delay),
      "step_time=" .. tostring(self_ref.step_duration(board_scene, step.from, step.to, anim_ctx))
    )
  end
end

local function _execute_step(step, ctx)
  if ctx.token ~= nil and not rt.token_matches(ctx.board_scene, ctx.player_id, ctx.token) then
    _log_step_skip(ctx.player_id, ctx.anim_ctx, step, ctx.token)
    return
  end
  _log_step_execute(ctx.player_id, ctx.anim_ctx, ctx.self_ref, ctx.board_scene, step)
  if ctx.anim_ctx and ctx.anim_ctx.state then
    board_feedback.play_step_tile_sound(ctx.anim_ctx.state, ctx.player_id, step.to)
  end
  ctx.self_ref.one_step(ctx.board_scene, ctx.player_id, step.from, step.to, ctx.anim_ctx)
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
  _apply_speed_boost(board_scene, player_id, total_time)
  local token = _setup_sequence_token(board_scene, player_id, anim_ctx, from_index, to_index, total_time)
  _log_sequence_start(player_id, anim_ctx, steps, total_time, token)
  local ctx = { board_scene = board_scene, player_id = player_id, anim_ctx = anim_ctx, self_ref = self_ref, token = token }
  for _, step in ipairs(steps) do
    _log_step_schedule(player_id, anim_ctx, step)
    if step.delay <= 0 then
      _execute_step(step, ctx)
    else
      runtime_ports.schedule(step.delay, function() _execute_step(step, ctx) end)
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
