local default_ports = {}
local number_utils = require("src.foundation.number")
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

local function _try_get_role_id(role)
  if role == nil then
    return nil
  end
  if type(role.get_roleid) == "function" then
    local ok, role_id = pcall(role.get_roleid)
    if ok then
      return role_id
    end
  end
  return role.id
end

function default_ports.build(runtime_context)
  local defaults = {}

  local function _query_game_roles()
    local game_api = _current_game_api(runtime_context)
    if game_api and type(game_api.get_all_valid_roles) == "function" then
      local ok, roles = pcall(game_api.get_all_valid_roles)
      if ok and type(roles) == "table" then
        return roles
      end
    end
    return {}
  end

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

  function defaults.resolve_roles()
    local ctx = runtime_context.current()
    if ctx and type(ctx.roles) == "table" then
      if #ctx.roles > 0 then
        return ctx.roles
      end
      local refreshed = _query_game_roles()
      if #refreshed > 0 then
        ctx.roles = refreshed
        return refreshed
      end
      return ctx.roles
    end
    return _query_game_roles()
  end

  local function _try_resolve_synthetic_role(player_id, ctx)
  local synthetic_registry = ctx and ctx.synthetic_actor_registry or nil
  if not (synthetic_registry and type(synthetic_registry.resolve_actor) == "function") then
    return nil
  end
  local synthetic_actor = synthetic_registry.resolve_actor(player_id)
  if synthetic_actor and synthetic_actor.adapter then
    return synthetic_actor.adapter
  end
  return nil
end

function defaults.resolve_role(player_id)
  if player_id == nil then
    return nil
  end
  local ctx = runtime_context.current()
  local synthetic_adapter = _try_resolve_synthetic_role(player_id, ctx)
  if synthetic_adapter then
    return synthetic_adapter
  end
  local roles = defaults.resolve_roles()
  if type(roles) == "table" then
    for _, role in ipairs(roles) do
      if _try_get_role_id(role) == player_id then
        return role
      end
    end
  end
  local game_api = _current_game_api(runtime_context)
  if game_api and type(game_api.get_role) == "function" then
    local ok, role = pcall(game_api.get_role, player_id)
    if ok then
      return role
    end
  end
  return nil
end

  function defaults.mark_role_lose(role)
    if role and role.lose then
      role.lose()
    end
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

  local function _try_timestamp_from_api(game_api)
    if game_api and type(game_api.get_timestamp) == "function" then
      local ok, ts = pcall(game_api.get_timestamp)
      if ok and number_utils.is_numeric(ts) then
        return ts
      end
    end
    return nil
  end

  local function _api_now_seconds()
    local ts = _try_timestamp_from_api(_current_game_api(runtime_context))
    return ts or 0
  end

  defaults.wall_now_seconds = _api_now_seconds

  function defaults.wall_now_hms()
    local game_api = _current_game_api(runtime_context)
    if game_api == nil then
      return ""
    end
    local ts = _try_timestamp_from_api(game_api)
    if ts == nil then
      return ""
    end
    local function _safe_part(fn_name)
      local fn = game_api[fn_name]
      if type(fn) ~= "function" then
        return nil
      end
      local ok, val = pcall(fn, ts)
      if not ok or not number_utils.is_numeric(val) then
        return nil
      end
      return number_utils.to_integer(val)
    end
    local h = _safe_part("get_hour")
    local m = _safe_part("get_minute")
    local s = _safe_part("get_second")
    if h == nil or m == nil or s == nil then
      return ""
    end
    return string.format("%02d:%02d:%02d", h, m, s)
  end

  function defaults.wall_diff_seconds(timestamp_1, timestamp_2)
    local game_api = _current_game_api(runtime_context)
    if game_api
        and type(game_api.get_timestamp_diff) == "function"
        and number_utils.is_numeric(timestamp_1)
        and number_utils.is_numeric(timestamp_2) then
      local ok, diff = pcall(game_api.get_timestamp_diff, timestamp_1, timestamp_2)
      if ok and number_utils.is_numeric(diff) then
        return diff
      end
    end
    return number_utils.diff_or_zero(timestamp_1, timestamp_2)
  end

  defaults.cpu_now_seconds = _api_now_seconds
  defaults.cpu_diff_seconds = number_utils.diff_or_zero

  function defaults.is_effect_idle()
    local ok, effect_track = pcall(require, "src.ui.render.support.effect_track")
    if ok and type(effect_track) == "table" and type(effect_track.is_idle) == "function" then
      return effect_track.is_idle()
    end
    return true
  end

  local function _int_archive_type()
    return Enums and Enums.ArchiveType and Enums.ArchiveType.Int or nil
  end

  function defaults.archives_enabled()
    local game_api = _current_game_api(runtime_context)
    if game_api and type(game_api.is_archives_enabled) == "function" then
      local ok, enabled = pcall(game_api.is_archives_enabled)
      if ok then
        return enabled == true
      end
    end
    return false
  end

  function defaults.get_archive_int(role_id, key)
    local role = defaults.resolve_role(role_id)
    local archive_type = _int_archive_type()
    if not (role and archive_type ~= nil and type(role.get_archive_by_type) == "function") then
      return 0
    end
    local ok, value = pcall(role.get_archive_by_type, role, archive_type, key)
    if ok and number_utils.is_numeric(value) then
      return value
    end
    return 0
  end

  function defaults.set_archive_int(role_id, key, value)
    local role = defaults.resolve_role(role_id)
    local archive_type = _int_archive_type()
    if not (role and archive_type ~= nil and type(role.set_archive_by_type) == "function") then
      return false
    end
    local ok = pcall(role.set_archive_by_type, role, archive_type, key, value)
    return ok == true
  end

  return defaults
