local host_runtime_bridge = require("src.ui.host_bridge")

local M = {}

function M.from_deps(deps)
  if deps and deps.host_runtime then
    return deps.host_runtime
  end
  return host_runtime_bridge
end

function M.from_state(state_or_scene, deps)
  local resolved_deps = deps or (state_or_scene and state_or_scene.presentation_runtime) or nil
  return M.from_deps(resolved_deps)
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=d362e85d97f4f0f5
scope.0.id=chunk:src/ui/render/host_runtime_resolver.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=18
scope.0.semanticHash=07c3d82703d1bc7b
scope.1.id=function:M.from_deps:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=10
scope.1.semanticHash=d127040e7b69fae0
scope.2.id=function:M.from_state:12
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=15
scope.2.semanticHash=0b7a92dda993dca9
]]
