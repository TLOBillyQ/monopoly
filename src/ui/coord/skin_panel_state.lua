local transaction_state = require("src.app.cosmetics.transaction_state")

local state = {}

function state.ensure(root_state)
  local panel, err = transaction_state.ensure_panel(root_state)
  return assert(panel, err or "missing_state")
end

function state.role_key(role_id)
  return assert(transaction_state.role_key(role_id), "missing role_id")
end

return state

--[[ mutate4lua-manifest
version=2
projectHash=93e34ecc66ee70ae
scope.0.id=chunk:src/ui/coord/skin_panel_state.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=20
scope.0.semanticHash=0172e15ec350c3ff
scope.1.id=function:state.ensure:3
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=13
scope.1.semanticHash=e96d220fb2c1c432
scope.1.lastMutatedAt=2026-06-05T07:32:29Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=5
scope.1.lastMutationKilled=5
scope.2.id=function:state.role_key:15
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=17
scope.2.semanticHash=cfeb2cbf0f9f9cee
scope.2.lastMutatedAt=2026-06-05T07:32:29Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=1
scope.2.lastMutationKilled=1
]]
