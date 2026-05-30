local role_globals = {}

function role_globals.install(roles)
  local resolved = roles
  if type(resolved) ~= "table" then
    resolved = {}
  end
  _G["ALLROLES"] = resolved
  _G["all_roles"] = resolved
  return resolved
end

return role_globals

--[[ mutate4lua-manifest
version=2
projectHash=63d3e9a93660cc7e
scope.0.id=chunk:src/state/ui_role_globals.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=14
scope.0.semanticHash=41be3c1fd7f0069a
scope.1.id=function:role_globals.install:3
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=11
scope.1.semanticHash=beb8e27b1745fd02
]]
