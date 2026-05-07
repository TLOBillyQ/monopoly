local host_bridge = {}

local function _host_runtime()
  return require("src.host")
end

function host_bridge.resolve_roles()
  return _host_runtime().resolve_roles()
end

function host_bridge.resolve_role(role_id)
  return _host_runtime().resolve_role(role_id)
end

function host_bridge.resolve_role_with(...)
  return _host_runtime().resolve_role_with(...)
end

function host_bridge.register_custom_event(event_name, handler)
  return _host_runtime().register_custom_event(event_name, handler)
end

function host_bridge.show_tips(...)
  return _host_runtime().show_tips(...)
end

function host_bridge.enqueue_tip(...)
  return _host_runtime().enqueue_tip(...)
end

function host_bridge.get_unit_id(unit)
  return _host_runtime().get_unit_id(unit)
end

function host_bridge.has_scene_ui_support()
  return _host_runtime().has_scene_ui_support()
end

function host_bridge.get_eui_node_at_scene_ui(...)
  return _host_runtime().get_eui_node_at_scene_ui(...)
end

function host_bridge.schedule(...)
  return _host_runtime().schedule(...)
end

function host_bridge.create_unit_group(...)
  return _host_runtime().create_unit_group(...)
end

function host_bridge.create_unit_with_scale(...)
  return _host_runtime().create_unit_with_scale(...)
end

function host_bridge.destroy_unit(...)
  return _host_runtime().destroy_unit(...)
end

function host_bridge.destroy_unit_with_children(...)
  return _host_runtime().destroy_unit_with_children(...)
end

function host_bridge.acquire_unit(unit_key, pos, rotation, scale)
  return _host_runtime().acquire_unit(unit_key, pos, rotation, scale)
end

function host_bridge.release_unit(unit_key, handle)
  return _host_runtime().release_unit(unit_key, handle)
end

function host_bridge.prewarm_unit(unit_key, count, rotation, scale, sample_pos)
  return _host_runtime().prewarm_unit(unit_key, count, rotation, scale, sample_pos)
end

function host_bridge.destroy_scene_ui(...)
  return _host_runtime().destroy_scene_ui(...)
end

function host_bridge.set_scene_ui_visible(...)
  return _host_runtime().set_scene_ui_visible(...)
end

function host_bridge.bind_sfx_to_unit(...)
  return _host_runtime().bind_sfx_to_unit(...)
end

function host_bridge.play_sfx_by_key(...)
  return _host_runtime().play_sfx_by_key(...)
end

function host_bridge.play_3d_sound(...)
  return _host_runtime().play_3d_sound(...)
end

return host_bridge
