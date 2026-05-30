local function with_client_role(runtime, role, fn)
  assert(runtime ~= nil, "missing runtime")
  assert(type(fn) == "function", "missing fn")
  if type(runtime.with_client_role) == "function" then
    return runtime.with_client_role(role, fn)
  end
  if type(runtime.set_client_role) ~= "function" then
    return fn()
  end
  runtime.set_client_role(role)
  local ok, err = pcall(fn)
  runtime.set_client_role(nil)
  if not ok then
    error(err)
  end
end

return with_client_role

--[[ mutate4lua-manifest
version=2
projectHash=e8da893f4ff50bad
scope.0.id=chunk:src/ui/utils/with_client_role.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=19
scope.0.semanticHash=2aea491b8a5c17b8
scope.1.id=function:with_client_role:1
scope.1.kind=function
scope.1.startLine=1
scope.1.endLine=16
scope.1.semanticHash=c48f38019db6b828
]]
