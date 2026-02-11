local bootstrap = {}

local function _resolve_lua_api()
  if LuaAPI == nil then
    LuaAPI = {}
    return LuaAPI
  end
  if type(LuaAPI) == "table" then
    return LuaAPI
  end
  local raw_api = LuaAPI
  local proxy = setmetatable({}, {
    __index = function(_, key)
      return raw_api[key]
    end,
  })
  _G.LuaAPI = proxy
  return proxy
end

function bootstrap.load_behavior()
  if not math.tofixed then
    math.tofixed = function(value)
      return value
    end
  end
  if type(EVENT) ~= "table" then
    EVENT = { REPEAT_TIMEOUT = "REPEAT_TIMEOUT" }
  elseif EVENT.REPEAT_TIMEOUT == nil then
    EVENT.REPEAT_TIMEOUT = "REPEAT_TIMEOUT"
  end
  if type(RegisterTriggerEvent) ~= "function" then
    RegisterTriggerEvent = function()
      return {}
    end
  end
  local lua_api = _resolve_lua_api()
  if type(lua_api.global_unregister_trigger_event) ~= "function" then
    lua_api.global_unregister_trigger_event = function() end
  end
  if type(SetFrameOut) ~= "function" then
    SetFrameOut = function()
      return { frame = 0 }
    end
  end
  require("vendor.third_party.ClassUtils")
  return require("vendor.third_party.Behavior.config")
end

return bootstrap
