local bankruptcy_feedback = {}
local contract_helper = require("src.rules.ports.contract_helper")

function bankruptcy_feedback.on_tiles_cleared(game, player, owned_tile_ids)
  return contract_helper.call_required_method(game, "bankruptcy_feedback_port", "bankruptcy_feedback_port", "on_tiles_cleared", game, player, owned_tile_ids)
end

return bankruptcy_feedback

--[[ mutate4lua-manifest
version=4
projectHash=eac61528270caa3f
scope.0.id=chunk:src/rules/ports/bankruptcy_feedback.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=9
scope.0.semanticHash=6c4317e9dd7629c5
scope.1.id=function:bankruptcy_feedback.on_tiles_cleared
scope.1.kind=function
scope.1.startLine=4
scope.1.endLine=6
scope.1.semanticHash=5225d4c6399d0b12
]]
