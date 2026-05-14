local logger = require("src.foundation.log.logger")
local turn_action_port = require("src.ui.input.dispatch.turn_action_port")
local game_action_dispatcher = require("src.ui.input.dispatch.game_action")
local view_command_dispatcher = require("src.ui.input.dispatch.view_command")

local intent_dispatcher = {}

function intent_dispatcher.dispatch(state, game, intent, opts)
  assert(intent ~= nil, "missing intent")
  local intent_type = intent.type
  local action_port = turn_action_port.resolve(state, opts)
  if (intent_type == "toggle_action_log"
      or intent_type == "open_skin_panel"
      or intent_type == "open_gallery_panel"
      or intent_type == "skin_gallery_action")
      and intent_dispatcher.dispatch_view_command(state, intent) then
    return
  end
  if turn_action_port.should_block(state, intent, action_port) then
    return
  end
  if not game then
    logger.warn("ui intent without game:", tostring(intent_type))
    return
  end

  if intent_dispatcher.dispatch_game_action(state, game, intent, opts, action_port) then
    return
  end

  intent_dispatcher.dispatch_view_command(state, intent)
end

function intent_dispatcher.dispatch_game_action(state, game, intent, opts, action_port)
  local resolved_action_port = action_port or turn_action_port.resolve(state, opts)
  return game_action_dispatcher.dispatch(state, game, intent, opts, resolved_action_port, turn_action_port)
end

intent_dispatcher.dispatch_view_command = view_command_dispatcher.dispatch

return intent_dispatcher
