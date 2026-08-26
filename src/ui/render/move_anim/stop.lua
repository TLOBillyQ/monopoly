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

-- Motion stops are first-match-wins: the first method the host unit exposes
-- wins and names the stop path.
local _MOTION_STOP_METHODS = {
  "stop_move",
  "force_stop_move",
  "stop_forced_move",
}

-- Anim stops are cumulative: every method the unit exposes runs, and the
-- stop path records them in order.
local _ANIM_STOP_METHODS = {
  "interrupt_multi_animation",
  "stop_anim",
  "stop_play_body_anim",
  "stop_play_upper_anim",
  "model_stop_animation",
}

local function _call_ai_command_stop(unit)
  if type(unit.ai_command_stop_move) ~= "function" then
    return nil
  end
  unit.ai_command_stop_move(_zero_fixed())
  return "ai_command_stop_move"
end

local function _stop_unit_motion(unit)
  if unit == nil then
    return nil
  end
  for _, method in ipairs(_MOTION_STOP_METHODS) do
    if type(unit[method]) == "function" then
      unit[method]()
      return method
    end
  end
  return _call_ai_command_stop(unit)
end

local function _stop_synthetic_ai_motion(unit, enabled)
  if enabled ~= true or unit == nil then
    return nil
  end
  return _call_ai_command_stop(unit)
end

local function _stop_unit_anim(unit)
  if unit == nil then
    return nil
  end
  local path = nil
  for _, method in ipairs(_ANIM_STOP_METHODS) do
    if type(unit[method]) == "function" then
      unit[method]()
      path = _append_stop_path(path, method)
    end
  end
  return path
end

local function _scene_unit(scene, player_id)
  return scene and scene.units_by_player_id and scene.units_by_player_id[player_id] or nil
end

local function _set_player_position(scene, player_id, target_pos)
  local unit = _scene_unit(scene, player_id)
  assert(unit, "missing unit: " .. tostring(player_id))
  assert(unit.set_position, "missing unit.set_position: " .. tostring(player_id))
  unit.set_position(target_pos)
  return "set_position"
end

function stop.stop_player_presentation(player_id, unit, opts)
  opts = opts or {}
  local synthetic_actor = seq_builder.is_synthetic_actor(player_id) == true
  local motion_stop_path = _stop_unit_motion(unit)
  return {
    synthetic_actor = synthetic_actor,
    ai_stop_path = _stop_synthetic_ai_motion(unit, opts.stop_synthetic_ai == true and synthetic_actor),
    motion_stop_path = motion_stop_path,
    anim_stop_path = _stop_unit_anim(unit),
  }
end

local function _text_or(value, fallback)
  return tostring(value or fallback)
end

local function _log_clear_token(player_id, reason, active_token)
  if not debug_mod.enabled() then
    return
  end
  debug_mod.debug_log(
    "clear_token",
    "player_id=" .. tostring(player_id),
    "reason=" .. _text_or(reason, "none"),
    "token=" .. _text_or(active_token, "nil")
  )
end

local function _has_token_or_sequence(active_token, active_sequence)
  return active_token ~= nil or active_sequence ~= nil
end

local function _clear_sequence_lock(board_scene, player_id, active_sequence, reason)
  if active_sequence ~= nil then
    rt.release_sequence_lock(board_scene, player_id, active_sequence, reason or "clear_player_token")
    rt.clear_active_sequence(board_scene, player_id)
  end
end

function stop.clear_player_token(board_scene, player_id, reason)
  if board_scene == nil or player_id == nil then
    return
  end
  local runtime_state = rt.ensure_runtime(board_scene)
  local active_token = runtime_state.active_token_by_player_id[player_id]
  local active_sequence = runtime_state.active_sequence_by_player_id[player_id]
  if not _has_token_or_sequence(active_token, active_sequence) then
    return
  end
  runtime_state.active_token_by_player_id[player_id] = nil
  _clear_sequence_lock(board_scene, player_id, active_sequence, reason)
  _log_clear_token(player_id, reason, active_token)
end

local function _has_stop_scope(rs, player_id)
  return rs.active_token_by_player_id[player_id] ~= nil or rs.active_sequence_by_player_id[player_id] ~= nil
end

function stop.has_active_stop_context(board_scene, player_id)
  if board_scene == nil or player_id == nil then return false end
  return _has_stop_scope(rt.ensure_runtime(board_scene), player_id)
end

local _stop_synthetic_ai_opts = { stop_synthetic_ai = true }

