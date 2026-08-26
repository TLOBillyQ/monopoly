-- Transient turn-state predicates for the 3D player-status overlay: detect
-- whether a player has a pending roadblock trigger, just stopped on a roadblock,
-- or is detained on the current frozen turn. Pure boolean queries over
-- game/turn state, consumed by src.ui.render.status3d.status_resolve.
local M = {}

local function _is_roadblock_trigger_for_player(anim, player_id)
  return anim
      and anim.kind == "roadblock_trigger"
      and anim.player_id == player_id
end

local function _queued_roadblock_trigger_for_player(queue, player_id)
  if type(queue) ~= "table" then
    return false
  end
  for _, entry in ipairs(queue) do
    if _is_roadblock_trigger_for_player(entry, player_id) then
      return true
    end
  end
  return false
end

local function _trigger_context_ready(game, player)
  return game and game.turn and player and player.id ~= nil
end

function M.has_pending_roadblock_trigger(game, player)
  if not _trigger_context_ready(game, player) then
    return false
  end
  if _is_roadblock_trigger_for_player(game.turn.action_anim, player.id) then
    return true
  end
  return _queued_roadblock_trigger_for_player(game.turn.action_anim_queue, player.id)
end

function M.check_roadblock_status(last_turn, player)
  if not last_turn then
    return false
  end
  if last_turn.player_id ~= player.id then
    return false
  end
  local move_result = last_turn.move_result
  return move_result ~= nil and move_result.stopped_on_roadblock == true
end

local function _has_detention_wait(turn)
  if not turn then
    return false
  end
  local notice_active = turn.no_action_notice_active == true
  local detained_active = turn.detained_wait_active == true or turn.phase == "detained_wait"
  return notice_active or detained_active, notice_active
end

local function _last_turn_matches_player(last_turn, player)
  return last_turn
      and last_turn.player_id == player.id
      and last_turn.skipped == true
      and last_turn.stay_turns ~= nil
end

local function _notice_matches_player(turn, player, notice_active)
  return not notice_active or turn.no_action_notice_player_id == player.id
end

function M.is_player_detained_this_turn(game, player)
  if game == nil or player == nil then
    return false
  end
  local wait_active, notice_active = _has_detention_wait(game.turn)
  if not wait_active then
    return false
  end
  if not _last_turn_matches_player(game.last_turn, player) then
    return false
  end
  return _notice_matches_player(game.turn, player, notice_active)
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=965dcef34f28a9ef
scope.0.id=chunk:src/ui/render/status3d/status_signals.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=85
scope.0.semanticHash=14603f23a16c8d90
scope.1.id=function:_is_roadblock_trigger_for_player
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=11
scope.1.semanticHash=443901f1a8edb741
scope.2.id=function:_queued_roadblock_trigger_for_player
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=23
scope.2.semanticHash=7fa9213249c0abf0
scope.3.id=function:_trigger_context_ready
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=27
scope.3.semanticHash=53d600ea623b3391
scope.4.id=function:M.has_pending_roadblock_trigger
scope.4.kind=function
scope.4.startLine=29
scope.4.endLine=37
scope.4.semanticHash=e336f7ae1a6dca6f
scope.5.id=function:M.check_roadblock_status
scope.5.kind=function
scope.5.startLine=39
scope.5.endLine=48
scope.5.semanticHash=bba74f3d7a9dc6f8
scope.6.id=function:_has_detention_wait
scope.6.kind=function
scope.6.startLine=50
scope.6.endLine=57
scope.6.semanticHash=f4d4e67d70d6e026
scope.7.id=function:_last_turn_matches_player
scope.7.kind=function
scope.7.startLine=59
scope.7.endLine=64
scope.7.semanticHash=e422a4e845c2e44f
scope.8.id=function:_notice_matches_player
scope.8.kind=function
scope.8.startLine=66
scope.8.endLine=68
scope.8.semanticHash=a7a7ae4b1aaa5812
scope.9.id=function:M.is_player_detained_this_turn
scope.9.kind=function
scope.9.startLine=70
scope.9.endLine=82
scope.9.semanticHash=79159cf986885656
]]
