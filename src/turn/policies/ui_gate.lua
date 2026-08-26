-- The UI sync gate is optional: headless lanes and the no-UI gameplay guard run
-- without ui_sync ports installed. Both the action validator and the auto-play
-- context need the same "ask the port if it is there, otherwise no gate" rule,
-- so it lives here rather than being restated at each call site.
local ui_gate = {}

function ui_gate.resolve(state, ui_sync_ports)
  if ui_sync_ports and type(ui_sync_ports.resolve_ui_gate) == "function" then
    return ui_sync_ports.resolve_ui_gate(state)
  end
  return nil
end

return ui_gate

--[[ mutate4lua-manifest
version=4
projectHash=5c7fffbfc201a2b8
scope.0.id=chunk:src/turn/policies/ui_gate.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=15
scope.0.semanticHash=3602766acf8b8b7a
scope.1.id=function:ui_gate.resolve
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=12
scope.1.semanticHash=45f66a2f06b983ec
]]
