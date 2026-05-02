local logger = require("src.foundation.log.logger")
local turn_action_port = require("src.ui.input.dispatch.turn_action_port")
local game_action_dispatcher = require("src.ui.input.dispatch.game_action")
local view_command_dispatcher = require("src.ui.input.dispatch.view_command")

local intent_dispatcher = {}

function intent_dispatcher.dispatch(state, game, intent, opts)
  assert(intent ~= nil, "missing intent")
  local intent_type = intent.type
  logger.info("[diag-firsttap] intent_dispatcher.dispatch enter", tostring(intent_type), tostring(intent.id))
  local action_port = turn_action_port.resolve(state, opts)
  if intent_type == "toggle_action_log" and intent_dispatcher.dispatch_view_command(state, intent) then
    logger.info("[diag-firsttap] handled by toggle_action_log")
    return
  end
  if turn_action_port.should_block(state, intent, action_port) then
    logger.info("[diag-firsttap] BLOCKED by turn_action_port.should_block")
    return
  end
  if not game then
    logger.warn("ui intent without game:", tostring(intent_type))
    return
  end

  if intent_dispatcher.dispatch_game_action(state, game, intent, opts, action_port) then
    logger.info("[diag-firsttap] handled by dispatch_game_action")
    return
  end

  logger.info("[diag-firsttap] fallthrough to dispatch_view_command")
  intent_dispatcher.dispatch_view_command(state, intent)
end

function intent_dispatcher.dispatch_game_action(state, game, intent, opts, action_port)
  local resolved_action_port = action_port or turn_action_port.resolve(state, opts)
  return game_action_dispatcher.dispatch(state, game, intent, opts, resolved_action_port, turn_action_port)
end

function intent_dispatcher.dispatch_view_command(state, intent)
  return view_command_dispatcher.dispatch(state, intent)
end

return intent_dispatcher
