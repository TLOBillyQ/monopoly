local tip_queue = require("src.foundation.tips")
local action_button_wait = require("src.turn.policies.action_button_wait")
local action_button_timer = require("src.turn.policies.action_button_timer")

local turn_timer_policy = {}

turn_timer_policy.is_action_button_wait_active = action_button_wait.is_action_button_wait_active
turn_timer_policy.update_action_button_timer = action_button_timer.update_action_button_timer

local function _resolve_elapsed(elapsed, dt)
  return (elapsed or 0) + (dt or 0)
end

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

  local elapsed = _resolve_elapsed(turn[elapsed_key], dt)
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
projectHash=3733b049dd583e8b
scope.0.id=chunk:src/turn/policies/timer.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=67
scope.0.semanticHash=83d838b002b20029
scope.1.id=function:_resolve_elapsed:10
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=12
scope.1.semanticHash=45538442d3a1a35c
scope.2.id=function:_complete_wait:14
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=18
scope.2.semanticHash=6bdf4de041312382
scope.3.id=function:_wait_timer:20
scope.3.kind=function
scope.3.startLine=20
scope.3.endLine=45
scope.3.semanticHash=6828514ee859beaa
scope.4.id=function:turn_timer_policy.update_detained_wait_timer:47
scope.4.kind=function
scope.4.startLine=47
scope.4.endLine=50
scope.4.semanticHash=9bcdbb8b6769a02b
scope.5.id=function:_inter_turn_before_complete:52
scope.5.kind=function
scope.5.startLine=52
scope.5.endLine=58
scope.5.semanticHash=0fdeda5aba3f9a2a
scope.6.id=function:turn_timer_policy.update_inter_turn_wait_timer:60
scope.6.kind=function
scope.6.startLine=60
scope.6.endLine=64
scope.6.semanticHash=3ab240ad915ac011
]]
