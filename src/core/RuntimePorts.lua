local runtime_ports = {}
local runtime_context = require("src.core.RuntimeContext")

local configured = nil
local legacy_fallback_policy = {
  roles = false,
  role = false,
  vehicle = false,
  camera = false,
}

local function _normalized_legacy_fallback_policy(policy)
  local next_policy = policy or {}
  return {
    roles = next_policy.roles == true,
    role = next_policy.role == true,
    vehicle = next_policy.vehicle == true,
    camera = next_policy.camera == true,
  }
end

local function _is_any_legacy_fallback_enabled()
  return legacy_fallback_policy.roles
    or legacy_fallback_policy.role
    or legacy_fallback_policy.vehicle
    or legacy_fallback_policy.camera
end

local function _default_rng_next_int(min, max)
  assert(min ~= nil and max ~= nil, "rng.next_int requires min/max")
  assert(GameAPI and GameAPI.random_int, "missing GameAPI.random_int")
  return GameAPI.random_int(min, max)
end

local function _default_schedule(delay, fn)
  assert(type(fn) == "function", "schedule requires callback")
  if SetTimeOut then
    SetTimeOut(delay or 0, fn)
    return
  end
  fn()
end

local function _try_get_role_id(role)
  if role == nil then
    return nil
  end
  if type(role.get_roleid) == "function" then
    local ok, role_id = pcall(role.get_roleid, role)
    if ok then
      return role_id
    end
  end
  return role.id
end

local function _resolve_roles_from_legacy_globals()
  if type(all_roles) == "table" then
    return all_roles
  end
  if type(ALLROLES) == "table" then
    return ALLROLES
  end
  if GameAPI and type(GameAPI.get_all_valid_roles) == "function" then
    local ok, roles = pcall(GameAPI.get_all_valid_roles)
    if ok and type(roles) == "table" then
      return roles
    end
  end
  return {}
end

local function _default_resolve_roles()
  local ctx = runtime_context.current()
  if ctx and type(ctx.roles) == "table" then
    return ctx.roles
  end
  if legacy_fallback_policy.roles then
    return _resolve_roles_from_legacy_globals()
  end
  return {}
end

local function _default_resolve_role(player_id)
  if player_id == nil then
    return nil
  end
  local roles = _default_resolve_roles()
  if type(roles) == "table" then
    for _, role in ipairs(roles) do
      if _try_get_role_id(role) == player_id then
        return role
      end
    end
  end
  if legacy_fallback_policy.role and GameAPI and type(GameAPI.get_role) == "function" then
    local ok, role = pcall(GameAPI.get_role, player_id)
    if ok then
      return role
    end
  end
  return nil
end

local function _default_mark_role_lose(role)
  if role and role.lose then
    role.lose()
  end
end

local function _default_resolve_vehicle_helper()
  local ctx = runtime_context.current()
  if ctx and type(ctx.vehicle_helper) == "table" then
    return ctx.vehicle_helper
  end
  if not legacy_fallback_policy.vehicle then
    return nil
  end
  return vehicle_helper
end

local function _default_resolve_camera_helper()
  local ctx = runtime_context.current()
  if ctx and type(ctx.camera_helper) == "table" then
    return ctx.camera_helper
  end
  if not legacy_fallback_policy.camera then
    return nil
  end
  return camera_helper
end

local function _default_emit_event(event_name, payload)
  if event_name == nil then
    return false
  end
  if not TriggerCustomEvent then
    return false
  end
  local ok = pcall(TriggerCustomEvent, event_name, payload or {})
  return ok
end

local function _default_wall_now_seconds()
  if GameAPI and type(GameAPI.get_timestamp) == "function" then
    local ok, ts = pcall(GameAPI.get_timestamp)
    if ok and type(ts) == "number" then
      return ts
    end
  end
  return 0
end

