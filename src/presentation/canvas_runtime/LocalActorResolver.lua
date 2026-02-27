local runtime = require("src.presentation.api.UIRuntimePort")

local resolver = {}

local function _cache_local_role_id(state, role_id)
  if not state or not state.ui then
    return
  end
  if role_id ~= nil then
    state.ui.local_actor_role_id = role_id
  end
end

function resolver.resolve_from_event(state, data)
  local role = data and data.role or nil
  local role_id = runtime.resolve_role_id(role)
  if role_id ~= nil then
    _cache_local_role_id(state, role_id)
    return role_id
  end

  local current_role = runtime.get_client_role()
  role_id = runtime.resolve_role_id(current_role)
  if role_id ~= nil then
    _cache_local_role_id(state, role_id)
    return role_id
  end

  local cached = state and state.ui and state.ui.local_actor_role_id or nil
  if cached ~= nil then
    return cached
  end
  return nil
end

function resolver.resolve_local(state)
  return resolver.resolve_from_event(state, nil)
end

return resolver
