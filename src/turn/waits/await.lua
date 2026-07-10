local auto_play_port = require("src.rules.ports.auto_play")
local turn_decision = require("src.turn.waits.decision")
local validator = require("src.turn.actions.validator")
local chain_args = require("src.foundation.chain_args")
local shared = require("src.turn.waits.await_shared")
local action_anim = require("src.turn.waits.await_action_anim")
local move_anim = require("src.turn.waits.await_move_anim")
local transitions = require("src.turn.waits.await_transitions")
local seconds = require("src.turn.waits.await_seconds")

local _WAIT = shared.WAIT
local _unpack_next = shared.unpack_next
local _mark_dirty = shared.mark_dirty

local _CHOICE_ACTION_TYPES = { choice_select = true, choice_cancel = true, choice_force_skip = true }

local function _is_choice_action(peeked)
  if not peeked then return false end
  return _CHOICE_ACTION_TYPES[peeked.type] == true
end

local function _build_action_next(args, player)
  return {
    next_state = args and args.next_state or "roll",
    next_args = args and args.next_args or { player = player },
  }
end

local function _action(session, args)
  assert(session, "missing await session")
  assert(session.game, "missing await session.game")
  local game = session.game
  session:mark_phase("wait_action")
  local player = game:current_player()
  if auto_play_port.is_auto_player(game, player) then
    return _build_action_next(args, player)
  end
  local peeked = session:peek_pending_action()
  if _is_choice_action(peeked) then
    return _build_action_next(args, player)
  end
  local action = session:take_pending_action()
  if action then
    return _build_action_next(args, player)
  end
  return _WAIT
end

local _resolve_choice_action
local _validate_choice_action
local _wait_for_choice_action_anim

local _decide_opts = { elapsed_seconds = 0 }

local function _resolve_after_action_anim(args, res)
  return chain_args.resolve_after_action_anim(args, res, "move_followup")
end

local function _clear_choice_wait(session, args)
  session.choice_elapsed_seconds = 0
  session:clear_pending_action()
  local next_state, next_args = _unpack_next(args)
  return {
    next_state = next_state,
    next_args = next_args,
  }
end

local function _resolve_choice_result(game, choice, session)
  local action = _resolve_choice_action(choice, session, game)
  if action == nil then
    return nil, false
  end
  if not _validate_choice_action(action, choice) then
    return nil, false
  end
  if action.type == "choice_force_skip" then
    if game and game.turn then
      game.turn.pending_choice = nil
      _mark_dirty(game)
    end
    return {}, true
  end
  return turn_decision.resolve_choice(game, choice, action), true
end

local function _finish_choice_wait(session, args, game, res)
  if res and res.stay then
    return _WAIT
  end
  local next_state, next_args = _resolve_after_action_anim(args, res)
  if next_state ~= "wait_choice" then
    session.choice_elapsed_seconds = 0
  end
  if game.turn.action_anim then
    return _wait_for_choice_action_anim(game, next_state, next_args)
  end
  return {
    next_state = next_state,
    next_args = next_args,
  }
end

_resolve_choice_action = function(choice, session, game)
  if game and game.turn and game.turn._choice_force_skip_pending then
    game.turn._choice_force_skip_pending = nil
    return { type = "choice_force_skip", choice_id = choice and choice.id }
  end
  _decide_opts.elapsed_seconds = session.choice_elapsed_seconds or 0
  return turn_decision.decide_choice_action(game, choice, session:take_pending_action(), _decide_opts)
end

_validate_choice_action = function(action, choice)
  if action.type == "choice_force_skip" then
    return true
  end
  if action.type ~= "choice_select" and action.type ~= "choice_cancel" then
    return true
  end
  return validator.validate_choice_id(action, choice)
end

_wait_for_choice_action_anim = function(game, next_state, next_args)
  if next_state == "move_followup" then
    game.turn.move_followup_pending = true
    _mark_dirty(game)
  end
  return {
    next_state = "wait_action_anim",
    next_args = {
      next_state = next_state,
      next_args = next_args,
    },
  }
end

local function _choice(session, args)
  assert(session ~= nil and session.game ~= nil, "missing await session")
  local game = session.game
  session:mark_phase("wait_choice")
  local choice = game.turn.pending_choice
  if not choice then
    if game.turn._choice_force_skip_pending then
      game.turn._choice_force_skip_pending = nil
    end
    return _clear_choice_wait(session, args)
  end

  local res, resolved = _resolve_choice_result(game, choice, session)
  if not resolved then
    return _WAIT
  end
  return _finish_choice_wait(session, args, game, res)
