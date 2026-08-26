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
version=4
projectHash=1e7caa6b37d134a3
scope.0.id=chunk:src/ui/render/support/with_client_role.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=19
scope.0.semanticHash=3805a0121ee76424
scope.1.id=function:with_client_role
scope.1.kind=function
scope.1.startLine=1
scope.1.endLine=16
scope.1.semanticHash=49744ae90ffdd00a
]]
