local meta = require("src.ui.render.status3d.meta")
local specs = require("src.ui.render.status3d.specs")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local host_runtime_resolver = require("src.ui.render.host_runtime_resolver")

local M = {}

local _empty_roles = {}

local _resolve_host_runtime = host_runtime_resolver.from_deps

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
  return _empty_roles
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

local function _resolve_ctrl_unit_for_player(cache, player_id, deps)
  local role = _resolve_role(player_id, deps)
  if role == nil then
    meta.warn_once(cache, "missing_role_" .. tostring(player_id), "status3d missing role:", tostring(player_id))
    return nil
  end
  local ctrl_unit = role.get_ctrl_unit and role.get_ctrl_unit()
  if not (ctrl_unit and ctrl_unit.create_scene_ui_bind_unit) then
    meta.warn_once(cache, "missing_ctrl_unit_" .. tostring(player_id), "status3d unit missing create_scene_ui_bind_unit:", tostring(player_id))
    return nil
  end
  return ctrl_unit
end

local function _create_layer_for_status(ctrl_unit, cache, status_key, layout_id, player_id, player_layers, player_text_nodes, roles, deps)
  local layer = _create_scene_ui_bind_unit(ctrl_unit, layout_id)
  if layer == nil then
    meta.warn_once(cache, "create_layer_" .. tostring(status_key) .. "_" .. tostring(player_id),
      "status3d create layer failed:", tostring(status_key), tostring(player_id))
    return
  end
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

function M.ensure_layers_for_player(cache, player, deps)
  local player_id = player.id
  if cache.layers[player_id] ~= nil then
    return true
  end
  local ctrl_unit = _resolve_ctrl_unit_for_player(cache, player_id, deps)
  if ctrl_unit == nil then
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
    _create_layer_for_status(ctrl_unit, cache, status_key, layout_id, player_id, player_layers, player_text_nodes, roles, deps)
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

--[[ mutate4lua-manifest
version=2
projectHash=3b3a5237b9ebf3fe
scope.0.id=chunk:src/ui/render/status3d/scene.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=143
scope.0.semanticHash=01f0938e278e8e62
scope.0.lastMutatedAt=2026-06-01T12:41:40Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=survived
scope.0.lastMutationSites=24
scope.0.lastMutationKilled=20
scope.1.id=function:anonymous@14:14
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=16
scope.1.semanticHash=2b0f05e54d9828e3
scope.2.id=function:_resolve_role:12
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=17
scope.2.semanticHash=47758aa44fd6fe54
scope.2.lastMutatedAt=2026-06-01T12:41:40Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=2
scope.2.lastMutationKilled=2
scope.3.id=function:_resolve_observer_roles:19
scope.3.kind=function
scope.3.startLine=19
scope.3.endLine=25
scope.3.semanticHash=635be834e63732ee
scope.3.lastMutatedAt=2026-06-01T12:41:40Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=4
scope.3.lastMutationKilled=4
scope.4.id=function:_create_scene_ui_bind_unit:39
scope.4.kind=function
scope.4.startLine=39
scope.4.endLine=45
scope.4.semanticHash=ef2c422820a40844
scope.4.lastMutatedAt=2026-06-01T12:41:40Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=3
scope.4.lastMutationKilled=3
scope.5.id=function:_resolve_label_node_id:47
scope.5.kind=function
scope.5.startLine=47
scope.5.endLine=59
scope.5.semanticHash=d3e7859fc3cd935d
scope.5.lastMutatedAt=2026-06-01T12:41:40Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=survived
scope.5.lastMutationSites=13
scope.5.lastMutationKilled=11
scope.6.id=function:_resolve_text_node:61
scope.6.kind=function
scope.6.startLine=61
scope.6.endLine=75
scope.6.semanticHash=793fa5dac3c4b650
scope.6.lastMutatedAt=2026-06-01T12:41:40Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=survived
scope.6.lastMutationSites=9
scope.6.lastMutationKilled=8
scope.7.id=function:_resolve_ctrl_unit_for_player:77
scope.7.kind=function
scope.7.startLine=77
scope.7.endLine=89
scope.7.semanticHash=2b2650a3c64f30be
scope.7.lastMutatedAt=2026-06-01T12:41:40Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=8
scope.7.lastMutationKilled=8
scope.8.id=function:_create_layer_for_status:91
scope.8.kind=function
scope.8.startLine=91
scope.8.endLine=107
scope.8.semanticHash=09c9bb44601ee940
scope.8.lastMutatedAt=2026-06-01T12:41:40Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=7
scope.8.lastMutationKilled=7
]]