end

return default_ports

--[[ mutate4lua-manifest
version=2
projectHash=958fa5de478bdcb9
scope.0.id=chunk:src/host/default_ports.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=220
scope.0.semanticHash=02da6a5d89bb3551
scope.1.id=function:_current_env:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=9
scope.1.semanticHash=11ffb5cae6bfba68
scope.2.id=function:_current_api:11
scope.2.kind=function
scope.2.startLine=11
scope.2.endLine=14
scope.2.semanticHash=286ef21f361446d7
scope.3.id=function:_current_game_api:16
scope.3.kind=function
scope.3.startLine=16
scope.3.endLine=18
scope.3.semanticHash=bf1e142bdc7c609a
scope.4.id=function:_current_lua_api:20
scope.4.kind=function
scope.4.startLine=20
scope.4.endLine=22
scope.4.semanticHash=f61ada1a14452a90
scope.5.id=function:_try_get_role_id:24
scope.5.kind=function
scope.5.startLine=24
scope.5.endLine=35
scope.5.semanticHash=deb32682d9286f3b
scope.6.id=function:_query_game_roles:40
scope.6.kind=function
scope.6.startLine=40
scope.6.endLine=49
scope.6.semanticHash=f6a604109d58b510
scope.7.id=function:defaults.rng_next_int:51
scope.7.kind=function
scope.7.startLine=51
scope.7.endLine=56
scope.7.semanticHash=4264edc23481b38a
scope.8.id=function:defaults.schedule:58
scope.8.kind=function
scope.8.startLine=58
scope.8.endLine=66
scope.8.semanticHash=976d8c9ad6abfdbf
scope.9.id=function:defaults.resolve_roles:68
scope.9.kind=function
scope.9.startLine=68
scope.9.endLine=82
scope.9.semanticHash=7bfd31caea65201b
scope.10.id=function:_try_resolve_synthetic_role:84
scope.10.kind=function
scope.10.startLine=84
scope.10.endLine=94
scope.10.semanticHash=737e5d59a07ae264
scope.11.id=function:defaults.mark_role_lose:123
scope.11.kind=function
scope.11.startLine=123
scope.11.endLine=127
scope.11.semanticHash=4affd8d7f808c004
scope.12.id=function:defaults.resolve_camera_helper:129
scope.12.kind=function
scope.12.startLine=129
scope.12.endLine=135
scope.12.semanticHash=755aa67fdb42e74a
scope.13.id=function:defaults.emit_event:137
scope.13.kind=function
scope.13.startLine=137
scope.13.endLine=143
scope.13.semanticHash=550b696186716f3c
scope.14.id=function:_try_timestamp_from_api:145
scope.14.kind=function
scope.14.startLine=145
scope.14.endLine=153
scope.14.semanticHash=b34edaa2276ad356
scope.15.id=function:_api_now_seconds:155
scope.15.kind=function
scope.15.startLine=155
scope.15.endLine=158
scope.15.semanticHash=e683d488252a0d0f
scope.16.id=function:_safe_part:171
scope.16.kind=function
scope.16.startLine=171
scope.16.endLine=181
scope.16.semanticHash=f5c6f14d0fa101fc
scope.17.id=function:defaults.wall_now_hms:162
scope.17.kind=function
scope.17.startLine=162
scope.17.endLine=189
scope.17.semanticHash=64ca5a1f6d326c7d
scope.18.id=function:defaults.wall_diff_seconds:191
scope.18.kind=function
scope.18.startLine=191
scope.18.endLine=203
scope.18.semanticHash=b3c5bb1ed112e80b
scope.19.id=function:defaults.is_effect_idle:208
scope.19.kind=function
scope.19.startLine=208
scope.19.endLine=214
scope.19.semanticHash=46455d57947142b6
scope.20.id=function:defaults.resolve_role:96
scope.20.kind=function
scope.20.startLine=96
scope.20.endLine=217
scope.20.semanticHash=632b204fab3d67b0
]]
