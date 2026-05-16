local runtime = require("src.ui.render.runtime_ui")
local host_runtime_ports = require("src.ui.host_bridge")
local local_actor_resolver = require("src.ui.coord.local_actor_resolver")
local role_id_utils = require("src.foundation.identity")

local actor_context = {}

actor_context.resolve_local_actor_role_id = local_actor_resolver.resolve_local

function actor_context.resolve_role_by_id(role_id)
  role_id = role_id_utils.normalize(role_id)
  if role_id == nil then
    return runtime.get_client_role()
  end
  local roles = host_runtime_ports.resolve_roles()
  if type(roles) == "table" then
    for _, role in ipairs(roles) do
      if role_id_utils.equals(runtime.resolve_role_id(role), role_id) then
        return role
      end
    end
  end
  local resolved = host_runtime_ports.resolve_role_with(role_id)
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
