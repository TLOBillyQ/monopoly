local host_runtime_ports = require("src.ui.seams.host_runtime")

local M = {}

function M.from_deps(deps)
  if deps and deps.host_runtime then
    return deps.host_runtime
  end
  return host_runtime_ports
end

function M.from_state(state_or_scene, deps)
  local resolved_deps = deps or (state_or_scene and state_or_scene.presentation_runtime) or nil
  return M.from_deps(resolved_deps)
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=517ba44bc7b52149
scope.0.id=chunk:src/ui/render/support/host_runtime_resolver.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=18
scope.0.semanticHash=4a1a275868f08e5b
scope.1.id=function:M.from_deps
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=10
scope.1.semanticHash=1304769284a0d924
scope.2.id=function:M.from_state
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=15
scope.2.semanticHash=e44a18b40b52f71a
]]
