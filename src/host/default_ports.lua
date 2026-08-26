-- runtime_ports 的宿主默认实现装配(>100 mutation sites 拆分):时钟族
-- clock_ports / 角色族 role_ports / 档案族 archive_ports 各自成模块,
-- 本文件保留 build 骨架与零散默认(随机数/调度/相机/事件/特效查询)。
local clock_ports = require("src.host.clock_ports")
local role_ports = require("src.host.role_ports")
local archive_ports = require("src.host.archive_ports")

local default_ports = {}
local game_api_key = "Game" .. "API"
local lua_api_key = "Lua" .. "API"

local function _current_env(runtime_context)
  local ctx = runtime_context.current and runtime_context.current() or nil
  return ctx and ctx.env or nil
end

local function _current_api(runtime_context, env_key)
  local env = _current_env(runtime_context)
  return env and env[env_key] or nil
end

local function _current_game_api(runtime_context)
  return _current_api(runtime_context, game_api_key)
end

local function _current_lua_api(runtime_context)
  return _current_api(runtime_context, lua_api_key)
end

function default_ports.build(runtime_context)
  local defaults = {}

  clock_ports.install(defaults, runtime_context)
  role_ports.install(defaults, runtime_context)
  archive_ports.install(defaults, runtime_context)

  function defaults.rng_next_int(min, max)
    assert(min ~= nil and max ~= nil, "rng.next_int requires min/max")
    local game_api = _current_game_api(runtime_context)
    assert(game_api and game_api.random_int, "missing game api random_int")
    return game_api.random_int(min, max)
  end

  function defaults.schedule(delay, fn)
    assert(type(fn) == "function", "schedule requires callback")
    local lua_api = _current_lua_api(runtime_context)
    if lua_api and type(lua_api.call_delay_time) == "function" then
      lua_api.call_delay_time(delay or 0, fn)
      return
    end
    fn()
  end

  function defaults.resolve_camera_helper()
    local ctx = runtime_context.current()
    if ctx and type(ctx.camera_helper) == "table" then
      return ctx.camera_helper
    end
    return nil
  end

  function defaults.emit_event(event_name, payload, _opts)
    if type(TriggerCustomEvent) ~= "function" then
      return false
    end
    local ok = pcall(TriggerCustomEvent, event_name, payload or {})
    return ok == true
  end

  function defaults.is_effect_idle()
    local ok, effect_track = pcall(require, "src.ui.render.support.effect_track")
    if ok and type(effect_track) == "table" and type(effect_track.is_idle) == "function" then
      return effect_track.is_idle()
    end
    return true
  end

  return defaults
end

return default_ports

--[[ mutate4lua-manifest
version=4
projectHash=690b63b4b4929d64
scope.0.id=chunk:src/host/default_ports.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=82
scope.0.semanticHash=926f38f28fecdb06
scope.1.id=function:_current_env
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=15
scope.1.semanticHash=d08d43958f5bffa4
scope.2.id=function:_current_api
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=20
scope.2.semanticHash=837e31706e29c8d9
scope.3.id=function:_current_game_api
scope.3.kind=function
scope.3.startLine=22
scope.3.endLine=24
scope.3.semanticHash=e504e513aab7d79c
scope.4.id=function:_current_lua_api
scope.4.kind=function
scope.4.startLine=26
scope.4.endLine=28
scope.4.semanticHash=e504e513aab7d79c
scope.5.id=function:default_ports.build
scope.5.kind=function
scope.5.startLine=30
scope.5.endLine=79
scope.5.semanticHash=13575ef9e1751600
scope.6.id=function:defaults.rng_next_int
scope.6.kind=function
scope.6.startLine=37
scope.6.endLine=42
scope.6.semanticHash=5d6c9db5ffc50c06
scope.7.id=function:defaults.schedule
scope.7.kind=function
scope.7.startLine=44
scope.7.endLine=52
scope.7.semanticHash=87f8fc7343d323fc
scope.8.id=function:defaults.resolve_camera_helper
scope.8.kind=function
scope.8.startLine=54
scope.8.endLine=60
scope.8.semanticHash=0a80efb7257876a4
scope.9.id=function:defaults.emit_event
scope.9.kind=function
scope.9.startLine=62
scope.9.endLine=68
scope.9.semanticHash=4ddfe5d21ad348e2
scope.10.id=function:defaults.is_effect_idle
scope.10.kind=function
scope.10.startLine=70
scope.10.endLine=76
scope.10.semanticHash=60c77742ea0fc3e3
]]
