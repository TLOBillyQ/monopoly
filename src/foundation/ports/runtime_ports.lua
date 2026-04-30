local runtime_ports = {}

local configured = nil

local function _resolve_port(name)
  if configured and configured[name] ~= nil then
    return configured[name]
  end
  return nil
end

function runtime_ports.configure(ports)
  configured = ports or nil
end

function runtime_ports.rng_next_int(min, max)
  local fn = _resolve_port("rng_next_int")
  assert(type(fn) == "function", "missing runtime port: rng_next_int")
  return fn(min, max)
end

function runtime_ports.schedule(delay, fn)
  local scheduler = _resolve_port("schedule")
  if type(scheduler) ~= "function" then
    if fn then
      fn()
    end
    return
  end
  return scheduler(delay, fn)
end

function runtime_ports.resolve_role(player_id)
  local resolver = _resolve_port("resolve_role")
  if type(resolver) ~= "function" then
    return nil
  end
  return resolver(player_id)
end

function runtime_ports.resolve_roles()
  local resolver = _resolve_port("resolve_roles")
  if type(resolver) ~= "function" then
    return {}
  end
  return resolver()
end

function runtime_ports.mark_role_lose(role)
  local marker = _resolve_port("mark_role_lose")
  if type(marker) ~= "function" then
    return nil
  end
  return marker(role)
end

function runtime_ports.resolve_vehicle_helper()
  local resolver = _resolve_port("resolve_vehicle_helper")
  if type(resolver) ~= "function" then
    return nil
  end
  return resolver()
end

function runtime_ports.resolve_camera_helper()
  local resolver = _resolve_port("resolve_camera_helper")
  if type(resolver) ~= "function" then
    return nil
  end
  return resolver()
end

function runtime_ports.emit_event(event_name, payload, opts)
  local emitter = _resolve_port("emit_event")
  if type(emitter) ~= "function" then
    return false
  end
  return emitter(event_name, payload, opts)
end

function runtime_ports.wall_now_seconds()
  local fn = _resolve_port("wall_now_seconds")
  if type(fn) ~= "function" then
    return 0
  end
  return fn()
end

function runtime_ports.wall_diff_seconds(timestamp_1, timestamp_2)
  local fn = _resolve_port("wall_diff_seconds")
  if type(fn) ~= "function" then
    return 0
  end
  return fn(timestamp_1, timestamp_2)
end

function runtime_ports.cpu_now_seconds()
  local fn = _resolve_port("cpu_now_seconds")
  if type(fn) ~= "function" then
    return 0
  end
  return fn()
end

function runtime_ports.cpu_diff_seconds(timestamp_1, timestamp_2)
  local fn = _resolve_port("cpu_diff_seconds")
  if type(fn) ~= "function" then
    return 0
  end
  return fn(timestamp_1, timestamp_2)
end

function runtime_ports.is_effect_idle()
  local fn = _resolve_port("is_effect_idle")
  if type(fn) ~= "function" then
    return true
  end
  return fn()
end

function runtime_ports.reset_for_tests()
  configured = nil
end

return runtime_ports
