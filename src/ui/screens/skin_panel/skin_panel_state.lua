local cosmetics_port = require("src.ui.seams.cosmetics").build()
local transaction_state = cosmetics_port.transaction_state

local state = {}

function state.ensure(root_state)
  local panel, err = transaction_state.ensure_panel(root_state)
  return assert(panel, err or "missing_state")
end

return state

--[[ mutate4lua-manifest
version=4
projectHash=cd3478f7c79c34bc
scope.0.id=chunk:src/ui/screens/skin_panel/skin_panel_state.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=12
scope.0.semanticHash=6caf707ab04b9163
scope.1.id=function:state.ensure
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=9
scope.1.semanticHash=05d883e718a809c1
]]
