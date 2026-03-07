local default_ports = {}
local number_utils = require("src.core.NumberUtils")
local game_api_key = "Game" .. "API"
local lua_api_key = "Lua" .. "API"

local function _current_env(runtime_context)
  local ctx = runtime_context.current and runtime_context.current() or nil
  return ctx and ctx.env or nil
end

local function _current_game_api(runtime_context)
  local env = _current_env(runtime_context)
  return env and env[game_api_key] or nil
end

local function _current_lua_api(runtime_context)
  local env = _current_env(runtime_context)
  return env and env[lua_api_key] or nil
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

  function defaults.resolve_role(player_id)
    if player_id == nil then
      return nil
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

  function defaults.resolve_vehicle_helper()
    local ctx = runtime_context.current()
    if ctx and type(ctx.vehicle_helper) == "table" then
      return ctx.vehicle_helper
    end
    return nil
  end

  function defaults.resolve_camera_helper()
    local ctx = runtime_context.current()
    if ctx and type(ctx.camera_helper) == "table" then
      return ctx.camera_helper
    end
    return nil
  end

  function defaults.resolve_change_skin_helper()
    local ctx = runtime_context.current()
    if ctx and type(ctx.change_skin_helper) == "table" then
      return ctx.change_skin_helper
    end
    return nil
  end

  function defaults.emit_event(event_name, payload)
    if event_name == nil then
      return false
    end
    local lua_api = _current_lua_api(runtime_context)
    if not (lua_api and type(lua_api.global_send_custom_event) == "function") then
      return false
    end
    local ok = pcall(lua_api.global_send_custom_event, event_name, payload or {})
    return ok
  end

  function defaults.wall_now_seconds()
    local game_api = _current_game_api(runtime_context)
    if game_api and type(game_api.get_timestamp) == "function" then
      local ok, ts = pcall(game_api.get_timestamp)
      if ok and number_utils.is_numeric(ts) then
        return ts
      end
    end
    return 0
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
    if number_utils.is_numeric(timestamp_1) and number_utils.is_numeric(timestamp_2) then
      return timestamp_1 - timestamp_2
    end
    return 0
  end

  function defaults.cpu_now_seconds()
    local game_api = _current_game_api(runtime_context)
    if game_api and type(game_api.get_timestamp) == "function" then
      local ok, ts = pcall(game_api.get_timestamp)
      if ok and number_utils.is_numeric(ts) then
        return ts
      end
    end
    return 0
  end

  function defaults.cpu_diff_seconds(timestamp_1, timestamp_2)
    if number_utils.is_numeric(timestamp_1) and number_utils.is_numeric(timestamp_2) then
      return timestamp_1 - timestamp_2
    end
    return 0
  end

  return defaults
end

return default_ports
