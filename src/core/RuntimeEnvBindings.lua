local runtime_env_bindings = {}
local global_tip_trace_installed = false
local global_tip_trace_raw_show_tips = nil

local function _tip_trace_preview(value)
  local ok, text = pcall(tostring, value)
  if not ok then
    return "<tostring_failed>"
  end
  if text == nil then
    return "<nil>"
  end
  if #text > 200 then
    return string.sub(text, 1, 200) .. "..."
  end
  return text
end

local function _tip_trace_origin()
  if not (debug and type(debug.getinfo) == "function") then
    return "debug_unavailable"
  end
  for level = 3, 16 do
    local info = debug.getinfo(level, "nSl")
    if not info then
      break
    end
    local src = info.short_src or info.source or ""
    if src ~= ""
      and src ~= "=[C]"
      and string.find(src, "src/core/RuntimeEnvBindings.lua", 1, true) == nil then
      local line = info.currentline or 0
      local fn_name = info.name or "anonymous"
      return tostring(src) .. ":" .. tostring(line) .. ":" .. tostring(fn_name)
    end
  end
  return "origin_unresolved"
end

local function _install_global_tip_trace()
  if global_tip_trace_installed == true then
    return
  end
  if type(GlobalAPI) ~= "table" then
    return
  end
  local show_tips = GlobalAPI.show_tips
  if type(show_tips) ~= "function" then
    return
  end
  global_tip_trace_raw_show_tips = show_tips
  local wrapped = function(content, duration)
    local line = table.concat({
      "[TipTrace][GlobalAPI]",
      "text_type=" .. tostring(type(content)),
      "duration=" .. tostring(duration),
      "origin=" .. _tip_trace_origin(),
      "preview=" .. _tip_trace_preview(content),
    }, " ")
    if type(print) == "function" then
      pcall(print, line)
    end
    return global_tip_trace_raw_show_tips(content, duration)
  end
  local ok, err = pcall(function()
    GlobalAPI.show_tips = wrapped
  end)
  if not ok then
    if type(print) == "function" then
      pcall(print, "[TipTrace][GlobalAPI] install skipped: " .. tostring(err))
    end
    return
  end
  global_tip_trace_installed = true
end

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

function runtime_env_bindings.install(env)
  assert(env ~= nil, "missing runtime env")
  if env.GameAPI ~= nil then
    GameAPI = env.GameAPI
  end
  if env.LuaAPI ~= nil then
    LuaAPI = env.LuaAPI
  end
  _install_lua_api(LuaAPI)
  _install_global_tip_trace()
  return {
    GameAPI = GameAPI,
    LuaAPI = LuaAPI,
  }
end

return runtime_env_bindings
