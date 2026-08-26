local registry = {}

local handlers = {}

function registry.register(kind, handler)
  assert(kind ~= nil and kind ~= "", "missing kind")
  assert(type(handler) == "function", "missing handler")
  handlers[kind] = handler
end

function registry.resolve(kind)
  return handlers[kind]
end

return registry

--[[ mutate4lua-manifest
version=4
projectHash=725c69da614023a4
scope.0.id=chunk:src/ui/render/anim/registry.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=16
scope.0.semanticHash=403addc2b618f7de
scope.1.id=function:registry.register
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=9
scope.1.semanticHash=38656b3ef9afe105
scope.2.id=function:registry.resolve
scope.2.kind=function
scope.2.startLine=11
scope.2.endLine=13
scope.2.semanticHash=fc8eda1d7903d2b1
]]
