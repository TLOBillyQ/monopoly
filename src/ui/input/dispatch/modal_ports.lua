local M = {}

function M.resolve(state)
  local ports = state and state.gameplay_loop_ports or nil
  return ports and ports.modal or {}
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=49808f49db945507
scope.0.id=chunk:src/ui/input/dispatch/modal_ports.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=9
scope.0.semanticHash=f3e011a118694b87
scope.1.id=function:M.resolve:3
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=6
scope.1.semanticHash=464a131ab646beef
]]
