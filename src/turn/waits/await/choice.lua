local turn_decision = require("src.turn.waits.decision")
local validator = require("src.turn.actions.validator")
local shared = require("src.turn.waits.await.shared")

local M = {}

local _resolve_after_action_anim_state
local _resolve_choice_action
local _validate_choice_action
local _wait_for_choice_action_anim

local _next = shared.unpack_next
local _mark_dirty = shared.mark_dirty

local function _resolve_after_action_anim(args, res)
  local default_next_state, default_next_args = _next(args)
  local next_state, next_args = default_next_state, default_next_args
  local after_action_anim = type(res) == "table" and res.after_action_anim or nil
  if type(after_action_anim) ~= "table" then
    return next_state, next_args
  end
  return _resolve_after_action_anim_state(
    after_action_anim.next_state or next_state,
    after_action_anim.next_args or next_args,
    default_next_state,
    default_next_args
  )
end

_resolve_after_action_anim_state = function(next_state, next_args, default_next_state, default_next_args)
  if next_state ~= "move_followup" or type(next_args) ~= "table" then
    return next_state, next_args
  end
  next_args.next_state = next_args.next_state or default_next_state
  next_args.next_args = next_args.next_args or default_next_args
  return next_state, next_args
end

local function _clear_choice_wait(session, args)
  session.choice_elapsed_seconds = 0
  session:clear_pending_action()
  local next_state, next_args = _next(args)
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
    return { wait = true }
  end
  session.choice_elapsed_seconds = 0
  local next_state, next_args = _resolve_after_action_anim(args, res)
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
  return turn_decision.decide_choice_action(game, choice, session:take_pending_action(), {
    elapsed_seconds = session.choice_elapsed_seconds or 0,
  })
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

function M.choice(session, args)
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
    return { wait = true }
  end
  return _finish_choice_wait(session, args, game, res)
end

return M
