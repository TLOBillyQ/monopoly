local runtime_ports = require("src.core.ports.runtime_ports")
local runtime_event_bridge = require("src.host.eggy.event_bridge")
local runtime_context = require("src.host.eggy.context")
local logger = require("src.core.utils.logger")
local role_resolver = require("src.host.eggy.role_resolver")
local unit_lifecycle = require("src.host.eggy.units")
local scene_ui = require("src.host.eggy.scene_ui")
local raycast = require("src.host.eggy.raycast")
local sfx_runtime = require("src.host.eggy.sound")

local host_runtime = {}
local target_pick_listener_seq = 0
local target_pick_listeners = {}

function host_runtime.schedule(delay, fn)
  return runtime_ports.schedule(delay or 0, fn)
end

function host_runtime.show_tips(text, duration)
  return logger.show_tip(text, duration)
end

function host_runtime.register_custom_event(event_name, handler)
  if type(event_name) ~= "string" or type(handler) ~= "function" then
    return false
  end
  local runtime_ctx = runtime_context.current()
  local lua_api = runtime_ctx and runtime_ctx.env and runtime_ctx.env.LuaAPI or nil
  if not (lua_api and type(lua_api.global_register_custom_event) == "function") then
    return false
  end
  lua_api.global_register_custom_event(event_name, handler)
  return true
end

function host_runtime.emit_custom_event(event_name, payload)
  return runtime_event_bridge.emit_custom_event(event_name, payload)
end

function host_runtime.resolve_role(player_id)
  return host_runtime.resolve_role_with(player_id)
end

function host_runtime.resolve_role_with(player_id, predicate)
  return role_resolver.resolve_role_with(player_id, predicate)
end

function host_runtime.resolve_game_role(player_id)
  return role_resolver.resolve_game_role(player_id)
end

function host_runtime.resolve_roles()
  return role_resolver.resolve_roles()
end

function host_runtime.create_unit_group(group_id, pos, rotation)
  return unit_lifecycle.create_unit_group(group_id, pos, rotation)
end

function host_runtime.create_unit_with_scale(unit_id, pos, rotation, scale)
  return unit_lifecycle.create_unit_with_scale(unit_id, pos, rotation, scale)
end

function host_runtime.destroy_unit_with_children(handle, include_children)
  return unit_lifecycle.destroy_unit_with_children(handle, include_children)
end

function host_runtime.destroy_unit(handle)
  return unit_lifecycle.destroy_unit(handle)
end

function host_runtime.play_sfx_by_key(sfx_key, pos, rot, scale, duration, rate, with_sound)
  return sfx_runtime.play_sfx_by_key(sfx_key, pos, rot, scale, duration, rate, with_sound)
end

function host_runtime.play_3d_sound(pos, sound_id, duration, volume)
  return sfx_runtime.play_3d_sound(pos, sound_id, duration, volume)
end

function host_runtime.bind_sfx_to_unit(sfx_id, unit, socket_name, pos, bind_type)
  return sfx_runtime.bind_sfx_to_unit(sfx_id, unit, socket_name, pos, bind_type)
end

function host_runtime.destroy_sfx(sfx_id, fade_out)
  return sfx_runtime.destroy_sfx(sfx_id, fade_out)
end

function host_runtime.stop_sound(sound_id)
  return sfx_runtime.stop_sound(sound_id)
end

function host_runtime.set_scene_ui_visible(layer, role, visible)
  return scene_ui.set_scene_ui_visible(layer, role, visible)
end

function host_runtime.destroy_scene_ui(layer)
  return scene_ui.destroy_scene_ui(layer)
end

function host_runtime.has_scene_ui_support()
  return scene_ui.has_scene_ui_support()
end

function host_runtime.build_camera_ray(role, cfg)
  return raycast.build_camera_ray(role, cfg)
end

function host_runtime.pick_first_hit_unit(start_pos, end_pos, cfg)
  return raycast.pick_first_hit_unit(start_pos, end_pos, cfg)
end

function host_runtime.get_unit_id(unit)
  return raycast.get_unit_id(unit)
end

function host_runtime.resolve_hit_position(hit)
  return raycast.resolve_hit_position(hit)
end

function host_runtime.register_target_pick_listener(handler)
  if type(handler) ~= "function" then
    return nil
  end
  target_pick_listener_seq = target_pick_listener_seq + 1
  local token = target_pick_listener_seq
  target_pick_listeners[token] = handler
  return token
end

function host_runtime.unregister_target_pick_listener(token)
  if token == nil then
    return false
  end
  target_pick_listeners[token] = nil
  return true
end

function host_runtime.emit_target_pick(payload)
  for _, listener in pairs(target_pick_listeners) do
    listener(payload)
  end
end

return host_runtime
