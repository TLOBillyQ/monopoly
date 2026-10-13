require("test.bootstrap").install_package_paths()
-- busted injects luassert fields on assert.
-- luacheck: ignore 143
local luassert = assert
local support = require("test.support.shared_support")
local global_aliases = require("src.host.global_aliases")

local function _assert_eq(actual, expected, message)
  luassert.is.equal(expected, actual, message)
end

local _config_reset = require("test.support.config_reset")

local function _build_env()
  local lua_api = {
    call_delay_time = function() end,
    global_register_custom_event = function() end,
    global_unregister_custom_event = function() end,
    global_register_trigger_event = function() end,
    global_unregister_trigger_event = function() end,
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

describe("TestGlobalAliases", function()
  before_each(function()
    _config_reset.reset_all()
  end)

local function _test_install_sets_required_global_aliases()
  local env, game_api, lua_api = _build_env()
  support.with_patches({
    { key = "GameAPI", value = nil },
    { key = "LuaAPI", value = nil },
    { key = "SetTimeOut", value = nil },
    { key = "RegisterCustomEvent", value = nil },
    { key = "UnregisterCustomEvent", value = nil },
    { key = "RegisterTriggerEvent", value = nil },
    { key = "UnregisterTriggerEvent", value = nil },
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
    _assert_eq(
      UnregisterTriggerEvent,
      lua_api.global_unregister_trigger_event,
      "install should expose UnregisterTriggerEvent"
    )
    _assert_eq(UnitCustomEvent, lua_api.unit_register_custom_event, "install should expose UnitCustomEvent")
    _assert_eq(UnitTriggerEvent, lua_api.unit_register_trigger_event, "install should expose UnitTriggerEvent")
    _assert_eq(TriggerCustomEvent, lua_api.global_send_custom_event, "install should expose TriggerCustomEvent")
  end)
end

local function _test_install_rejects_a_luaapi_missing_any_required_method()
  local required_methods = {
    "call_delay_time",
    "global_register_custom_event",
    "global_register_trigger_event",
    "global_unregister_trigger_event",
    "unit_register_custom_event",
    "unit_register_trigger_event",
    "global_send_custom_event",
  }
  for _, method_name in ipairs(required_methods) do
    local env = _build_env()
    env.LuaAPI[method_name] = nil
    local ok, err = pcall(global_aliases.install, env)
    luassert.truthy(not ok, "install should reject LuaAPI missing " .. method_name)
    luassert.truthy(
      tostring(err):find("missing LuaAPI." .. method_name, 1, true),
      "error should name the missing method: " .. tostring(err)
    )
  end
end

local function _test_install_asserts_missing_env_and_luaapi()
  -- #293:install(nil) 与 env.LuaAPI 缺失的断言消息未测,消息位点变异存活。
  local ok_env, err_env = pcall(global_aliases.install, nil)
  luassert.truthy(not ok_env, "install should reject a missing env")
  luassert.truthy(tostring(err_env):find("missing runtime env", 1, true) ~= nil,
    "missing-env assert should carry its message: " .. tostring(err_env))

  local ok_api, err_api = pcall(global_aliases.install, {})
  luassert.truthy(not ok_api, "install should reject a LuaAPI-less env")
  luassert.truthy(tostring(err_api):find("missing LuaAPI", 1, true) ~= nil,
    "missing-LuaAPI assert should carry its message: " .. tostring(err_api))
end


it("test_install_sets_required_global_aliases", _test_install_sets_required_global_aliases)
it("test_install_rejects_a_luaapi_missing_any_required_method", _test_install_rejects_a_luaapi_missing_any_required_method)
it("test_install_asserts_missing_env_and_luaapi", _test_install_asserts_missing_env_and_luaapi)
end)
