local runtime = require("src.presentation.api.UIRuntimePort")

local resolver = {}

function resolver.resolve_from_event(state, data)
  local role = data and data.role or nil
  local role_id = runtime.resolve_role_id(role)
  if role_id ~= nil then
    return role_id
  end

  local current_role = runtime.get_client_role()
  role_id = runtime.resolve_role_id(current_role)
  if role_id ~= nil then
    return role_id
  end
  return nil
end

function resolver.resolve_local(state)
  return resolver.resolve_from_event(state, nil)
end

return resolver
