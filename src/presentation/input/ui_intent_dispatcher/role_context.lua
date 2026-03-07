local runtime = require("src.presentation.runtime.ui_runtime_port")
local host_runtime = require("src.presentation.runtime.host_runtime_port")
local role_id_utils = require("src.core.utils.role_id")

local role_context = {}

function role_context.resolve_by_id(role_id)
  role_id = role_id_utils.normalize(role_id)
  if role_id == nil then
    return runtime.get_client_role()
  end
  local roles = host_runtime.resolve_roles()
  if type(roles) == "table" then
    for _, role in ipairs(roles) do
      if role_id_utils.equals(runtime.resolve_role_id(role), role_id) then
        return role
      end
    end
  end
  local resolved = host_runtime.resolve_role(role_id)
  if resolved ~= nil then
    return resolved
  end
  return {
    get_roleid = function()
      return role_id
    end,
  }
end

return role_context
