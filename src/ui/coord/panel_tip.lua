local host_runtime_ports = require("src.ui.host_bridge")

local panel_tip = {}

function panel_tip.enqueue(source, text, key)
  host_runtime_ports.enqueue_tip({
    text = text,
    duration = 2.0,
    dedupe_key = key,
    blocks_inter_turn = false,
    source = source,
  })
end

return panel_tip

--[[ mutate4lua-manifest
version=2
projectHash=4d8eadd9b8f58d20
scope.0.id=chunk:src/ui/coord/panel_tip.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=16
scope.0.semanticHash=5d827a43107372f6
scope.1.id=function:panel_tip.enqueue:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=13
scope.1.semanticHash=a6c73f6c26762876
]]
