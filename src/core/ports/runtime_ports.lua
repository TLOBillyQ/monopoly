local runtime_ports = {}

local runtime_context = require("src.core.runtime_facade.runtime_context")
local default_ports_module = require("src.core.runtime_ports.default_ports")

local configured = nil
local defaults = default_ports_module.build(runtime_context)

local function _resolve_port(name)
  if configured and configured[name] ~= nil then
    return configured[name]
  end
  return defaults[name]
end

function runtime_ports.configure(ports)
  configured = ports or nil
end

function runtime_ports.rng_next_int(min, max)
  local fn = _resolve_port("rng_next_int")
  return fn(min, max)
end

function runtime_ports.schedule(delay, fn)
  local scheduler = _resolve_port("schedule")
  return scheduler(delay, fn)
end

function runtime_ports.resolve_role(player_id)
  local resolver = _resolve_port("resolve_role")
  return resolver(player_id)
end

function runtime_ports.resolve_roles()
  local resolver = _resolve_port("resolve_roles")
  return resolver()
end

function runtime_ports.mark_role_lose(role)
  local marker = _resolve_port("mark_role_lose")
  return marker(role)
end

function runtime_ports.resolve_vehicle_helper()
  local resolver = _resolve_port("resolve_vehicle_helper")
  return resolver()
end

function runtime_ports.resolve_camera_helper()
  local resolver = _resolve_port("resolve_camera_helper")
  return resolver()
end

function runtime_ports.resolve_change_skin_helper()
  local resolver = _resolve_port("resolve_change_skin_helper")
  return resolver()
end

function runtime_ports.resolve_market_paid_gateway()
  local resolver = _resolve_port("resolve_market_paid_gateway")
  if type(resolver) ~= "function" then
    return nil
  end
  return resolver()
end

function runtime_ports.emit_event(event_name, payload)
  local emitter = _resolve_port("emit_event")
  return emitter(event_name, payload)
end

function runtime_ports.wall_now_seconds()
  local fn = _resolve_port("wall_now_seconds")
  return fn()
end

function runtime_ports.wall_diff_seconds(timestamp_1, timestamp_2)
  local fn = _resolve_port("wall_diff_seconds")
  return fn(timestamp_1, timestamp_2)
end

function runtime_ports.cpu_now_seconds()
  local fn = _resolve_port("cpu_now_seconds")
  return fn()
end

function runtime_ports.cpu_diff_seconds(timestamp_1, timestamp_2)
  local fn = _resolve_port("cpu_diff_seconds")
  return fn(timestamp_1, timestamp_2)
end

function runtime_ports.reset_for_tests()
  configured = nil
end

return runtime_ports
