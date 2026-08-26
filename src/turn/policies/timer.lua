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

local function _active_turn(game, active_key)
  local turn = game.turn
  if not (turn and turn[active_key]) then
    return nil
  end
  return turn
end

local function _resolve_active_wait(game, state, active_key, timeout_key)
  if not (game and state) then
    return nil
  end
  local turn = _active_turn(game, active_key)
  if turn == nil then
    return nil
  end
  return turn, turn[timeout_key] or 0
end

local function _completion_vetoed(before_complete, turn, timeout)
  return before_complete and before_complete(turn, timeout) == false
end

local function _wait_timer(game, state, dt, step_turn, active_key, elapsed_key, timeout_key, before_complete)
  local turn, timeout = _resolve_active_wait(game, state, active_key, timeout_key)
  if turn == nil then
    return
  end

  local elapsed = action_button_timer.resolve_elapsed(turn[elapsed_key], dt)
  if timeout <= 0 then
    _complete_wait(turn, active_key, elapsed_key, step_turn, game)
    return
  end
  if elapsed < timeout then
    turn[elapsed_key] = elapsed
    return
  end

  if _completion_vetoed(before_complete, turn, timeout) then
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
version=4
projectHash=bd69c0cfdf86e992
scope.0.id=chunk:src/turn/policies/timer.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=82
scope.0.semanticHash=a69b3edec70f989b
scope.1.id=function:_complete_wait
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=14
scope.1.semanticHash=1a15a0fcd854fe0b
scope.2.id=function:_active_turn
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=22
scope.2.semanticHash=c7e83b5fab334098
scope.3.id=function:_resolve_active_wait
scope.3.kind=function
scope.3.startLine=24
scope.3.endLine=33
scope.3.semanticHash=37cc28954a16a009
scope.4.id=function:_completion_vetoed
scope.4.kind=function
scope.4.startLine=35
scope.4.endLine=37
scope.4.semanticHash=40f2700156087d2b
scope.5.id=function:_wait_timer
scope.5.kind=function
scope.5.startLine=39
scope.5.endLine=60
scope.5.semanticHash=672396c937d3a57d
scope.6.id=function:turn_timer_policy.update_detained_wait_timer
scope.6.kind=function
scope.6.startLine=62
scope.6.endLine=65
scope.6.semanticHash=ab5b05c048541dd2
scope.7.id=function:_inter_turn_before_complete
scope.7.kind=function
scope.7.startLine=67
scope.7.endLine=73
scope.7.semanticHash=4cb5f98093203129
scope.8.id=function:turn_timer_policy.update_inter_turn_wait_timer
scope.8.kind=function
scope.8.startLine=75
scope.8.endLine=79
scope.8.semanticHash=d5f40561e77fdc97
]]
