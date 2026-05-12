local meta = require("src.ui.render.status3d.meta")
local specs = require("src.ui.render.status3d.specs")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local host_runtime_bridge = require("src.ui.host_bridge")

local M = {}

local function _resolve_host_runtime(deps)
  local resolved_deps = deps or {}
  if resolved_deps.host_runtime then
    return resolved_deps.host_runtime
  end
  return host_runtime_bridge
end

local function _resolve_role(player_id, deps)
  local host_runtime = _resolve_host_runtime(deps)
  return host_runtime.resolve_role_with(player_id, function(role)
    return type(role.get_ctrl_unit) == "function"
  end)
end

local function _resolve_observer_roles()
  local roles = runtime_ports.resolve_roles()
  if type(roles) == "table" then
    return roles
  end
  return {}
end

local function _set_layer_visible_for_roles(layer, roles, visible, deps)
  local host_runtime = _resolve_host_runtime(deps)
  if not host_runtime.has_scene_ui_support() then
    return
  end
  for _, role in ipairs(roles) do
    if role ~= nil then
      host_runtime.set_scene_ui_visible(layer, role, visible)
    end
  end
end

local function _create_scene_ui_bind_unit(ctrl_unit, layout_id)
  local offset = math.Vector3(0.0, 4.0, 0.0)
  if ctrl_unit and ctrl_unit.create_scene_ui_bind_unit then
    return ctrl_unit.create_scene_ui_bind_unit(layout_id, Enums.ModelSocket.socket_head, offset, -1.0, true, true)
  end
  return nil
end

local function _resolve_label_node_id(node_name)
  if type(node_name) ~= "string" or node_name == "" then
    return nil
  end
  if not (UIManager and type(UIManager.get_first_node_by_name) == "function") then
    return nil
  end
  local ui_node = UIManager.get_first_node_by_name(node_name)
  if ui_node == nil then
    return nil
  end
  return ui_node.id
end

local function _resolve_text_node(layer, status_key, deps)
  local spec = specs.status_specs[status_key]
  if not (spec and spec.text_node_name) then
    return nil
  end
  local node_id = _resolve_label_node_id(spec.text_node_name)
  if node_id == nil then
    return nil
  end
  local host_runtime = _resolve_host_runtime(deps)
  if type(host_runtime.get_eui_node_at_scene_ui) ~= "function" then
    return nil
  end
  return host_runtime.get_eui_node_at_scene_ui(layer, node_id)
end

function M.ensure_layers_for_player(cache, player, deps)
  local player_id = player.id
  if cache.layers[player_id] ~= nil then
    return true
  end
  local role = _resolve_role(player_id, deps)
  if role == nil then
    meta.warn_once(cache, "missing_role_" .. tostring(player_id), "status3d missing role:", tostring(player_id))
    return false
  end
  local ctrl_unit = role.get_ctrl_unit and role.get_ctrl_unit()
  if not (ctrl_unit and ctrl_unit.create_scene_ui_bind_unit) then
    meta.warn_once(cache, "missing_ctrl_unit_" .. tostring(player_id), "status3d unit missing create_scene_ui_bind_unit:", tostring(player_id))
    return false
  end
  local resolved_meta, err = meta.build_meta(cache)
  if not resolved_meta then
    meta.warn_once(cache, "meta_error", "status3d meta resolve failed:", tostring(err))
    cache.disabled = true
    return false
  end
  local player_layers = {}
  local player_text_nodes = {}
  local roles = _resolve_observer_roles()
  for status_key, layout_id in pairs(resolved_meta.layouts) do
    local layer = _create_scene_ui_bind_unit(ctrl_unit, layout_id)
    if layer == nil then
      meta.warn_once(cache, "create_layer_" .. tostring(status_key) .. "_" .. tostring(player_id),
        "status3d create layer failed:", tostring(status_key), tostring(player_id))
    else
      player_layers[status_key] = layer
      _set_layer_visible_for_roles(layer, roles, false, deps)
      local text_node = _resolve_text_node(layer, status_key, deps)
      if text_node ~= nil then
        player_text_nodes[status_key] = text_node
      else
        meta.warn_once(cache, "missing_text_node_" .. tostring(status_key) .. "_" .. tostring(player_id),
          "status3d missing remaining-text node:", tostring(status_key), tostring(player_id))
      end
    end
  end
  cache.layers[player_id] = player_layers
  cache.text_nodes[player_id] = player_text_nodes
  cache.last_status_key_by_player[player_id] = specs.INIT_STATUS
  return true
end

M.resolve_observer_roles = _resolve_observer_roles
M.set_layer_visible_for_roles = _set_layer_visible_for_roles

-- Exported for testing
M._create_scene_ui_bind_unit = _create_scene_ui_bind_unit

return M
