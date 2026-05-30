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

--[[ mutate4lua-manifest
version=2
projectHash=c262d540e78ed100
scope.0.id=chunk:src/ui/coord/local_actor_resolver.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=51
scope.0.semanticHash=803e6bd5db6364ef
scope.1.id=function:_cache_local_role_id:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=12
scope.1.semanticHash=f4e4d39778ff0ebe
scope.2.id=function:_resolve_role_id_from_event:14
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=22
scope.2.semanticHash=e44c7e5ce8d46fb1
scope.3.id=function:_resolve_client_role_id:24
scope.3.kind=function
scope.3.startLine=24
scope.3.endLine=26
scope.3.semanticHash=c7f55e1a803e36e9
scope.4.id=function:_resolve_cached_role_id:28
scope.4.kind=function
scope.4.startLine=28
scope.4.endLine=30
scope.4.semanticHash=7e2927354ac46a76
scope.5.id=function:resolver.resolve_from_event:32
scope.5.kind=function
scope.5.startLine=32
scope.5.endLine=44
scope.5.semanticHash=1113699222bd51c7
]]
