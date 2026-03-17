local runtime = require("src.ui.render.runtime_ui")
local number_utils = require("src.core.utils.number_utils")
local role_id_utils = require("src.core.utils.role_id")
local runtime_state = require("src.ui.ctl.ports.runtime_state_seam")

local resolver = {}

local function _cache_local_role_id(state, role_id)
  if not state then
    return
  end
  state.local_actor_role_id = role_id
end

function resolver.resolve_from_event(state, data, opts)
  opts = opts or {}
  local local_only = opts.local_only == true
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

  local cached = role_id_utils.normalize(state and state.local_actor_role_id or nil)
  if cached ~= nil then
    return cached
  end

  if local_only then
    return nil
  end

  local current_model = state and runtime_state.get_ui_model(state) or nil
  local current_player_id = current_model and current_model.current_player_id or nil
  local fallback = number_utils.to_integer(current_player_id)
  return fallback
end

function resolver.resolve_local(state)
  return resolver.resolve_from_event(state, nil, { local_only = true })
end

return resolver
