local runtime_ports = {}

local runtime_context = require("src.core.RuntimeContext")
local context_policy = require("src.core.runtime_ports.ContextPolicy")
local default_ports_module = require("src.core.runtime_ports.DefaultPorts")

local configured = nil
local active_context_policy = "strict"
local legacy_fallback_policy = context_policy.normalize_legacy_fallback_policy()

local defaults = default_ports_module.build(runtime_context, function()
  return legacy_fallback_policy
end)

local function _resolve_port(name)
  if configured and configured[name] ~= nil then
    return configured[name]
  end
  return defaults[name]
end

function runtime_ports.configure(ports)
  configured = ports or nil
end

function runtime_ports.install_context_policy(policy, opts)
  local next_policy = policy or "strict"
  if not context_policy.is_valid(next_policy) then
    error("unknown context policy: " .. tostring(next_policy))
  end
  local next_opts = opts or {}
  active_context_policy = next_policy
  legacy_fallback_policy = context_policy.for_context(next_policy, next_opts.enable_legacy_helper_fallback)
end

function runtime_ports.set_legacy_fallback_policy(policy)
  legacy_fallback_policy = context_policy.normalize_legacy_fallback_policy(policy)
end

function runtime_ports.context_policy()
  return active_context_policy
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
  active_context_policy = "strict"
  legacy_fallback_policy = context_policy.normalize_legacy_fallback_policy()
end

return runtime_ports
