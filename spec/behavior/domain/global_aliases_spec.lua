local support = require("support.domain_support")
local global_aliases = require("src.host.global_aliases")

local _assert_eq = support.assert_eq

local function _build_env()
  local lua_api = {
    call_delay_time = function() end,
    global_register_custom_event = function() end,
    global_unregister_custom_event = function() end,
    global_register_trigger_event = function() end,
    unit_register_custom_event = function() end,
    unit_register_trigger_event = function() end,
    global_send_custom_event = function() end,
  }
  local game_api = {}
  return {
    GameAPI = game_api,
    LuaAPI = lua_api,
  }, game_api, lua_api
end

describe("global_aliases", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("install sets required global aliases", function()
    local env, game_api, lua_api = _build_env()
    support.with_patches({
      { key = "GameAPI", value = nil },
      { key = "LuaAPI", value = nil },
      { key = "SetTimeOut", value = nil },
      { key = "RegisterCustomEvent", value = nil },
      { key = "UnregisterCustomEvent", value = nil },
      { key = "RegisterTriggerEvent", value = nil },
      { key = "UnitCustomEvent", value = nil },
      { key = "UnitTriggerEvent", value = nil },
      { key = "TriggerCustomEvent", value = nil },
    }, function()
      global_aliases.install(env)

      _assert_eq(GameAPI, game_api, "install should expose GameAPI")
      _assert_eq(LuaAPI, lua_api, "install should expose LuaAPI")
      _assert_eq(SetTimeOut, lua_api.call_delay_time, "install should expose SetTimeOut")
      _assert_eq(RegisterCustomEvent, lua_api.global_register_custom_event, "install should expose RegisterCustomEvent")
      _assert_eq(
        UnregisterCustomEvent,
        lua_api.global_unregister_custom_event,
        "install should expose UnregisterCustomEvent"
      )
      _assert_eq(RegisterTriggerEvent, lua_api.global_register_trigger_event, "install should expose RegisterTriggerEvent")
      _assert_eq(UnitCustomEvent, lua_api.unit_register_custom_event, "install should expose UnitCustomEvent")
      _assert_eq(UnitTriggerEvent, lua_api.unit_register_trigger_event, "install should expose UnitTriggerEvent")
      _assert_eq(TriggerCustomEvent, lua_api.global_send_custom_event, "install should expose TriggerCustomEvent")
    end)
  end)
end)
