local host_runtime_ports = require("src.ui.host_bridge")
local runtime_deps = {}

function runtime_deps.build(opts)
  return {
    runtime = require("src.ui.render.runtime_ui"),
    host_runtime = host_runtime_ports,
    ui_events = require("src.ui.coord.ui_events"),
    modal_state = require("src.ui.state.modal"),
    ui_touch_policy = require("src.ui.input.touch"),
    camera_sync = opts and opts.camera_sync or nil,
  }
end

return runtime_deps

--[[ mutate4lua-manifest
version=2
projectHash=9bcd940138835132
scope.0.id=chunk:src/ui/coord/deps.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=16
scope.0.semanticHash=261c9edaac105935
scope.1.id=function:runtime_deps.build:4
scope.1.kind=function
scope.1.startLine=4
scope.1.endLine=13
scope.1.semanticHash=b06b50a41c0bbeb3
]]
