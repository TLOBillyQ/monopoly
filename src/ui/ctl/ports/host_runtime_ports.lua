local host_runtime = require("src.host.eggy")
local runtime_event_bridge = require("src.host.eggy.event_bridge")

local host_runtime_ports = {}

function host_runtime_ports.resolve_roles()
  return host_runtime.resolve_roles()
end

function host_runtime_ports.resolve_role(role_id)
  return host_runtime.resolve_role(role_id)
end

function host_runtime_ports.register_custom_event(event_name, handler)
  return host_runtime.register_custom_event(event_name, handler)
end

function host_runtime_ports.show_tips(...)
  return host_runtime.show_tips(...)
end

function host_runtime_ports.register_target_pick_listener(listener)
  return host_runtime.register_target_pick_listener(listener)
end

function host_runtime_ports.unregister_target_pick_listener(token)
  return host_runtime.unregister_target_pick_listener(token)
end

function host_runtime_ports.get_unit_id(unit)
  return host_runtime.get_unit_id(unit)
end

function host_runtime_ports.emit_custom_event(event_name, ...)
  return runtime_event_bridge.emit_custom_event(event_name, ...)
end

return host_runtime_ports
