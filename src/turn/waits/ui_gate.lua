local timing = require("src.config.gameplay.timing")
local number_utils = require("src.foundation.number")

local tick_ui_gate = {}

local _fallback_gate = {
  input_blocked = false,
  choice_active = false,
  market_active = false,
  popup_active = false,
  popup_seq = nil,
  popup_auto_close_seconds = nil,
  popup_owner_index = nil,
}

local function _ports_ui_sync(state)
  return state and state.gameplay_loop_ports and state.gameplay_loop_ports.ui_sync or nil
end

local function _resolve_ui_gate(state, resolver)
  if resolver and type(resolver.resolve_ui_gate) == "function" then
    local gate = resolver.resolve_ui_gate(state)
    if type(gate) == "table" then
      return gate
    end
  end
  return nil
end

function tick_ui_gate.resolve_ui_gate(state, ui_sync_ports)
  local resolver = ui_sync_ports or _ports_ui_sync(state)
  local gate = _resolve_ui_gate(state, resolver)
  if gate ~= nil then
    return gate
  end
  return _fallback_gate
end

function tick_ui_gate.resolve_modal_timeout_seconds(state, ui_sync_ports)
  local gate = tick_ui_gate.resolve_ui_gate(state, ui_sync_ports)
  local auto_close_seconds = gate.popup_auto_close_seconds
  if auto_close_seconds ~= nil and number_utils.is_numeric(auto_close_seconds) and auto_close_seconds > 0 then
    return auto_close_seconds
  end
  return timing.popup_auto_close_seconds
end

return tick_ui_gate

--[[ mutate4lua-manifest
version=4
projectHash=459d5d9756c1ceb2
scope.0.id=chunk:src/turn/waits/ui_gate.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=49
scope.0.semanticHash=a300e3f84f0c7a1f
scope.1.id=function:_ports_ui_sync
scope.1.kind=function
scope.1.startLine=16
scope.1.endLine=18
scope.1.semanticHash=c250138038aa193a
scope.2.id=function:_resolve_ui_gate
scope.2.kind=function
scope.2.startLine=20
scope.2.endLine=28
scope.2.semanticHash=121c9093f3e6bbc9
scope.3.id=function:tick_ui_gate.resolve_ui_gate
scope.3.kind=function
scope.3.startLine=30
scope.3.endLine=37
scope.3.semanticHash=b92a47343d050954
scope.4.id=function:tick_ui_gate.resolve_modal_timeout_seconds
scope.4.kind=function
scope.4.startLine=39
scope.4.endLine=46
scope.4.semanticHash=0bd831f6510e3893
]]
