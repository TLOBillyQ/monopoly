local M = {}

function M.with_method(host_runtime, method_name)
  if not (host_runtime and type(host_runtime[method_name]) == "function") then
    return nil
  end
  return host_runtime
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=44608142256a5456
scope.0.id=chunk:src/ui/render/board_feedback/host_runtime.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=11
scope.0.semanticHash=c0620bcfec3f5984
scope.1.id=function:M.with_method:3
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=8
scope.1.semanticHash=78f4720bed58a1a2
scope.1.lastMutatedAt=2026-06-24T20:12:26Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=5
scope.1.lastMutationKilled=5
]]
