local runtime_global_aliases = {}

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

function runtime_global_aliases.install(env)
  assert(env ~= nil, "missing runtime env")
  local lua_api = _require_lua_api(env.LuaAPI)

  if env.GameAPI ~= nil then
    GameAPI = env.GameAPI
  end
  LuaAPI = lua_api
  SetTimeOut = lua_api.call_delay_time
  RegisterCustomEvent = lua_api.global_register_custom_event
  RegisterTriggerEvent = lua_api.global_register_trigger_event
  UnitCustomEvent = lua_api.unit_register_custom_event
  UnitTriggerEvent = lua_api.unit_register_trigger_event
  TriggerCustomEvent = lua_api.global_send_custom_event

  return {
    GameAPI = GameAPI,
    LuaAPI = LuaAPI,
  }
end

return runtime_global_aliases
