local nodes = require("src.ui.schema.base")
local debug_nodes = require("src.ui.schema.debug")

return {
  key = "base",
  canvas = nodes.canvas,
  action_log = {
    label = debug_nodes.log_text,
    toggle_targets = { nodes.action_log_button },
  },
}

--[[ mutate4lua-manifest
version=2
projectHash=538cb0ece1037216
scope.0.id=chunk:src/ui/schema/base_contract.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=12
scope.0.semanticHash=c8503b1b8975e0bd
]]
