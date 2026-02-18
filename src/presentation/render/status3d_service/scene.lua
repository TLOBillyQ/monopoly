local meta = require("src.presentation.render.status3d_service.meta")
local specs = require("src.presentation.render.status3d_service.specs")

local M = {}

local function _resolve_observer_roles()
  if GameAPI and GameAPI.get_all_valid_roles then
    local ok, roles = pcall(GameAPI.get_all_valid_roles)
    if ok and type(roles) == "table" then
      return roles
    end
  end
  if type(all_roles) == "table" then
    return all_roles
  end
  return {}
end

local function _set_layer_visible_for_roles(layer, roles, visible)
  if not (GameAPI and GameAPI.set_scene_ui_visible) then
    return
  end
  local target_visible = visible == true
  for _, role in ipairs(roles) do
    if role ~= nil then
      pcall(GameAPI.set_scene_ui_visible, layer, role, target_visible)
    end
  end
end

local function _set_node_visible_for_roles(node, roles, visible)
  if node == nil then
    return
  end
  local target_visible = visible == true
  for _, role in ipairs(roles) do
    if role and role.set_node_visible then
      pcall(role.set_node_visible, node, target_visible)
    end
  end
end

local function _create_scene_ui_bind_unit(role, ctrl_unit, resolved_meta)
  assert(resolved_meta ~= nil, "missing meta")
  local offset = math.Vector3(0, 4, 0)
  if ctrl_unit and ctrl_unit.create_scene_ui_bind_unit then
    return ctrl_unit.create_scene_ui_bind_unit(resolved_meta.layer_key, Enums.ModelSocket.socket_head, offset, -1.0, true, true)
  end
  if role and role.create_scene_ui_bind_unit then
    return role.create_scene_ui_bind_unit(resolved_meta.layer_key, Enums.ModelSocket.socket_head, offset, -1.0, true, true)
  end
  if SceneUI and SceneUI.create_scene_ui_bind_unit then
    return SceneUI.create_scene_ui_bind_unit(resolved_meta.layer_key, Enums.ModelSocket.socket_head, offset, -1.0, true, true)
  end
  return nil
end

function M.ensure_layer_for_player(cache, player)
  local player_id = player.id
  if cache.layers_by_player_id[player_id] ~= nil then
    return true
  end
  local role = GameAPI.get_role(player_id)
  if role == nil then
    meta.warn_once(cache, "missing_role_" .. tostring(player_id), "status3d missing role:", tostring(player_id))
    return false
  end
  local ctrl_unit = role.get_ctrl_unit and role.get_ctrl_unit()
  if ctrl_unit == nil or ctrl_unit.create_scene_ui_bind_unit == nil then
    meta.warn_once(cache, "missing_create_scene_ui_bind_unit_" .. tostring(player_id), "status3d unit missing create_scene_ui_bind_unit:", tostring(player_id))
    return false
  end
  local resolved_meta, err = meta.build_meta(cache)
  if not resolved_meta then
    meta.warn_once(cache, "meta_error", "status3d meta resolve failed:", tostring(err))
    cache.disabled = true
    return false
  end
  local layer = _create_scene_ui_bind_unit(role, ctrl_unit, resolved_meta)
  if layer == nil then
    meta.warn_once(cache, "create_layer_failed_" .. tostring(player_id), "status3d create layer failed:", tostring(player_id))
    return false
  end
  local nodes_by_status = {}
  for status_key, node_ids in pairs(resolved_meta.node_ids_by_status) do
    local bg = GameAPI.get_eui_node_at_scene_ui(layer, node_ids.bg)
    local text = GameAPI.get_eui_node_at_scene_ui(layer, node_ids.text)
    if not bg or not text then
      meta.warn_once(cache, "missing_node_" .. tostring(status_key), "status3d node missing:", tostring(status_key))
    end
    nodes_by_status[status_key] = { bg = bg, text = text }
  end
  local roles = _resolve_observer_roles()
  for _, node_pair in pairs(nodes_by_status) do
    if node_pair then
      _set_node_visible_for_roles(node_pair.bg, roles, false)
      _set_node_visible_for_roles(node_pair.text, roles, false)
    end
  end
  _set_layer_visible_for_roles(layer, roles, false)
  cache.layers_by_player_id[player_id] = layer
  cache.nodes_by_player_id[player_id] = nodes_by_status
  cache.last_status_key_by_player[player_id] = specs.INIT_STATUS
  return true
end

M.resolve_observer_roles = _resolve_observer_roles
M.set_layer_visible_for_roles = _set_layer_visible_for_roles
M.set_node_visible_for_roles = _set_node_visible_for_roles

return M
