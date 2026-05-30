local M = {}

function M.resolve(state, sub_key, fallback)
  local resolved = state and (state._resolved_gameplay_loop_ports or state.gameplay_loop_ports) or nil
  local sub = type(resolved) == "table" and resolved[sub_key] or nil
  if type(sub) == "table" then
    return sub
  end
  return fallback
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=73165cdb697f7de3
scope.0.id=chunk:src/turn/loop/resolve_port.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=13
scope.0.semanticHash=d4b60f5d7c23b829
scope.1.id=function:M.resolve:3
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=10
scope.1.semanticHash=aaf6d1df1721b583
]]
