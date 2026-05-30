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
  if type(unit.stop_move) == "function" then
    unit.stop_move()
    return "stop_move"
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

local function _set_player_position(scene, player_id, target_pos)
  local unit = scene and scene.units_by_player_id and scene.units_by_player_id[player_id] or nil
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
  if debug_mod.enabled() then
    debug_mod.debug_log(
      "clear_token",
      "player_id=" .. tostring(player_id),
      "reason=" .. tostring(reason or "none"),
      "token=" .. tostring(active_token or "nil")
    )
  end
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
version=2
projectHash=440f1825f7cffe00
scope.0.id=chunk:src/ui/render/move_anim/stop.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=180
scope.0.semanticHash=05c7111db0c546a7
scope.1.id=function:_zero_fixed:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=12
scope.1.semanticHash=568979dafe058243
scope.2.id=function:_append_stop_path:14
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=22
scope.2.semanticHash=db38a3ade9373638
scope.3.id=function:_stop_unit_motion:24
scope.3.kind=function
scope.3.startLine=24
scope.3.endLine=45
scope.3.semanticHash=1671c7db0ef702c0
scope.4.id=function:_stop_synthetic_ai_motion:47
scope.4.kind=function
scope.4.startLine=47
scope.4.endLine=56
scope.4.semanticHash=561a53505ef66145
scope.5.id=function:_stop_unit_anim:58
scope.5.kind=function
scope.5.startLine=58
scope.5.endLine=84
scope.5.semanticHash=2d79cbce3bd1b649
scope.6.id=function:_set_player_position:86
scope.6.kind=function
scope.6.startLine=86
scope.6.endLine=92
scope.6.semanticHash=2bbd3c0417bd5c51
scope.7.id=function:stop.stop_player_presentation:94
scope.7.kind=function
scope.7.startLine=94
scope.7.endLine=104
scope.7.semanticHash=7c9780a019665cab
scope.8.id=function:stop.clear_player_token:106
scope.8.kind=function
scope.8.startLine=106
scope.8.endLine=129
scope.8.semanticHash=1a1d9c0607bca127
scope.9.id=function:_has_stop_scope:131
scope.9.kind=function
scope.9.startLine=131
scope.9.endLine=133
scope.9.semanticHash=b5bfdbeb62ab41db
scope.10.id=function:stop.has_active_stop_context:135
scope.10.kind=function
scope.10.startLine=135
scope.10.endLine=138
scope.10.semanticHash=80ef4ec1f6c06a92
scope.11.id=function:stop.prepare_player_for_snap:142
scope.11.kind=function
scope.11.startLine=142
scope.11.endLine=146
scope.11.semanticHash=787a486a6ecab403
scope.12.id=function:_snap_reason:148
scope.12.kind=function
scope.12.startLine=148
scope.12.endLine=150
scope.12.semanticHash=6f41680423e56a28
scope.13.id=function:_log_snap:152
scope.13.kind=function
scope.13.startLine=152
scope.13.endLine=159
scope.13.semanticHash=6498dc59178e8054
scope.14.id=function:stop.snap_player_to_index:161
scope.14.kind=function
scope.14.startLine=161
scope.14.endLine=169
scope.14.semanticHash=b89096e99d20e6fe
scope.15.id=function:stop.play_teleport:171
scope.15.kind=function
scope.15.startLine=171
scope.15.endLine=177
scope.15.semanticHash=99397619fb0ce9d7
]]
