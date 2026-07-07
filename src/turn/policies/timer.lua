local tip_queue = require("src.foundation.tips")
local action_button_wait = require("src.turn.policies.action_button_wait")
local action_button_timer = require("src.turn.policies.action_button_timer")

local turn_timer_policy = {}

turn_timer_policy.is_action_button_wait_active = action_button_wait.is_action_button_wait_active
turn_timer_policy.update_action_button_timer = action_button_timer.update_action_button_timer

local function _complete_wait(turn, active_key, elapsed_key, step_turn, game)
  turn[active_key] = false
  turn[elapsed_key] = 0
  step_turn(game)
end

local function _wait_timer(game, state, dt, step_turn, active_key, elapsed_key, timeout_key, before_complete)
  if not (game and state) then
    return
  end
  local turn = game.turn
  if not (turn and turn[active_key]) then
    return
  end

  local elapsed = action_button_timer.resolve_elapsed(turn[elapsed_key], dt)
  local timeout = turn[timeout_key] or 0
  if timeout <= 0 then
    _complete_wait(turn, active_key, elapsed_key, step_turn, game)
    return
  end
  if elapsed < timeout then
    turn[elapsed_key] = elapsed
    return
  end

  if before_complete and before_complete(turn, timeout) == false then
    return
  end

  _complete_wait(turn, active_key, elapsed_key, step_turn, game)
end

function turn_timer_policy.update_detained_wait_timer(game, state, dt, step_turn)
  _wait_timer(game, state, dt, step_turn,
    "detained_wait_active", "detained_wait_elapsed", "detained_wait_seconds", nil)
end

local function _inter_turn_before_complete(turn, timeout)
  turn.inter_turn_wait_elapsed = timeout
  if tip_queue.has_blocking_pending("inter_turn") then
    return false
  end
  return true
end

function turn_timer_policy.update_inter_turn_wait_timer(game, state, dt, step_turn)
  _wait_timer(game, state, dt, step_turn,
    "inter_turn_wait_active", "inter_turn_wait_elapsed", "inter_turn_wait_seconds",
    _inter_turn_before_complete)
end

return turn_timer_policy

--[[ mutate4lua-manifest
version=2
projectHash=dad2cc58a4c444f6
scope.0.id=chunk:src/turn/policies/timer.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=63
scope.0.semanticHash=3a0463252fe50f8d
scope.0.lastMutatedAt=2026-07-07T02:52:28Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=3
scope.0.lastMutationKilled=3
scope.1.id=function:_complete_wait:10
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=14
scope.1.semanticHash=6bdf4de041312382
scope.1.lastMutatedAt=2026-07-07T02:52:28Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=3
scope.1.lastMutationKilled=3
scope.2.id=function:_wait_timer:16
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=41
scope.2.semanticHash=bf5df5d271bd2d42
scope.2.lastMutatedAt=2026-07-07T02:52:28Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=16
scope.2.lastMutationKilled=16
scope.3.id=function:turn_timer_policy.update_detained_wait_timer:43
scope.3.kind=function
scope.3.startLine=43
scope.3.endLine=46
scope.3.semanticHash=9bcdbb8b6769a02b
scope.3.lastMutatedAt=2026-07-07T02:52:28Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=1
scope.3.lastMutationKilled=1
scope.4.id=function:_inter_turn_before_complete:48
scope.4.kind=function
scope.4.startLine=48
scope.4.endLine=54
scope.4.semanticHash=0fdeda5aba3f9a2a
scope.4.lastMutatedAt=2026-07-07T02:52:28Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=3
scope.4.lastMutationKilled=3
scope.5.id=function:turn_timer_policy.update_inter_turn_wait_timer:56
scope.5.kind=function
scope.5.startLine=56
scope.5.endLine=60
scope.5.semanticHash=3ab240ad915ac011
scope.5.lastMutatedAt=2026-07-07T02:52:28Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=1
scope.5.lastMutationKilled=1
]]
