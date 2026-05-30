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
  local ok, module = pcall(require, "src.ui.coord.panel_interrupt")
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
  local pi = _panel_interrupt_module()
  if pi and anim_ctx and anim_ctx.state then
    pi.end_move(anim_ctx.state)
  end
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
  if token ~= nil then
    local pi = _panel_interrupt_module()
    if pi and anim_ctx.state then
      pi.begin_move(anim_ctx.state)
    end
  end
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

--[[ mutate4lua-manifest
version=2
projectHash=c48b403d2558767e
scope.0.id=chunk:src/ui/render/move_anim/playback.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=229
scope.0.semanticHash=5b6d31a6dabb8b22
scope.1.id=function:_panel_interrupt_module:14
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=19
scope.1.semanticHash=538416f1d9c47263
scope.2.id=function:_should_skip_stop_active_sequence:21
scope.2.kind=function
scope.2.startLine=21
scope.2.endLine=34
scope.2.semanticHash=a88481855e5e0006
scope.3.id=function:anonymous@47:47
scope.3.kind=function
scope.3.startLine=47
scope.3.endLine=49
scope.3.semanticHash=812d0b7f3fb59c11
scope.4.id=function:playback.one_step:38
scope.4.kind=function
scope.4.startLine=38
scope.4.endLine=57
scope.4.semanticHash=89eaecd4baec9003
scope.5.id=function:_stop_active_sequence:59
scope.5.kind=function
scope.5.startLine=59
scope.5.endLine=82
scope.5.semanticHash=03d94d7974076dae
scope.6.id=function:_apply_modifier_to_unit:84
scope.6.kind=function
scope.6.startLine=84
scope.6.endLine=90
scope.6.semanticHash=e47688afd81c7861
scope.7.id=function:_apply_speed_boost:92
scope.7.kind=function
scope.7.startLine=92
scope.7.endLine=97
scope.7.semanticHash=feef9df0364912bd
scope.8.id=function:_setup_sequence_token:99
scope.8.kind=function
scope.8.startLine=99
scope.8.endLine=118
scope.8.semanticHash=3e46af6d2fc903e4
scope.9.id=function:_log_sequence_start:120
scope.9.kind=function
scope.9.startLine=120
scope.9.endLine=134
scope.9.semanticHash=81cf1e65cf04f6b5
scope.10.id=function:_log_step_schedule:136
scope.10.kind=function
scope.10.startLine=136
scope.10.endLine=147
scope.10.semanticHash=10105e31918ed6a8
scope.11.id=function:_anim_seq_text:149
scope.11.kind=function
scope.11.startLine=149
scope.11.endLine=151
scope.11.semanticHash=a9deb04a45e128fb
scope.12.id=function:_log_step_skip:153
scope.12.kind=function
scope.12.startLine=153
scope.12.endLine=164
scope.12.semanticHash=652d592c06bc7dc6
scope.13.id=function:_log_step_execute:166
scope.13.kind=function
scope.13.startLine=166
scope.13.endLine=178
scope.13.semanticHash=c00dd21bc06cbfd5
scope.14.id=function:_execute_step:180
scope.14.kind=function
scope.14.startLine=180
scope.14.endLine=190
scope.14.semanticHash=db707c312869fbd7
scope.15.id=function:anonymous@217:217
scope.15.kind=function
scope.15.startLine=217
scope.15.endLine=217
scope.15.semanticHash=0cdf5f162b26aa62
scope.16.id=function:anonymous@221:221
scope.16.kind=function
scope.16.startLine=221
scope.16.endLine=223
scope.16.semanticHash=fe8fe584f654e7d2
]]
