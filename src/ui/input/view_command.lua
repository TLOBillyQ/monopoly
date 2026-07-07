local view_command_dispatcher = {}
local panel_interrupt = require("src.ui.coord.panel_interrupt")
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

local function _resolve_port(state)
  local ports = state and state.gameplay_loop_ports or nil
  local view_command = ports and ports.view_command or nil
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
version=2
projectHash=8bc5bd6bbdda2d97
scope.0.id=chunk:src/ui/input/view_command.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=44
scope.0.semanticHash=3d940dfb7011707e
scope.0.lastMutatedAt=2026-06-05T07:26:59Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=5
scope.0.lastMutationKilled=5
scope.1.id=function:_intent_panel_id:11
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=13
scope.1.semanticHash=7011b93f246294da
scope.1.lastMutatedAt=2026-06-05T07:26:59Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=1
scope.1.lastMutationKilled=1
scope.2.id=function:_dispatch_via_ports:15
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=22
scope.2.semanticHash=8150b80ab9135464
scope.2.lastMutatedAt=2026-06-05T07:26:59Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=12
scope.2.lastMutationKilled=12
scope.3.id=function:_blocks_panel_entry:24
scope.3.kind=function
scope.3.startLine=24
scope.3.endLine=30
scope.3.semanticHash=51c672a3215ccd5f
scope.3.lastMutatedAt=2026-06-05T07:26:59Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=6
scope.3.lastMutationKilled=6
scope.4.id=function:view_command_dispatcher.dispatch:32
scope.4.kind=function
scope.4.startLine=32
scope.4.endLine=41
scope.4.semanticHash=ca33f4952f3e125e
scope.4.lastMutatedAt=2026-06-05T07:26:59Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=5
scope.4.lastMutationKilled=5
]]
