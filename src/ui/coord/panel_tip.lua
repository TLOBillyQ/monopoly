local tip_queue = require("src.foundation.tips")

local panel_tip = {}

function panel_tip.enqueue(source, text, key)
  tip_queue.enqueue({
    text = text,
    duration = 2.0,
    dedupe_key = key,
    blocks_inter_turn = false,
    source = source,
  })
end

return panel_tip

--[[ mutate4lua-manifest
version=4
projectHash=70bf260123e22f42
scope.0.id=chunk:src/ui/coord/panel_tip.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=16
scope.0.semanticHash=cdef50058a99ce10
scope.1.id=function:panel_tip.enqueue
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=13
scope.1.semanticHash=8d91547e56f51c13
]]
