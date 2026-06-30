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

function M.has_pending_roadblock_trigger(game, player)
  if not (game and game.turn and player and player.id ~= nil) then
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
version=2
projectHash=633783b2832c25cb
scope.0.id=chunk:src/ui/render/status3d/status_signals.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=81
scope.0.semanticHash=309f2a42fc5cd3a7
scope.0.lastMutatedAt=2026-06-30T13:41:59Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=8
scope.0.lastMutationKilled=8
scope.1.id=function:_is_roadblock_trigger_for_player:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=11
scope.1.semanticHash=e4c1d2f457417c4a
scope.1.lastMutatedAt=2026-06-30T13:41:59Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=5
scope.1.lastMutationKilled=5
scope.2.id=function:M.has_pending_roadblock_trigger:25
scope.2.kind=function
scope.2.startLine=25
scope.2.endLine=33
scope.2.semanticHash=2b75e013d215959b
scope.2.lastMutatedAt=2026-06-30T13:41:59Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=9
scope.2.lastMutationKilled=9
scope.3.id=function:M.check_roadblock_status:35
scope.3.kind=function
scope.3.startLine=35
scope.3.endLine=44
scope.3.semanticHash=4990376c33a877d9
scope.3.lastMutatedAt=2026-06-30T13:41:59Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=8
scope.3.lastMutationKilled=8
scope.4.id=function:_has_detention_wait:46
scope.4.kind=function
scope.4.startLine=46
scope.4.endLine=53
scope.4.semanticHash=45493966fde6e2da
scope.4.lastMutatedAt=2026-06-30T13:41:59Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=10
scope.4.lastMutationKilled=10
scope.5.id=function:_last_turn_matches_player:55
scope.5.kind=function
scope.5.startLine=55
scope.5.endLine=60
scope.5.semanticHash=2d672133ee98c32b
scope.5.lastMutatedAt=2026-06-30T13:41:59Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=7
scope.5.lastMutationKilled=7
scope.6.id=function:_notice_matches_player:62
scope.6.kind=function
scope.6.startLine=62
scope.6.endLine=64
scope.6.semanticHash=6e8016f64087a4ce
scope.6.lastMutatedAt=2026-06-30T13:41:59Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=3
scope.6.lastMutationKilled=3
scope.7.id=function:M.is_player_detained_this_turn:66
scope.7.kind=function
scope.7.startLine=66
scope.7.endLine=78
scope.7.semanticHash=5177e58539af6660
scope.7.lastMutatedAt=2026-06-30T13:41:59Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=11
scope.7.lastMutationKilled=11
]]
