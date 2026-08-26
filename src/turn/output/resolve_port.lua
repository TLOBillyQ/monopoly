local M = {}

local function _resolved_ports(state)
  return state and (state._resolved_gameplay_loop_ports or state.gameplay_loop_ports) or nil
end

local function _sub_port(resolved, sub_key)
  return type(resolved) == "table" and resolved[sub_key] or nil
end

function M.resolve(state, sub_key, fallback)
  local sub = _sub_port(_resolved_ports(state), sub_key)
  if type(sub) == "table" then
    return sub
  end
  return fallback
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=2c2128283f9e5218
scope.0.id=chunk:src/turn/output/resolve_port.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=20
scope.0.semanticHash=06f94dabc32ddb4d
scope.1.id=function:_resolved_ports
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=5
scope.1.semanticHash=d692619e49063104
scope.2.id=function:_sub_port
scope.2.kind=function
scope.2.startLine=7
scope.2.endLine=9
scope.2.semanticHash=a6671db2ff301cf8
scope.3.id=function:M.resolve
scope.3.kind=function
scope.3.startLine=11
scope.3.endLine=17
scope.3.semanticHash=d602e9a24ea4db65
]]
