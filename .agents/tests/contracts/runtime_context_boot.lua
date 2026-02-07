local runtime_context = require("src.core.RuntimeContext")

local function _assert_eq(a, b, msg)
  if a ~= b then
    error((msg or "assert failed") .. " | expected=" .. tostring(b) .. " got=" .. tostring(a))
  end
end

local lua_api = {
  call_delay_time = function() end,
  global_register_custom_event = function() end,
  global_register_trigger_event = function() end,
  unit_register_custom_event = function() end,
  unit_register_trigger_event = function() end,
  global_send_custom_event = function() end,
}

local game_api = {
  get_all_valid_roles = function()
    return { 1, 2, 3 }
  end,
}

local ctx = runtime_context.new({
  GameAPI = game_api,
  LuaAPI = lua_api,
})

runtime_context.set_current(ctx)
runtime_context.install_globals(ctx)

_assert_eq(GameAPI, game_api, "GameAPI installed")
_assert_eq(LuaAPI, lua_api, "LuaAPI installed")
_assert_eq(type(SetTimeOut), "function", "SetTimeOut installed")
_assert_eq(type(TriggerCustomEvent), "function", "TriggerCustomEvent installed")
_assert_eq(#all_roles, 3, "roles cached")
_assert_eq(ALLROLES, all_roles, "ALLROLES alias")

local refreshed = runtime_context.refresh_roles(ctx)
_assert_eq(refreshed[1], 1, "refresh_roles")

print("Contract runtime_context_boot passed")
