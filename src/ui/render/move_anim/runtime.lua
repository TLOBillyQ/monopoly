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

function runtime.release_sequence_lock(board_scene, player_id, entry, reason)
  if entry == nil or entry.lock_released == true then
    return
  end
  entry.lock_released = true
  entry.reason = reason
  if entry.anim_ctx and type(entry.anim_ctx.on_sequence_lock) == "function" then
    entry.anim_ctx.on_sequence_lock(true, entry.total_time, runtime.sequence_meta(entry))
  end
  if debug_mod.enabled() then
    debug_mod.debug_log(
      "sequence_lock_release",
      "player_id=" .. tostring(player_id),
      "seq=" .. tostring(entry.seq or "nil"),
      "token=" .. tostring(entry.token or "nil"),
      "reason=" .. tostring(reason or "none")
    )
  end
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
version=2
projectHash=6b11369cbea65daf
scope.0.id=chunk:src/ui/render/move_anim/runtime.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=90
scope.0.semanticHash=c765c39e9e88706d
scope.1.id=function:runtime.ensure_runtime:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=16
scope.1.semanticHash=b3aa3dce368f66dd
scope.2.id=function:runtime.build_token:18
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=20
scope.2.semanticHash=609219b87d481184
scope.3.id=function:anonymous@23:23
scope.3.kind=function
scope.3.startLine=23
scope.3.endLine=25
scope.3.semanticHash=061948b13211e14d
scope.4.id=function:_per_player_getter:22
scope.4.kind=function
scope.4.startLine=22
scope.4.endLine=26
scope.4.semanticHash=e121f0c05cdfe789
scope.5.id=function:runtime.set_active_token:28
scope.5.kind=function
scope.5.startLine=28
scope.5.endLine=32
scope.5.semanticHash=35086019270d4412
scope.6.id=function:runtime.sequence_meta:37
scope.6.kind=function
scope.6.startLine=37
scope.6.endLine=49
scope.6.semanticHash=75a530dcb1ce102b
scope.7.id=function:runtime.release_sequence_lock:51
scope.7.kind=function
scope.7.startLine=51
scope.7.endLine=69
scope.7.semanticHash=0d1f1c7b50bd597c
scope.8.id=function:runtime.clear_active_sequence:71
scope.8.kind=function
scope.8.startLine=71
scope.8.endLine=74
scope.8.semanticHash=88fc9a34f06d2c25
scope.9.id=function:runtime.set_active_sequence:76
scope.9.kind=function
scope.9.startLine=76
scope.9.endLine=83
scope.9.semanticHash=466a13b926364abd
scope.10.id=function:runtime.token_matches:85
scope.10.kind=function
scope.10.startLine=85
scope.10.endLine=87
scope.10.semanticHash=e4a5b19fc086df6f
]]
