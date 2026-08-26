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

local _panel_interrupt_cache
local function _panel_interrupt_module()
  if _panel_interrupt_cache ~= nil then return _panel_interrupt_cache end
  local ok, module = pcall(require, "src.ui.state.panel_interrupt")
  if ok then _panel_interrupt_cache = module end
  return _panel_interrupt_cache
end

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

local function _unit_for_player(board_scene, player_id)
  return board_scene and board_scene.units_by_player_id and board_scene.units_by_player_id[player_id] or nil
end

local function _or_none(value)
  return value or "none"
end

local function _log_finish_stop(player_id, anim_ctx, token, stop_result)
  if not debug_mod.enabled() then
    return
  end
  debug_mod.debug_log(
    "finish_stop",
    "player_id=" .. tostring(player_id),
    "seq=" .. tostring(anim_ctx and anim_ctx.seq or "nil"),
    "token=" .. tostring(token),
    "motion_stop=" .. tostring(_or_none(stop_result.motion_stop_path)),
    "anim_stop=" .. tostring(_or_none(stop_result.anim_stop_path))
  )
end

local function _end_panel_move(anim_ctx)
  local pi = _panel_interrupt_module()
  if pi and anim_ctx and anim_ctx.state then
    pi.end_move(anim_ctx.state)
  end
end

local function _stop_active_sequence(board_scene, player_id, anim_ctx, token)
  if _should_skip_stop_active_sequence(board_scene, player_id, anim_ctx, token) then
    return
  end
  local unit = _unit_for_player(board_scene, player_id)
  local stop_result = stop.stop_player_presentation(player_id, unit, _stop_synthetic_ai_opts)
  local active_sequence = rt.get_active_sequence(board_scene, player_id)
  _log_finish_stop(player_id, anim_ctx, token, stop_result)
  rt.release_sequence_lock(board_scene, player_id, active_sequence, "sequence_finished")
  stop.clear_player_token(board_scene, player_id, "sequence_finished")
  _end_panel_move(anim_ctx)
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
  _apply_modifier_to_unit(_unit_for_player(board_scene, player_id), total_time)
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

local function _anim_seq_text(anim_ctx)
  return tostring(anim_ctx and anim_ctx.seq)
end

