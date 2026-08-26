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
version=4
projectHash=b9969331c645056e
scope.0.id=chunk:src/state/ui_role_globals.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=14
scope.0.semanticHash=44d3ad7fd026489c
scope.1.id=function:role_globals.install
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=11
scope.1.semanticHash=38c06187758750ac
]]
