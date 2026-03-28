local runtime = require("src.ui.render.runtime_ui")
local number_utils = require("src.core.utils.number_utils")
local role_id_utils = require("src.core.utils.role_id")
local runtime_state = require("src.ui.state")

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

local function _resolve_client_role_id(state)
  local current_role = runtime.get_client_role()
  local role_id = runtime.resolve_role_id(current_role)
  if role_id ~= nil then
    _cache_local_role_id(state, role_id)
    return role_id
  end
  return nil
end

local function _resolve_current_player_role_id(state)
  local current_model = state and runtime_state.get_ui_model(state) or nil
  local current_player_id = current_model and current_model.current_player_id or nil
  return number_utils.to_integer(current_player_id)
end

local function _resolve_cached_role_id(state)
  return role_id_utils.normalize(runtime_state.get_local_actor_role_id(state))
end

function resolver.resolve_from_event(state, data, opts)
  opts = opts or {}
  local local_only = opts.local_only == true
  local role_id = _resolve_role_id_from_event(state, data)
  if role_id ~= nil then
    return role_id
  end

  role_id = _resolve_client_role_id(state)
  if role_id ~= nil then
    return role_id
  end

  local cached = _resolve_cached_role_id(state)
  if cached ~= nil then
    return cached
  end

  if local_only then
    return nil
  end

  return _resolve_current_player_role_id(state)
end

function resolver.resolve_turn_bound(state, data)
  local role_id = _resolve_role_id_from_event(state, data)
  if role_id ~= nil then
    return role_id
  end

  role_id = _resolve_client_role_id(state)
  if role_id ~= nil then
    return role_id
  end

  role_id = _resolve_current_player_role_id(state)
  if role_id ~= nil then
    return role_id
  end

  return _resolve_cached_role_id(state)
end

function resolver.resolve_local(state)
  return resolver.resolve_from_event(state, nil, { local_only = true })
end

return resolver
