local M = {}

function M.with_method(host_runtime, method_name)
  if not (host_runtime and type(host_runtime[method_name]) == "function") then
    return nil
  end
  return host_runtime
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=7e583834274ff793
scope.0.id=chunk:src/ui/render/board_feedback/host_runtime.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=11
scope.0.semanticHash=428948cb7cc0d5d0
scope.1.id=function:M.with_method
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=8
scope.1.semanticHash=6f1d5b4f92b718f6
]]