local function _default_wall_diff_seconds(timestamp_1, timestamp_2)
  if GameAPI
      and type(GameAPI.get_timestamp_diff) == "function"
      and type(timestamp_1) == "number"
      and type(timestamp_2) == "number" then
    local ok, diff = pcall(GameAPI.get_timestamp_diff, timestamp_1, timestamp_2)
    if ok and type(diff) == "number" then
      return diff
    end
  end
  if type(timestamp_1) == "number" and type(timestamp_2) == "number" then
    return timestamp_1 - timestamp_2
  end
  return 0
end

local function _default_cpu_now_seconds()
  if os and type(os.clock) == "function" then
    return os.clock()
  end
  return 0
end

local function _default_cpu_diff_seconds(timestamp_1, timestamp_2)
  if type(timestamp_1) == "number" and type(timestamp_2) == "number" then
    return timestamp_1 - timestamp_2
  end
  return 0
end

local function _resolve_port(name, fallback)
  if configured and configured[name] ~= nil then
    return configured[name]
  end
  return fallback
end

function runtime_ports.configure(ports)
  configured = ports or nil
end

function runtime_ports.set_legacy_global_fallback_enabled(enabled)
  if enabled == true then
    runtime_ports.set_legacy_fallback_policy({
      roles = true,
      role = true,
      vehicle = true,
      camera = true,
    })
    return
  end
  runtime_ports.set_legacy_fallback_policy()
end

function runtime_ports.legacy_global_fallback_enabled()
  return _is_any_legacy_fallback_enabled()
end

function runtime_ports.set_legacy_fallback_policy(policy)
  legacy_fallback_policy = _normalized_legacy_fallback_policy(policy)
end

function runtime_ports.legacy_fallback_policy()
  return {
    roles = legacy_fallback_policy.roles,
    role = legacy_fallback_policy.role,
    vehicle = legacy_fallback_policy.vehicle,
    camera = legacy_fallback_policy.camera,
  }
end

function runtime_ports.rng_next_int(min, max)
  local fn = _resolve_port("rng_next_int", _default_rng_next_int)
  return fn(min, max)
end

function runtime_ports.schedule(delay, fn)
  local scheduler = _resolve_port("schedule", _default_schedule)
  return scheduler(delay, fn)
end

function runtime_ports.resolve_role(player_id)
  local resolver = _resolve_port("resolve_role", _default_resolve_role)
  return resolver(player_id)
end

function runtime_ports.resolve_roles()
  local resolver = _resolve_port("resolve_roles", _default_resolve_roles)
  return resolver()
end

function runtime_ports.mark_role_lose(role)
  local marker = _resolve_port("mark_role_lose", _default_mark_role_lose)
  return marker(role)
end

function runtime_ports.resolve_vehicle_helper()
  local resolver = _resolve_port("resolve_vehicle_helper", _default_resolve_vehicle_helper)
  return resolver()
end

function runtime_ports.resolve_camera_helper()
  local resolver = _resolve_port("resolve_camera_helper", _default_resolve_camera_helper)
  return resolver()
end

function runtime_ports.emit_event(event_name, payload)
  local emitter = _resolve_port("emit_event", _default_emit_event)
  return emitter(event_name, payload)
end

function runtime_ports.wall_now_seconds()
  local fn = _resolve_port("wall_now_seconds", _default_wall_now_seconds)
  return fn()
end

function runtime_ports.wall_diff_seconds(timestamp_1, timestamp_2)
  local fn = _resolve_port("wall_diff_seconds", _default_wall_diff_seconds)
  return fn(timestamp_1, timestamp_2)
end

function runtime_ports.cpu_now_seconds()
  local fn = _resolve_port("cpu_now_seconds", _default_cpu_now_seconds)
  return fn()
end

function runtime_ports.cpu_diff_seconds(timestamp_1, timestamp_2)
  local fn = _resolve_port("cpu_diff_seconds", _default_cpu_diff_seconds)
  return fn(timestamp_1, timestamp_2)
end

function runtime_ports.reset_for_tests()
  configured = nil
  legacy_fallback_policy = _normalized_legacy_fallback_policy()
end

return runtime_ports