end

local await = {}

await.choice = _choice
await.action = _action
await.move_anim = move_anim.move_anim
await.action_anim = action_anim.action_anim
await.landing_visual = transitions.landing_visual
await.detained = transitions.detained
await.inter_turn = transitions.inter_turn
await.seconds = seconds.seconds

await._M_test = {
  _coalesce_head = action_anim._coalesce_head,
}

return await

--[[ mutate4lua-manifest
version=2
projectHash=d01f10aefeced978
scope.0.id=chunk:src/turn/waits/await.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=170
scope.0.semanticHash=24ea83f8eb6a2713
scope.0.lastMutatedAt=2026-07-07T02:45:38Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=survived
scope.0.lastMutationSites=13
scope.0.lastMutationKilled=12
scope.1.id=function:_is_choice_action:17
scope.1.kind=function
scope.1.startLine=17
scope.1.endLine=20
scope.1.semanticHash=d38acae24912679b
scope.1.lastMutatedAt=2026-07-07T02:45:38Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=4
scope.1.lastMutationKilled=4
scope.2.id=function:_build_action_next:22
scope.2.kind=function
scope.2.startLine=22
scope.2.endLine=27
scope.2.semanticHash=c4ed43e077237b77
scope.2.lastMutatedAt=2026-07-07T02:45:38Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=5
scope.2.lastMutationKilled=5
scope.3.id=function:_action:29
scope.3.kind=function
scope.3.startLine=29
scope.3.endLine=47
scope.3.semanticHash=48821194d0b98099
scope.3.lastMutatedAt=2026-07-07T02:45:38Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=11
scope.3.lastMutationKilled=11
scope.4.id=function:_resolve_after_action_anim:55
scope.4.kind=function
scope.4.startLine=55
scope.4.endLine=57
scope.4.semanticHash=ea3de58a8f0adf16
scope.4.lastMutatedAt=2026-07-07T02:45:38Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=1
scope.4.lastMutationKilled=1
scope.5.id=function:_clear_choice_wait:59
scope.5.kind=function
scope.5.startLine=59
scope.5.endLine=67
scope.5.semanticHash=c57e352f42405a93
scope.5.lastMutatedAt=2026-07-07T02:45:38Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=3
scope.5.lastMutationKilled=3
scope.6.id=function:_resolve_choice_result:69
scope.6.kind=function
scope.6.startLine=69
scope.6.endLine=85
scope.6.semanticHash=60048a98e28e4de0
scope.6.lastMutatedAt=2026-07-07T02:45:38Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=survived
scope.6.lastMutationSites=13
scope.6.lastMutationKilled=12
scope.7.id=function:_finish_choice_wait:87
scope.7.kind=function
scope.7.startLine=87
scope.7.endLine=100
scope.7.semanticHash=f5e05b6ad22b4ccb
scope.7.lastMutatedAt=2026-07-07T02:45:38Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=4
scope.7.lastMutationKilled=4
scope.8.id=function:anonymous@102:102
scope.8.kind=function
scope.8.startLine=102
scope.8.endLine=109
scope.8.semanticHash=8babb436e8bb8c64
scope.8.lastMutatedAt=2026-07-07T02:45:38Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=survived
scope.8.lastMutationSites=7
scope.8.lastMutationKilled=6
scope.9.id=function:anonymous@111:111
scope.9.kind=function
scope.9.startLine=111
scope.9.endLine=119
scope.9.semanticHash=49ee766c1a96e952
scope.9.lastMutatedAt=2026-07-07T02:45:38Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=survived
scope.9.lastMutationSites=10
scope.9.lastMutationKilled=9
scope.10.id=function:anonymous@121:121
scope.10.kind=function
scope.10.startLine=121
scope.10.endLine=133
scope.10.semanticHash=1f9e120a87fb5b5b
scope.10.lastMutatedAt=2026-07-07T02:45:38Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=5
scope.10.lastMutationKilled=5
scope.11.id=function:_choice:135
scope.11.kind=function
scope.11.startLine=135
scope.11.endLine=152
scope.11.semanticHash=cae4baddcb0856a5
scope.11.lastMutatedAt=2026-07-07T02:45:38Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=7
scope.11.lastMutationKilled=7
]]
