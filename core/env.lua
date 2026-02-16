local env_bindings = {}

local function _install_lua_api(lua_api)
  assert(lua_api ~= nil, "missing LuaAPI")
  assert(type(lua_api.call_delay_time) == "function", "missing LuaAPI.call_delay_time")
  assert(type(lua_api.global_register_custom_event) == "function", "missing LuaAPI.global_register_custom_event")
  assert(type(lua_api.global_register_trigger_event) == "function", "missing LuaAPI.global_register_trigger_event")
  assert(type(lua_api.unit_register_custom_event) == "function", "missing LuaAPI.unit_register_custom_event")
  assert(type(lua_api.unit_register_trigger_event) == "function", "missing LuaAPI.unit_register_trigger_event")
  assert(type(lua_api.global_send_custom_event) == "function", "missing LuaAPI.global_send_custom_event")
  SetTimeOut = lua_api.call_delay_time
  RegisterCustomEvent = lua_api.global_register_custom_event
  RegisterTriggerEvent = lua_api.global_register_trigger_event
  UnitCustomEvent = lua_api.unit_register_custom_event
  UnitTriggerEvent = lua_api.unit_register_trigger_event
  TriggerCustomEvent = lua_api.global_send_custom_event
end

function env_bindings.install(env)
  assert(env ~= nil, "missing runtime env")
  if env.GameAPI ~= nil then
    GameAPI = env.GameAPI
  end
  if env.LuaAPI ~= nil then
    LuaAPI = env.LuaAPI
  end
  _install_lua_api(LuaAPI)
  return {
    GameAPI = GameAPI,
    LuaAPI = LuaAPI,
  }
end

return env_bindings
