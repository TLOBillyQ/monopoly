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

function tick_ui_gate.resolve_ui_gate(state, ui_sync_ports)
  local resolver = ui_sync_ports
  if not resolver and state and state.gameplay_loop_ports and state.gameplay_loop_ports.ui_sync then
    resolver = state.gameplay_loop_ports.ui_sync
  end
  if resolver and type(resolver.resolve_ui_gate) == "function" then
    local gate = resolver.resolve_ui_gate(state)
    if type(gate) == "table" then
      return gate
    end
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
version=2
projectHash=889693f6e99cd78e
scope.0.id=chunk:src/turn/waits/ui_gate.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=40
scope.0.semanticHash=ee3fa882d6be4094
scope.1.id=function:tick_ui_gate.resolve_ui_gate:16
scope.1.kind=function
scope.1.startLine=16
scope.1.endLine=28
scope.1.semanticHash=a17db5faed96e8a2
scope.2.id=function:tick_ui_gate.resolve_modal_timeout_seconds:30
scope.2.kind=function
scope.2.startLine=30
scope.2.endLine=37
scope.2.semanticHash=3a98a2bac092bc18
]]
