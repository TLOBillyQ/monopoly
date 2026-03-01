local runtime_ports = {}

local configured = nil

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

local function _default_resolve_role(player_id)
  if player_id == nil then
    return nil
  end
  if not (GameAPI and GameAPI.get_role) then
    return nil
  end
  local ok, role = pcall(GameAPI.get_role, player_id)
  if not ok then
    return nil
  end
  return role
end

local function _default_mark_role_lose(role)
  if role and role.lose then
    role.lose()
  end
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

local function _resolve_port(name, fallback)
  if configured and configured[name] ~= nil then
    return configured[name]
  end
  return fallback
end

function runtime_ports.configure(ports)
  configured = ports or nil
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

function runtime_ports.mark_role_lose(role)
  local marker = _resolve_port("mark_role_lose", _default_mark_role_lose)
  return marker(role)
end

function runtime_ports.emit_event(event_name, payload)
  local emitter = _resolve_port("emit_event", _default_emit_event)
  return emitter(event_name, payload)
end

function runtime_ports.reset_for_tests()
  configured = nil
end

return runtime_ports
