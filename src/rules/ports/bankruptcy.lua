local bankruptcy = {}
local contract_helper = require("src.rules.ports.contract_helper")

function bankruptcy.eliminate(game, player, opts)
  return contract_helper.call_required_method(game, "bankruptcy_port", "bankruptcy_port", "eliminate", game, player, opts)
end

return bankruptcy

--[[ mutate4lua-manifest
version=2
projectHash=445b241b137641ef
scope.0.id=chunk:src/rules/ports/bankruptcy.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=9
scope.0.semanticHash=cf6e6a2b0424363f
scope.1.id=function:bankruptcy.eliminate:4
scope.1.kind=function
scope.1.startLine=4
scope.1.endLine=6
scope.1.semanticHash=514260ad8665e4a0
]]
