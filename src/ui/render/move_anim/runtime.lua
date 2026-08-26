local debug_mod = require("src.ui.render.move_anim.debug")

local runtime = {}

function runtime.ensure_runtime(board_scene)
  if type(board_scene._move_anim_runtime) ~= "table" then
    board_scene._move_anim_runtime = {
      active_token_by_player_id = {},
      active_sequence_by_player_id = {},
    }
  end
  if type(board_scene._move_anim_runtime.active_sequence_by_player_id) ~= "table" then
    board_scene._move_anim_runtime.active_sequence_by_player_id = {}
  end
  return board_scene._move_anim_runtime
end

function runtime.build_token(player_id, seq)
  return string.format("%s:%s", player_id, seq or "no_seq")
end

local function _per_player_getter(field)
  return function(board_scene, player_id)
    return runtime.ensure_runtime(board_scene)[field][player_id]
  end
end

function runtime.set_active_token(board_scene, player_id, token)
  local rt = runtime.ensure_runtime(board_scene)
  rt.active_token_by_player_id[player_id] = token
  return token
end

local _get_active_token = _per_player_getter("active_token_by_player_id")
runtime.get_active_sequence = _per_player_getter("active_sequence_by_player_id")

function runtime.sequence_meta(entry)
  if entry == nil then
    return nil
  end
  return {
    player_id = entry.player_id,
    from = entry.from_index,
    to = entry.to_index,
    seq = entry.seq,
    token = entry.token,
    reason = entry.reason,
  }
end

local function _text_or(value, fallback)
  return tostring(value or fallback)
end

local function _log_sequence_lock_release(player_id, entry, reason)
  if not debug_mod.enabled() then
    return
  end
  debug_mod.debug_log(
    "sequence_lock_release",
    "player_id=" .. tostring(player_id),
    "seq=" .. _text_or(entry.seq, "nil"),
    "token=" .. _text_or(entry.token, "nil"),
    "reason=" .. _text_or(reason, "none")
  )
end

function runtime.release_sequence_lock(board_scene, player_id, entry, reason)
  if entry == nil or entry.lock_released == true then
    return
  end
  entry.lock_released = true
  entry.reason = reason
  if entry.anim_ctx and type(entry.anim_ctx.on_sequence_lock) == "function" then
    entry.anim_ctx.on_sequence_lock(true, entry.total_time, runtime.sequence_meta(entry))
  end
  _log_sequence_lock_release(player_id, entry, reason)
end

function runtime.clear_active_sequence(board_scene, player_id)
  local rt = runtime.ensure_runtime(board_scene)
  rt.active_sequence_by_player_id[player_id] = nil
end

function runtime.set_active_sequence(board_scene, player_id, entry)
  local rt = runtime.ensure_runtime(board_scene)
  local previous = rt.active_sequence_by_player_id[player_id]
  if previous ~= nil and previous ~= entry then
    runtime.release_sequence_lock(board_scene, player_id, previous, "sequence_replaced")
  end
  rt.active_sequence_by_player_id[player_id] = entry
end

function runtime.token_matches(board_scene, player_id, token)
  return _get_active_token(board_scene, player_id) == token
end

return runtime

--[[ mutate4lua-manifest
version=4
projectHash=d0d52338931b7320
scope.0.id=chunk:src/ui/render/move_anim/runtime.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=99
scope.0.semanticHash=a28ba035ed2da2c7
scope.1.id=function:runtime.ensure_runtime
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=16
scope.1.semanticHash=db0615bac0523110
scope.2.id=function:runtime.build_token
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=20
scope.2.semanticHash=e8358209fefd3d83
scope.3.id=function:_per_player_getter
scope.3.kind=function
scope.3.startLine=22
scope.3.endLine=26
scope.3.semanticHash=959fb213a6cfc267
scope.4.id=function:<anonymous>
scope.4.kind=function
scope.4.startLine=23
scope.4.endLine=25
scope.4.semanticHash=981b9db8a8c632d6
scope.5.id=function:runtime.set_active_token
scope.5.kind=function
scope.5.startLine=28
scope.5.endLine=32
scope.5.semanticHash=75bef81415ddffe9
scope.6.id=function:runtime.sequence_meta
scope.6.kind=function
scope.6.startLine=37
scope.6.endLine=49
scope.6.semanticHash=4e193d2b02737fe5
scope.7.id=function:_text_or
scope.7.kind=function
scope.7.startLine=51
scope.7.endLine=53
scope.7.semanticHash=ff3f50da4d1f8f47
scope.8.id=function:_log_sequence_lock_release
scope.8.kind=function
scope.8.startLine=55
scope.8.endLine=66
scope.8.semanticHash=e4c014ce5c3e5bdd
scope.9.id=function:runtime.release_sequence_lock
scope.9.kind=function
scope.9.startLine=68
scope.9.endLine=78
scope.9.semanticHash=eaea2969b1068970
scope.10.id=function:runtime.clear_active_sequence
scope.10.kind=function
scope.10.startLine=80
scope.10.endLine=83
scope.10.semanticHash=5bd4c881c7e9a5bd
scope.11.id=function:runtime.set_active_sequence
scope.11.kind=function
scope.11.startLine=85
scope.11.endLine=92
scope.11.semanticHash=ef9bcb556bf4b9a3
scope.12.id=function:runtime.token_matches
scope.12.kind=function
scope.12.startLine=94
scope.12.endLine=96
scope.12.semanticHash=50f5ac42882d692e
]]
