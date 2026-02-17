local turn_decision = require("turn.step.decide")
local logger = require("core.logger")

local choice_handler = {}

local function _resolve_choice(game, choice, action)
  return turn_decision.resolve_choice(game, choice, action)
end

function choice_handler.handle_wait_choice(game, args, pending_action)
  game.turn.phase = "wait_choice"
  game.dirty.turn = true
  game.dirty.any = true
  local choice = game.turn.pending_choice
  if not choice then
    return args.resume_state, args.resume_args
  end

  pending_action = turn_decision.decide_choice_action(game, choice, pending_action)

  if not pending_action then
    return "wait_choice", args
  end
  local action = pending_action

  if action.type == "choice_select" or action.type == "choice_cancel" then
    if not action.choice_id or not choice.id or action.choice_id ~= choice.id then
      logger.warn(
        "choice action mismatch:",
        tostring(action.type),
        "action_choice_id=" .. tostring(action.choice_id),
        "pending_choice_id=" .. tostring(choice.id)
      )
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
