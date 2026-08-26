local runtime = require("src.ui.render.support.runtime_ui")
local host_roles = require("src.ui.seams.host_roles")
local role_id_utils = require("src.foundation.identity")

local actor_context = {}

local function _find_role_in_roster(role_id)
  local roles = host_roles.resolve_roles()
  if type(roles) ~= "table" then
    return nil
  end
  for _, role in ipairs(roles) do
    if role_id_utils.equals(runtime.resolve_role_id(role), role_id) then
      return role
    end
  end
  return nil
end

-- 宿主名册里找不到时退化成一个只认得自己 id 的最小 role stub。
function actor_context.resolve_role_by_id(role_id)
  role_id = role_id_utils.normalize(role_id)
  if role_id == nil then
    return runtime.get_client_role()
  end
  local role = _find_role_in_roster(role_id)
  if role ~= nil then
    return role
  end
  local resolved = host_roles.resolve_role_with(role_id)
  if resolved ~= nil then
    return resolved
  end
  return {
    get_roleid = function()
      return role_id
    end,
  }
end

return actor_context

--[[ mutate4lua-manifest
version=4
projectHash=1e0c0a596db7c972
scope.0.id=chunk:src/ui/coord/actor_context.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=42
scope.0.semanticHash=47dc1d3a0d758c15
scope.1.id=function:_find_role_in_roster
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=18
scope.1.semanticHash=f65734ed134c7370
scope.2.id=function:actor_context.resolve_role_by_id
scope.2.kind=function
scope.2.startLine=21
scope.2.endLine=39
scope.2.semanticHash=823343e642df010c
scope.3.id=function:<anonymous>
scope.3.kind=function
scope.3.startLine=35
scope.3.endLine=37
scope.3.semanticHash=1136505bd37c301e
]]
