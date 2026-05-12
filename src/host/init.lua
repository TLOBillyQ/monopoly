local runtime_ports = require("src.foundation.ports.runtime_ports")
local runtime_context = require("src.host.context")
local tip_queue = require("src.foundation.coordination.tip_queue")
local role_resolver = require("src.host.role_resolver")
local unit_lifecycle = require("src.host.units")
local entity_pool = require("src.host.entity_pool")
local scene_ui = require("src.host.scene_ui")
local raycast = require("src.host.raycast")
local sfx_runtime = require("src.host.sound")

local host_runtime = {}

function host_runtime.schedule(delay, fn)
  return runtime_ports.schedule(delay or 0, fn)
end

host_runtime.enqueue_tip = tip_queue.enqueue

function host_runtime.show_tips(text, duration)
  return host_runtime.enqueue_tip({
    text = text,
    duration = duration,
    blocks_inter_turn = false,
    source = "host_runtime.show_tips",
  })
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

host_runtime.create_unit_group = unit_lifecycle.create_unit_group
host_runtime.create_unit_with_scale = unit_lifecycle.create_unit_with_scale
host_runtime.destroy_unit_with_children = unit_lifecycle.destroy_unit_with_children
host_runtime.destroy_unit = unit_lifecycle.destroy_unit

host_runtime.acquire_unit = entity_pool.acquire
host_runtime.release_unit = entity_pool.release
host_runtime.prewarm_unit = entity_pool.prewarm

host_runtime.play_sfx_by_key = sfx_runtime.play_sfx_by_key
host_runtime.play_3d_sound = sfx_runtime.play_3d_sound
host_runtime.bind_sfx_to_unit = sfx_runtime.bind_sfx_to_unit

host_runtime.set_scene_ui_visible = scene_ui.set_scene_ui_visible
host_runtime.destroy_scene_ui = scene_ui.destroy_scene_ui
host_runtime.has_scene_ui_support = scene_ui.has_scene_ui_support
host_runtime.get_eui_node_at_scene_ui = scene_ui.get_eui_node_at_scene_ui

host_runtime.build_camera_ray = raycast.build_camera_ray
host_runtime.pick_first_hit_unit = raycast.pick_first_hit_unit
host_runtime.get_unit_id = raycast.get_unit_id
host_runtime.resolve_hit_position = raycast.resolve_hit_position

return host_runtime
