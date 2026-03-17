local host_runtime_ports = {}

local function _host_runtime()
  return package.loaded["src.host.eggy"] or require("src.host.eggy")
end

local function _runtime_event_bridge()
  return package.loaded["src.host.eggy.event_bridge"]
    or require("src.host.eggy.event_bridge")
end

function host_runtime_ports.resolve_roles()
  return _host_runtime().resolve_roles()
end

function host_runtime_ports.resolve_role(role_id)
  return _host_runtime().resolve_role(role_id)
end

function host_runtime_ports.resolve_role_with(...)
  return _host_runtime().resolve_role_with(...)
end

function host_runtime_ports.register_custom_event(event_name, handler)
  return _host_runtime().register_custom_event(event_name, handler)
end

function host_runtime_ports.show_tips(...)
  return _host_runtime().show_tips(...)
end

function host_runtime_ports.register_target_pick_listener(listener)
  return _host_runtime().register_target_pick_listener(listener)
end

function host_runtime_ports.unregister_target_pick_listener(token)
  return _host_runtime().unregister_target_pick_listener(token)
end

function host_runtime_ports.get_unit_id(unit)
  return _host_runtime().get_unit_id(unit)
end

function host_runtime_ports.has_scene_ui_support()
  return _host_runtime().has_scene_ui_support()
end

function host_runtime_ports.schedule(...)
  return _host_runtime().schedule(...)
end

function host_runtime_ports.create_unit_group(...)
  return _host_runtime().create_unit_group(...)
end

function host_runtime_ports.create_unit_with_scale(...)
  return _host_runtime().create_unit_with_scale(...)
end

function host_runtime_ports.destroy_unit(...)
  return _host_runtime().destroy_unit(...)
end

function host_runtime_ports.destroy_unit_with_children(...)
  return _host_runtime().destroy_unit_with_children(...)
end

function host_runtime_ports.destroy_scene_ui(...)
  return _host_runtime().destroy_scene_ui(...)
end

function host_runtime_ports.set_scene_ui_visible(...)
  return _host_runtime().set_scene_ui_visible(...)
end

function host_runtime_ports.bind_sfx_to_unit(...)
  return _host_runtime().bind_sfx_to_unit(...)
end

function host_runtime_ports.play_sfx_by_key(...)
  return _host_runtime().play_sfx_by_key(...)
end

function host_runtime_ports.play_3d_sound(...)
  return _host_runtime().play_3d_sound(...)
end

function host_runtime_ports.emit_custom_event(event_name, ...)
  return _runtime_event_bridge().emit_custom_event(event_name, ...)
end

return host_runtime_ports
