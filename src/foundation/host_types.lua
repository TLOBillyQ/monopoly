local host_types = {}

local function _make_constructor(host_key)
  return function(x, y, z)
    if math and math[host_key] then
      return math[host_key](x, y, z)
    end
    return { x = x, y = y, z = z }
  end
end

host_types.vec3 = _make_constructor("Vector3")
host_types.quat = _make_constructor("Quaternion")

return host_types

--[[ mutate4lua-manifest
version=2
projectHash=e3f4a4a0e9ca4706
scope.0.id=chunk:src/foundation/host_types.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=16
scope.0.semanticHash=ea6c20795794741c
scope.0.lastMutatedAt=2026-05-27T14:37:24Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=2
scope.0.lastMutationKilled=2
scope.1.id=function:anonymous@4:4
scope.1.kind=function
scope.1.startLine=4
scope.1.endLine=9
scope.1.semanticHash=7fa1ed7922c87485
scope.1.lastMutatedAt=2026-05-27T14:37:24Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=1
scope.1.lastMutationKilled=1
scope.2.id=function:_make_constructor:3
scope.2.kind=function
scope.2.startLine=3
scope.2.endLine=10
scope.2.semanticHash=64de02796da7d77f
]]
