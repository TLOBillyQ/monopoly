local bankruptcy = {}
local contract_helper = require("src.rules.ports.contract_helper")

function bankruptcy.eliminate(game, player, opts)
  return contract_helper.call_required_method(game, "bankruptcy_port", "bankruptcy_port", "eliminate", game, player, opts)
end

return bankruptcy

--[[ mutate4lua-manifest
version=4
projectHash=801a0b7498e572c0
scope.0.id=chunk:src/rules/ports/bankruptcy.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=9
scope.0.semanticHash=6c4317e9dd7629c5
scope.1.id=function:bankruptcy.eliminate
scope.1.kind=function
scope.1.startLine=4
scope.1.endLine=6
scope.1.semanticHash=5225d4c6399d0b12
]]
