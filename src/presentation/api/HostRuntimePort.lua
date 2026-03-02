local runtime_ports = require("src.core.RuntimePorts")
local runtime_event_bridge = require("src.core.RuntimeEventBridge")

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

local function _role_matches_predicate(role, predicate)
  if role == nil then
    return false
  end
  if predicate == nil then
    return true
  end
  return predicate(role) == true
end

function host_runtime_port.resolve_role(player_id)
  return host_runtime_port.resolve_role_with(player_id)
end

function host_runtime_port.resolve_role_with(player_id, predicate)
  local role = runtime_ports.resolve_role(player_id)
  if _role_matches_predicate(role, predicate) then
    return role
  end
  role = host_runtime_port.resolve_game_role(player_id)
  if _role_matches_predicate(role, predicate) then
    return role
  end
  return nil
end

function host_runtime_port.resolve_game_role(player_id)
  if GameAPI and type(GameAPI.get_role) == "function" then
    local ok, fallback = pcall(GameAPI.get_role, player_id)
    if ok then
      return fallback
    end
  end
  return nil
end

function host_runtime_port.resolve_roles()
  local roles = runtime_ports.resolve_roles()
  if type(roles) == "table" and #roles > 0 then
    return roles
  end
  if GameAPI and type(GameAPI.get_all_valid_roles) == "function" then
    local ok, fallback = pcall(GameAPI.get_all_valid_roles)
    if ok and type(fallback) == "table" then
      return fallback
    end
  end
  return roles or {}
end

function host_runtime_port.create_unit_group(group_id, pos, rotation)
  if not (GameAPI and type(GameAPI.create_unit_group) == "function") then
    return nil, "missing GameAPI.create_unit_group"
  end
  return GameAPI.create_unit_group(group_id, pos, rotation)
end

function host_runtime_port.create_unit_with_scale(unit_id, pos, rotation, scale)
  if not (GameAPI and type(GameAPI.create_unit_with_scale) == "function") then
    return nil, "missing GameAPI.create_unit_with_scale"
  end
  return GameAPI.create_unit_with_scale(unit_id, pos, rotation, scale)
end

function host_runtime_port.destroy_unit_with_children(handle, include_children)
  if not (GameAPI and type(GameAPI.destroy_unit_with_children) == "function") then
    return false
  end
  GameAPI.destroy_unit_with_children(handle, include_children == true)
  return true
end

function host_runtime_port.destroy_unit(handle)
  if not (GameAPI and type(GameAPI.destroy_unit) == "function") then
    return false
  end
  GameAPI.destroy_unit(handle)
  return true
end

function host_runtime_port.set_scene_ui_visible(layer, role, visible)
  if not (GameAPI and type(GameAPI.set_scene_ui_visible) == "function") then
    return false
  end
  local ok = pcall(GameAPI.set_scene_ui_visible, layer, role, visible == true)
  return ok
end

function host_runtime_port.destroy_scene_ui(layer)
  if not (GameAPI and type(GameAPI.destroy_scene_ui) == "function") then
    return false
  end
  local ok = pcall(GameAPI.destroy_scene_ui, layer)
  return ok
end

function host_runtime_port.has_scene_ui_support()
  return GameAPI
    and type(GameAPI.set_scene_ui_visible) == "function"
    and true
    or false
end

return host_runtime_port
