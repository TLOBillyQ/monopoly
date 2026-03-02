local runtime_ports = require("src.core.RuntimePorts")
local runtime_event_bridge = require("src.core.RuntimeEventBridge")
local role_resolver = require("src.presentation.api.host_runtime.RoleResolver")
local unit_lifecycle = require("src.presentation.api.host_runtime.UnitLifecycle")
local scene_ui = require("src.presentation.api.host_runtime.SceneUI")

local host_runtime_port = {}

function host_runtime_port.schedule(delay, fn)
  return runtime_ports.schedule(delay or 0, fn)
end

function host_runtime_port.show_tips(text, duration)
  if GlobalAPI and type(GlobalAPI.show_tips) == "function" then
    GlobalAPI.show_tips(text, duration)
    return true
  end
  return false
end

function host_runtime_port.register_custom_event(event_name, handler)
  if type(event_name) ~= "string" or type(handler) ~= "function" then
    return false
  end
  if type(RegisterCustomEvent) ~= "function" then
    return false
  end
  RegisterCustomEvent(event_name, handler)
  return true
end

function host_runtime_port.emit_custom_event(event_name, payload)
  return runtime_event_bridge.emit_custom_event(event_name, payload)
end

function host_runtime_port.resolve_role(player_id)
  return host_runtime_port.resolve_role_with(player_id)
end

function host_runtime_port.resolve_role_with(player_id, predicate)
  return role_resolver.resolve_role_with(player_id, predicate)
end

function host_runtime_port.resolve_game_role(player_id)
  return role_resolver.resolve_game_role(player_id)
end

function host_runtime_port.resolve_roles()
  return role_resolver.resolve_roles()
end

function host_runtime_port.create_unit_group(group_id, pos, rotation)
  return unit_lifecycle.create_unit_group(group_id, pos, rotation)
end

function host_runtime_port.create_unit_with_scale(unit_id, pos, rotation, scale)
  return unit_lifecycle.create_unit_with_scale(unit_id, pos, rotation, scale)
end

function host_runtime_port.destroy_unit_with_children(handle, include_children)
  return unit_lifecycle.destroy_unit_with_children(handle, include_children)
end

function host_runtime_port.destroy_unit(handle)
  return unit_lifecycle.destroy_unit(handle)
end

function host_runtime_port.set_scene_ui_visible(layer, role, visible)
  return scene_ui.set_scene_ui_visible(layer, role, visible)
end

function host_runtime_port.destroy_scene_ui(layer)
  return scene_ui.destroy_scene_ui(layer)
end

function host_runtime_port.has_scene_ui_support()
  return scene_ui.has_scene_ui_support()
end

return host_runtime_port
