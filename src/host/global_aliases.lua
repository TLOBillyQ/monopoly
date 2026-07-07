-- Host runtime seam for Eggy globals.
-- This file is a bridge exception, not a business compatibility alias layer.
local host_runtime_bridge = {}

local _REQUIRED_LUA_API_METHODS = {
  "call_delay_time",
  "global_register_custom_event",
  "global_register_trigger_event",
  "unit_register_custom_event",
  "unit_register_trigger_event",
  "global_send_custom_event",
}

local function _require_lua_api(lua_api)
  assert(lua_api ~= nil, "missing LuaAPI")
  for _, method_name in ipairs(_REQUIRED_LUA_API_METHODS) do
    assert(type(lua_api[method_name]) == "function", "missing LuaAPI." .. method_name)
  end
  return lua_api
end

function host_runtime_bridge.install(env)
  assert(env ~= nil, "missing runtime env")
  local lua_api = _require_lua_api(env.LuaAPI)

  if env.GameAPI ~= nil then
    GameAPI = env.GameAPI
  end
  LuaAPI = lua_api
  SetTimeOut = lua_api.call_delay_time
  RegisterCustomEvent = lua_api.global_register_custom_event
  UnregisterCustomEvent = lua_api.global_unregister_custom_event
  RegisterTriggerEvent = lua_api.global_register_trigger_event
  UnitCustomEvent = lua_api.unit_register_custom_event
  UnitTriggerEvent = lua_api.unit_register_trigger_event
  TriggerCustomEvent = lua_api.global_send_custom_event

  return {
    GameAPI = GameAPI,
    LuaAPI = LuaAPI,
  }
end

return host_runtime_bridge

--[[ mutate4lua-manifest
version=2
projectHash=47bb1ee59a97734e
scope.0.id=chunk:src/host/global_aliases.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=45
scope.0.semanticHash=f3c2aaf140b04787
scope.0.lastMutatedAt=2026-07-07T02:43:15Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=9
scope.0.lastMutationKilled=9
scope.1.id=function:host_runtime_bridge.install:22
scope.1.kind=function
scope.1.startLine=22
scope.1.endLine=42
scope.1.semanticHash=0d244413b86b0d01
scope.1.lastMutatedAt=2026-07-07T02:43:15Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=3
scope.1.lastMutationKilled=3
]]
