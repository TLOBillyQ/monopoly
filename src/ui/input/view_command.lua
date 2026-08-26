local view_command_dispatcher = {}
local panel_interrupt = require("src.ui.state.panel_interrupt")
local command_policy = require("src.ui.input.command_policy")
local logger = require("src.foundation.log")

local function _intent_panel_id(intent)
  return command_policy.panel_id(intent)
end

local function _blocks_panel_entry(state, intent)
  local panel_id = _intent_panel_id(intent)
  if panel_id == nil then
    return false
  end
  return panel_interrupt.block_entry(state, panel_id, intent.actor_role_id) == true
end

local function _view_command_port(state)
  local ports = state and state.gameplay_loop_ports or nil
  return ports and ports.view_command or nil
end

local function _resolve_port(state)
  local view_command = _view_command_port(state)
  if view_command == nil or type(view_command.dispatch) ~= "function" then
    return nil
  end
  return view_command
end

function view_command_dispatcher.dispatch(state, intent)
  if _blocks_panel_entry(state, intent) then
    return true
  end
  local view_command = _resolve_port(state)
  if view_command == nil then
    local intent_type = intent and intent.type
    logger.warn("view_command port missing, intent dropped:", tostring(intent_type))
    return false
  end
  return view_command.dispatch(state, intent) == true
end

return view_command_dispatcher

--[[ mutate4lua-manifest
version=4
projectHash=5a4b8fb7bb424894
scope.0.id=chunk:src/ui/input/view_command.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=45
scope.0.semanticHash=fa186ea8484ffe4e
scope.1.id=function:_intent_panel_id
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=8
scope.1.semanticHash=f1ce1850b7232305
scope.2.id=function:_blocks_panel_entry
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=16
scope.2.semanticHash=3c3ff495381e5752
scope.3.id=function:_view_command_port
scope.3.kind=function
scope.3.startLine=18
scope.3.endLine=21
scope.3.semanticHash=93c839897afe61e5
scope.4.id=function:_resolve_port
scope.4.kind=function
scope.4.startLine=23
scope.4.endLine=29
scope.4.semanticHash=d465204facb96181
scope.5.id=function:view_command_dispatcher.dispatch
scope.5.kind=function
scope.5.startLine=31
scope.5.endLine=42
scope.5.semanticHash=40c45f0dcd403c7a
]]
