local runtime_ports = require("src.core.RuntimePorts")
local runtime_event_bridge = require("src.core.RuntimeEventBridge")
local logger = require("src.core.Logger")
local role_resolver = require("src.presentation.api.host_runtime.RoleResolver")
local unit_lifecycle = require("src.presentation.api.host_runtime.UnitLifecycle")
local scene_ui = require("src.presentation.api.host_runtime.SceneUI")
local raycast = require("src.presentation.api.host_runtime.Raycast")
local sfx_runtime = require("src.presentation.api.host_runtime.SfxRuntime")

local host_runtime_port = {}
local target_pick_listener_seq = 0
local target_pick_listeners = {}

function host_runtime_port.schedule(delay, fn)
  return runtime_ports.schedule(delay or 0, fn)
end

function host_runtime_port.show_tips(text, duration)
  return logger.show_tip(text, duration)
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

function host_runtime_port.play_sfx_by_key(sfx_key, pos, rot, scale, duration, rate, with_sound)
  return sfx_runtime.play_sfx_by_key(sfx_key, pos, rot, scale, duration, rate, with_sound)
end

function host_runtime_port.play_3d_sound(pos, sound_id, duration, volume)
  return sfx_runtime.play_3d_sound(pos, sound_id, duration, volume)
end

function host_runtime_port.bind_sfx_to_unit(sfx_id, unit, socket_name, pos, bind_type)
  return sfx_runtime.bind_sfx_to_unit(sfx_id, unit, socket_name, pos, bind_type)
end

function host_runtime_port.destroy_sfx(sfx_id, fade_out)
  return sfx_runtime.destroy_sfx(sfx_id, fade_out)
end

function host_runtime_port.stop_sound(sound_id)
  return sfx_runtime.stop_sound(sound_id)
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

function host_runtime_port.build_camera_ray(role, cfg)
  return raycast.build_camera_ray(role, cfg)
end

function host_runtime_port.pick_first_hit_unit(start_pos, end_pos, cfg)
  return raycast.pick_first_hit_unit(start_pos, end_pos, cfg)
end

function host_runtime_port.get_unit_id(unit)
  return raycast.get_unit_id(unit)
end

function host_runtime_port.resolve_hit_position(hit)
  return raycast.resolve_hit_position(hit)
end

function host_runtime_port.register_target_pick_listener(handler)
  if type(handler) ~= "function" then
    return nil
  end
  target_pick_listener_seq = target_pick_listener_seq + 1
  local token = target_pick_listener_seq
  target_pick_listeners[token] = handler
  return token
end

function host_runtime_port.unregister_target_pick_listener(token)
  if token == nil then
    return false
  end
  target_pick_listeners[token] = nil
  return true
end

function host_runtime_port.emit_target_pick(payload)
  for _, listener in pairs(target_pick_listeners) do
    listener(payload)
  end
end

return host_runtime_port