function stop.prepare_player_for_snap(board_scene, player_id, _anim_ctx, reason)
  stop.clear_player_token(board_scene, player_id, reason or "teleport")
  local unit = board_scene and board_scene.units_by_player_id and board_scene.units_by_player_id[player_id] or nil
  return stop.stop_player_presentation(player_id, unit, _stop_synthetic_ai_opts)
end

local function _snap_reason(reason)
  return reason or "play_sequence_teleport"
end

local function _log_snap(anim_ctx, player_id, to_index, r)
  debug_mod.debug_log(
    r,
    "player_id=" .. tostring(player_id),
    "seq=" .. tostring(anim_ctx and anim_ctx.seq or "nil"),
    "to=" .. tostring(to_index)
  )
end

function stop.snap_player_to_index(board_scene, player_id, to_index, anim_ctx, reason)
  local tile = assert(board_scene.tiles[to_index], "missing tile: " .. tostring(to_index))
  local r = _snap_reason(reason)
  local target_pos = tile.get_position()
  _set_player_position(board_scene, player_id, target_pos)
  seq_builder.publish_follow_target(anim_ctx, player_id, target_pos, r)
  if debug_mod.enabled() then _log_snap(anim_ctx, player_id, to_index, r) end
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

--[[ mutate4lua-manifest
version=4
projectHash=d0d52338931b7320
scope.0.id=chunk:src/ui/render/move_anim/stop.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=187
scope.0.semanticHash=eb2b783cb9bb89f4
scope.1.id=function:_zero_fixed
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=12
scope.1.semanticHash=afd69b7b21012fbf
scope.2.id=function:_append_stop_path
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=22
scope.2.semanticHash=69311b8f63227b3d
scope.3.id=function:_call_ai_command_stop
scope.3.kind=function
scope.3.startLine=42
scope.3.endLine=48
scope.3.semanticHash=9d340be8d428328c
scope.4.id=function:_stop_unit_motion
scope.4.kind=function
scope.4.startLine=50
scope.4.endLine=61
scope.4.semanticHash=076e70946941278f
scope.5.id=function:_stop_synthetic_ai_motion
scope.5.kind=function
scope.5.startLine=63
scope.5.endLine=68
scope.5.semanticHash=9df0e5f1600ba4a2
scope.6.id=function:_stop_unit_anim
scope.6.kind=function
scope.6.startLine=70
scope.6.endLine=82
scope.6.semanticHash=92088964eb3ba774
scope.7.id=function:_set_player_position
scope.7.kind=function
scope.7.startLine=84
scope.7.endLine=90
scope.7.semanticHash=fe5ad3260e62d1ec
scope.8.id=function:stop.stop_player_presentation
scope.8.kind=function
scope.8.startLine=92
scope.8.endLine=102
scope.8.semanticHash=5ef3adb3165802dc
scope.9.id=function:_text_or
scope.9.kind=function
scope.9.startLine=104
scope.9.endLine=106
scope.9.semanticHash=ff3f50da4d1f8f47
scope.10.id=function:_log_clear_token
scope.10.kind=function
scope.10.startLine=108
scope.10.endLine=118
scope.10.semanticHash=95e5b93fdbea25e9
scope.11.id=function:stop.clear_player_token
scope.11.kind=function
scope.11.startLine=120
scope.11.endLine=136
scope.11.semanticHash=ad8c51954a68a0dd
scope.12.id=function:_has_stop_scope
scope.12.kind=function
scope.12.startLine=138
scope.12.endLine=140
scope.12.semanticHash=a33a994477278af7
scope.13.id=function:stop.has_active_stop_context
scope.13.kind=function
scope.13.startLine=142
scope.13.endLine=145
scope.13.semanticHash=d3cd80d1abff1602
scope.14.id=function:stop.prepare_player_for_snap
scope.14.kind=function
scope.14.startLine=149
scope.14.endLine=153
scope.14.semanticHash=57db7d22e732ea59
scope.15.id=function:_snap_reason
scope.15.kind=function
scope.15.startLine=155
scope.15.endLine=157
scope.15.semanticHash=ce6edaea76014013
scope.16.id=function:_log_snap
scope.16.kind=function
scope.16.startLine=159
scope.16.endLine=166
scope.16.semanticHash=8d4d6545e1109aff
scope.17.id=function:stop.snap_player_to_index
scope.17.kind=function
scope.17.startLine=168
scope.17.endLine=176
scope.17.semanticHash=035ea43f94ac0ea6
scope.18.id=function:stop.play_teleport
scope.18.kind=function
scope.18.startLine=178
scope.18.endLine=184
scope.18.semanticHash=d39e1229c947f3e3
]]
