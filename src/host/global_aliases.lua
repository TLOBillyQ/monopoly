-- Host runtime seam for Eggy globals.
-- This file is a bridge exception, not a business compatibility alias layer.
local host_runtime_bridge = {}

local function _require_lua_api(lua_api)
  assert(lua_api ~= nil, "missing LuaAPI")
  assert(type(lua_api.call_delay_time) == "function", "missing LuaAPI.call_delay_time")
  assert(type(lua_api.global_register_custom_event) == "function", "missing LuaAPI.global_register_custom_event")
  assert(type(lua_api.global_register_trigger_event) == "function", "missing LuaAPI.global_register_trigger_event")
  assert(type(lua_api.unit_register_custom_event) == "function", "missing LuaAPI.unit_register_custom_event")
  assert(type(lua_api.unit_register_trigger_event) == "function", "missing LuaAPI.unit_register_trigger_event")
  assert(type(lua_api.global_send_custom_event) == "function", "missing LuaAPI.global_send_custom_event")
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
projectHash=463c87adc3dccf65
scope.0.id=chunk:src/host/global_aliases.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=39
scope.0.semanticHash=8af67667b42e1256
scope.1.id=function:_require_lua_api:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=14
scope.1.semanticHash=2315041359e93a31
scope.2.id=function:host_runtime_bridge.install:16
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=36
scope.2.semanticHash=0d244413b86b0d01
]]
