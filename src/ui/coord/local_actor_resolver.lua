local runtime = require("src.ui.render.runtime_ui")
local role_id_utils = require("src.foundation.identity")
local runtime_state = require("src.ui.state.runtime")

local resolver = {}

local function _cache_local_role_id(state, role_id)
  if not state then
    return
  end
  runtime_state.set_local_actor_role_id(state, role_id)
end

local function _resolve_role_id_from_event(state, data)
  local role = data and data.role or nil
  local role_id = runtime.resolve_role_id(role)
  if role_id ~= nil then
    _cache_local_role_id(state, role_id)
    return role_id
  end
  return nil
end

local function _resolve_client_role_id()
  return runtime.resolve_role_id(runtime.get_client_role())
end

local function _resolve_cached_role_id(state)
  return role_id_utils.normalize(runtime_state.get_local_actor_role_id(state))
end

function resolver.resolve_from_event(state, data)
  local role_id = _resolve_role_id_from_event(state, data)
  if role_id ~= nil then
    return role_id
  end

  role_id = _resolve_client_role_id()
  if role_id ~= nil then
    return role_id
  end

  return _resolve_cached_role_id(state)
end

resolver.resolve_turn_bound = resolver.resolve_from_event

resolver.resolve_local = resolver.resolve_from_event

return resolver
