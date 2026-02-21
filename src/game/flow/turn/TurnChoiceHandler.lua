local turn_decision = require("src.game.flow.turn.TurnDecision")
local validator = require("src.game.flow.turn.TurnDispatchValidator")

local choice_handler = {}

local function _resolve_choice(game, choice, action)
  return turn_decision.resolve_choice(game, choice, action)
end

function choice_handler.handle_wait_choice(turn_flow, args)
  local game = turn_flow.game
  game.turn.phase = "wait_choice"
  game.dirty.turn = true
  game.dirty.any = true
  local choice = game.turn.pending_choice
  if not choice then
    turn_flow.pending_action = nil
    return args.resume_state, args.resume_args
  end

  turn_flow.pending_action = turn_decision.decide_choice_action(game, choice, turn_flow.pending_action)

  if not turn_flow.pending_action then
    return "wait_choice", args
  end
  local action = turn_flow.pending_action
  turn_flow.pending_action = nil

  if action.type == "choice_select" or action.type == "choice_cancel" then
    if not validator.validate_choice_id(action, choice) then
      return "wait_choice", args
    end
  end
  local res = _resolve_choice(game, choice, action)
  if res.stay then
    return "wait_choice", args
  end
  local action_anim = game.turn.action_anim
  if action_anim then
    return "wait_action_anim", args
  end
  return args.resume_state, args.resume_args
end

return choice_handler