local function _log_step_skip(player_id, anim_ctx, step, token)
  if debug_mod.enabled() then
    debug_mod.debug_log(
      "step_skip_stale_token",
      "player_id=" .. tostring(player_id),
      "seq=" .. _anim_seq_text(anim_ctx),
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
      "seq=" .. _anim_seq_text(anim_ctx),
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

local function _begin_panel_move(anim_ctx, token)
  if token == nil then
    return
  end
  local pi = _panel_interrupt_module()
  if pi and anim_ctx.state then
    pi.begin_move(anim_ctx.state)
  end
end

local function _schedule_steps(steps, ctx)
  for _, step in ipairs(steps) do
    _log_step_schedule(ctx.player_id, ctx.anim_ctx, step)
    if step.delay <= 0 then
      _execute_step(step, ctx)
    else
      runtime_ports.schedule(step.delay, function() _execute_step(step, ctx) end)
    end
  end
end

local function _schedule_sequence_stop(board_scene, player_id, anim_ctx, token, total_time)
  if token == nil then
    return
  end
  runtime_ports.schedule(total_time, function()
    _stop_active_sequence(board_scene, player_id, anim_ctx, token)
  end)
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
  _begin_panel_move(anim_ctx, token)
  _log_sequence_start(player_id, anim_ctx, steps, total_time, token)
  _schedule_steps(steps, {
    board_scene = board_scene,
    player_id = player_id,
    anim_ctx = anim_ctx,
    self_ref = self_ref,
    token = token,
  })
  _schedule_sequence_stop(board_scene, player_id, anim_ctx, token, total_time)
  return total_time
end

return playback

--[[ mutate4lua-manifest
version=4
projectHash=f1a0735f204900c9
scope.0.id=chunk:src/ui/render/move_anim/playback.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=263
scope.0.semanticHash=ce1786cffa86ab71
scope.1.id=function:_panel_interrupt_module
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=19
scope.1.semanticHash=2d74489a532aa260
scope.2.id=function:_should_skip_stop_active_sequence
scope.2.kind=function
scope.2.startLine=21
scope.2.endLine=34
scope.2.semanticHash=5ab2c258c765f49f
scope.3.id=function:playback.one_step
scope.3.kind=function
scope.3.startLine=38
scope.3.endLine=57
scope.3.semanticHash=4a68f74619529c03
scope.4.id=function:<anonymous>
scope.4.kind=function
scope.4.startLine=47
scope.4.endLine=49
scope.4.semanticHash=8a9e09e2c774a4a5
scope.5.id=function:_unit_for_player
scope.5.kind=function
scope.5.startLine=59
scope.5.endLine=61
scope.5.semanticHash=bafa57000621798c
scope.6.id=function:_or_none
scope.6.kind=function
scope.6.startLine=63
scope.6.endLine=65
scope.6.semanticHash=ce6edaea76014013
scope.7.id=function:_log_finish_stop
scope.7.kind=function
scope.7.startLine=67
scope.7.endLine=79
scope.7.semanticHash=02efc5f59f05285c
scope.8.id=function:_end_panel_move
scope.8.kind=function
scope.8.startLine=81
scope.8.endLine=86
scope.8.semanticHash=a605660c4114c0a1
scope.9.id=function:_stop_active_sequence
scope.9.kind=function
scope.9.startLine=88
scope.9.endLine=99
scope.9.semanticHash=4fdf15f4b742d352
scope.10.id=function:_apply_modifier_to_unit
scope.10.kind=function
scope.10.startLine=101
scope.10.endLine=107
scope.10.semanticHash=5ae9056aba40d25d
scope.11.id=function:_apply_speed_boost
scope.11.kind=function
scope.11.startLine=109
scope.11.endLine=112
scope.11.semanticHash=525fc0b8e6fa4fed
scope.12.id=function:_setup_sequence_token
scope.12.kind=function
scope.12.startLine=114
scope.12.endLine=133
scope.12.semanticHash=3d4970f5aaab7355
scope.13.id=function:_log_sequence_start
scope.13.kind=function
scope.13.startLine=135
scope.13.endLine=149
scope.13.semanticHash=abc74d5e524a58c4
scope.14.id=function:_log_step_schedule
scope.14.kind=function
scope.14.startLine=151
scope.14.endLine=162
scope.14.semanticHash=fbf3ab1084a8c7fc
scope.15.id=function:_anim_seq_text
scope.15.kind=function
scope.15.startLine=164
scope.15.endLine=166
scope.15.semanticHash=02d7e8c2bfae03dd
scope.16.id=function:_log_step_skip
scope.16.kind=function
scope.16.startLine=168
scope.16.endLine=179
scope.16.semanticHash=efe5da9add8489c7
scope.17.id=function:_log_step_execute
scope.17.kind=function
scope.17.startLine=181
scope.17.endLine=193
scope.17.semanticHash=c96cfc28e67ba69c
scope.18.id=function:_execute_step
scope.18.kind=function
scope.18.startLine=195
scope.18.endLine=205
scope.18.semanticHash=1940b609574c0cb9
scope.19.id=function:_begin_panel_move
scope.19.kind=function
scope.19.startLine=207
scope.19.endLine=215
scope.19.semanticHash=1274d9c9d5000f71
scope.20.id=function:_schedule_steps
scope.20.kind=function
scope.20.startLine=217
scope.20.endLine=226
scope.20.semanticHash=1df1020dbd0a60ef
scope.21.id=function:<anonymous>#2
scope.21.kind=function
scope.21.startLine=223
scope.21.endLine=223
scope.21.semanticHash=e22c624bf91895a0
scope.22.id=function:_schedule_sequence_stop
scope.22.kind=function
scope.22.startLine=228
scope.22.endLine=235
scope.22.semanticHash=b2ab65ada71302d9
scope.23.id=function:<anonymous>#3
scope.23.kind=function
scope.23.startLine=232
scope.23.endLine=234
scope.23.semanticHash=0a52153964e7a7c8
scope.24.id=function:playback.play_sequence
scope.24.kind=function
scope.24.startLine=237
scope.24.endLine=260
scope.24.semanticHash=33dabe5f534d5839
]]
