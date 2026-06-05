local logger = require("src.foundation.log")
local turn_action_port = require("src.ui.input.turn_action")
local game_action_dispatcher = require("src.ui.input.game_action")
local view_command_dispatcher = require("src.ui.input.view_command")

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

--[[ mutate4lua-manifest
version=2
projectHash=b0092a91d976cd68
scope.0.id=chunk:src/ui/input/intent_dispatcher.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=35
scope.0.semanticHash=eb3f48a4dd6dec3f
scope.1.id=function:_dispatch_game_action:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=11
scope.1.semanticHash=01922b783fe2fff7
scope.2.id=function:intent_dispatcher.dispatch:20
scope.2.kind=function
scope.2.startLine=20
scope.2.endLine=32
scope.2.semanticHash=f2159ba696607a8c
]]
