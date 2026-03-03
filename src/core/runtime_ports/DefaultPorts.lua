local default_ports = {}
local number_utils = require("src.core.NumberUtils")

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
    if GameAPI and type(GameAPI.get_all_valid_roles) == "function" then
      local ok, roles = pcall(GameAPI.get_all_valid_roles)
      if ok and type(roles) == "table" then
        return roles
      end
    end
    return {}
  end

  function defaults.rng_next_int(min, max)
    assert(min ~= nil and max ~= nil, "rng.next_int requires min/max")
    assert(GameAPI and GameAPI.random_int, "missing GameAPI.random_int")
    return GameAPI.random_int(min, max)
  end

  function defaults.schedule(delay, fn)
    assert(type(fn) == "function", "schedule requires callback")
    if SetTimeOut then
      SetTimeOut(delay or 0, fn)
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
    if GameAPI and type(GameAPI.get_role) == "function" then
      local ok, role = pcall(GameAPI.get_role, player_id)
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

  function defaults.emit_event(event_name, payload)
    if event_name == nil then
      return false
    end
    if not TriggerCustomEvent then
      return false
    end
    local ok = pcall(TriggerCustomEvent, event_name, payload or {})
    return ok
  end

  function defaults.wall_now_seconds()
    if GameAPI and type(GameAPI.get_timestamp) == "function" then
      local ok, ts = pcall(GameAPI.get_timestamp)
      if ok and number_utils.is_numeric(ts) then
        return ts
      end
    end
    return 0
  end

  function defaults.wall_diff_seconds(timestamp_1, timestamp_2)
    if GameAPI
        and type(GameAPI.get_timestamp_diff) == "function"
        and number_utils.is_numeric(timestamp_1)
        and number_utils.is_numeric(timestamp_2) then
      local ok, diff = pcall(GameAPI.get_timestamp_diff, timestamp_1, timestamp_2)
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
    if os and type(os.clock) == "function" then
      return os.clock()
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
