local logger = require("src.foundation.log")
local turn_action_port = require("src.ui.input.dispatch.turn_action_port")
local game_action_dispatcher = require("src.ui.input.dispatch.game_action")
local view_command_dispatcher = require("src.ui.input.dispatch.view_command")

local intent_dispatcher = {}

local function _dispatch_game_action(state, game, intent, opts, action_port)
  local resolved_action_port = action_port or turn_action_port.resolve(state, opts)
  return game_action_dispatcher.dispatch(state, game, intent, opts, resolved_action_port, turn_action_port)
end

intent_dispatcher.dispatch_view_command = view_command_dispatcher.dispatch

local _view_command_types = {
  toggle_action_log = true, open_skin_panel = true, open_gallery_panel = true,
  skin_panel_action = true, item_atlas_action = true, skin_gallery_action = true,
}

function intent_dispatcher.dispatch(state, game, intent, opts)
  assert(intent, "missing intent")
  local intent_type = intent.type
  local action_port = turn_action_port.resolve(state, opts)
  if _view_command_types[intent_type] and intent_dispatcher.dispatch_view_command(state, intent) then return end
  if turn_action_port.should_block(state, intent, action_port) then return end
  if not game then
    logger.warn("ui intent without game:", tostring(intent_type))
    return
  end
  if _dispatch_game_action(state, game, intent, opts, action_port) then return end
  intent_dispatcher.dispatch_view_command(state, intent)
end

return intent_dispatcher
