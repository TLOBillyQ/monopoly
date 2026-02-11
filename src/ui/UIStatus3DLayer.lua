local logger = require("src.core.Logger")
local ui_nodes = require("Data.UIManagerNodes")

local ui_status_3d_layer = {}
local INIT_STATUS = "__init__"

local status_node_specs = {
  hospital = { bg = "医院状态-底图", text = "医院状态-文本" },
  mountain = { bg = "深山状态-底图", text = "深山状态-文本" },
  roadblock = { bg = "路障状态-底图", text = "路障状态-文本" },
  rich = { bg = "财神状态-底图", text = "财神状态-文本" },
  poor = { bg = "穷神状态-底图", text = "穷神状态-文本" },
  angel = { bg = "天使状态-底图", text = "天使状态-文本" },
}
local status_priority = { "hospital", "mountain", "roadblock", "poor", "rich", "angel" }
local status_node_name_lookup = {}
for status_key, spec in pairs(status_node_specs) do
  status_node_name_lookup[spec.bg] = { status_key = status_key, node_type = "bg" }
  status_node_name_lookup[spec.text] = { status_key = status_key, node_type = "text" }
end

local function _ensure_cache(state)
  assert(state ~= nil, "missing state")
  if state.ui_status_3d == nil then
    state.ui_status_3d = {
      layers_by_player_id = {},
      nodes_by_player_id = {},
      last_status_key_by_player = {},
      warned_once = {},
      disabled = false,
      meta = nil,
    }
  end
  return state.ui_status_3d
end

local function _warn_once(cache, key, ...)
  if cache.warned_once[key] then
    return
  end
  cache.warned_once[key] = true
  logger.warn(...)
end

local function _split_export_node_id(raw_id)
  if type(raw_id) ~= "string" then
    return nil, nil
  end
  local sep = string.find(raw_id, "|", 1, true)
  if not sep then
    return nil, nil
  end
  local prefix = string.sub(raw_id, 1, sep - 1)
  local node_id_raw = string.sub(raw_id, sep + 1)
  if prefix == "" or node_id_raw == "" then
    return nil, nil
  end
  return prefix, tonumber(node_id_raw) or node_id_raw
end

local function _build_meta(cache)
  if cache.meta ~= nil then
    return cache.meta
  end
  local resolved = {}
  local layer_prefix = nil
  for status_key in pairs(status_node_specs) do
    resolved[status_key] = {}
  end
  for raw_id, entry in pairs(ui_nodes) do
    if type(entry) == "table" then
      local binding = status_node_name_lookup[entry[1]]
      if binding then
        local prefix, node_id = _split_export_node_id(raw_id)
        if not prefix or not node_id then
          return nil, "invalid status node export id: " .. tostring(raw_id)
        end
        if layer_prefix == nil then
          layer_prefix = prefix
        elseif layer_prefix ~= prefix then
          return nil, "status node layer prefix mismatch: " .. tostring(layer_prefix) .. " / " .. tostring(prefix)
        end
        resolved[binding.status_key][binding.node_type] = node_id
      end
    end
  end
  if layer_prefix == nil then
    return nil, "status 3d nodes not found in Data.UIManagerNodes"
  end
  for status_key, spec in pairs(status_node_specs) do
    local node_set = resolved[status_key]
    if not node_set.bg then
      return nil, "missing status bg node: " .. tostring(spec.bg)
    end
    if not node_set.text then
      return nil, "missing status text node: " .. tostring(spec.text)
    end
  end
  cache.meta = { layer_key = tonumber(layer_prefix) or layer_prefix, node_ids_by_status = resolved }
  return cache.meta
end

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

local function _ensure_layer_for_player(cache, player)
  local player_id = player.id
  if cache.layers_by_player_id[player_id] ~= nil then
    return true
  end
  local role = GameAPI.get_role(player_id)
  if role == nil then
    _warn_once(cache, "missing_role_" .. tostring(player_id), "status3d missing role:", tostring(player_id))
    return false
  end
  local ctrl_unit = role.get_ctrl_unit and role.get_ctrl_unit()
  if ctrl_unit == nil or ctrl_unit.create_scene_ui_bind_unit == nil then
    _warn_once(cache, "missing_create_scene_ui_bind_unit_" .. tostring(player_id), "status3d unit missing create_scene_ui_bind_unit:", tostring(player_id))
    return false
  end
  local meta, err = _build_meta(cache)
  if not meta then
    _warn_once(cache, "meta_error", "status3d meta resolve failed:", tostring(err))
    cache.disabled = true
    return false
  end
  local layer = ctrl_unit.create_scene_ui_bind_unit(meta.layer_key, Enums.ModelSocket.socket_head, math.Vector3(0, 3, 0), -1.0, true, true)
  if layer == nil then
    _warn_once(cache, "create_layer_failed_" .. tostring(player_id), "status3d create layer failed:", tostring(player_id))
    return false
  end
  local nodes_by_status = {}
  for status_key, node_ids in pairs(meta.node_ids_by_status) do
    nodes_by_status[status_key] = {
      bg = GameAPI.get_eui_node_at_scene_ui(layer, node_ids.bg),
      text = GameAPI.get_eui_node_at_scene_ui(layer, node_ids.text),
    }
  end
  cache.layers_by_player_id[player_id] = layer
  cache.nodes_by_player_id[player_id] = nodes_by_status
  cache.last_status_key_by_player[player_id] = INIT_STATUS
  return true
end

local function _resolve_player_status_key(game, player)
  if player == nil or player.eliminated == true then
    return nil
  end
  local status = player.status or {}
  local stay_turns = status.stay_turns or 0
  if stay_turns > 0 and game.board and game.board.get_tile then
    local tile = game.board:get_tile(player.position)
    local tile_type = tile and tile.type or nil
    if tile_type == "hospital" then
      return "hospital"
    end
    if tile_type == "mountain" then
      return "mountain"
    end
  end
  local last_turn = game.last_turn
  if last_turn and last_turn.player_id == player.id then
    local move_result = last_turn.move_result
    if move_result and move_result.stopped_on_roadblock == true then
      return "roadblock"
    end
  end
  local deity = status.deity
  if deity and (deity.remaining or 0) > 0 then
    if deity.type == "poor" then
      return "poor"
    end
    if deity.type == "rich" then
      return "rich"
    end
    if deity.type == "angel" then
      return "angel"
    end
  end
  return nil
end

local function _sync_layer_status(cache, player, status_key)
  local player_id = player.id
  if cache.last_status_key_by_player[player_id] == status_key then
    return
  end
  local layer = cache.layers_by_player_id[player_id]
  local nodes = cache.nodes_by_player_id[player_id]
  if not layer or not nodes then
    return
  end
  local roles = _resolve_observer_roles()
  for _, key in ipairs(status_priority) do
    local node_pair = nodes[key]
    if node_pair then
      local visible = status_key == key
      _set_node_visible_for_roles(node_pair.bg, roles, visible)
      _set_node_visible_for_roles(node_pair.text, roles, visible)
    end
  end
  _set_layer_visible_for_roles(layer, roles, status_key ~= nil)
  cache.last_status_key_by_player[player_id] = status_key
end

function ui_status_3d_layer.reset(state)
  if not state or not state.ui_status_3d then
    return
  end
  local cache = state.ui_status_3d
  if GameAPI and GameAPI.destroy_scene_ui then
    for _, layer in pairs(cache.layers_by_player_id or {}) do
      if layer ~= nil then
        pcall(GameAPI.destroy_scene_ui, layer)
      end
    end
  end
  state.ui_status_3d = nil
end

function ui_status_3d_layer.sync(game, state, dirty)
  if not game or not state then
    return
  end
  local cache = _ensure_cache(state)
  if cache.disabled then
    return
  end
  if not (GameAPI and GameAPI.get_role and GameAPI.get_eui_node_at_scene_ui and GameAPI.set_scene_ui_visible) then
    _warn_once(cache, "missing_gameapi", "status3d disabled: missing scene ui GameAPI methods")
    cache.disabled = true
    return
  end
  if not (Enums and Enums.ModelSocket and Enums.ModelSocket.socket_head and math and math.Vector3) then
    _warn_once(cache, "missing_sceneui_env", "status3d disabled: missing scene ui runtime")
    cache.disabled = true
    return
  end
  local _, err = _build_meta(cache)
  if err then
    _warn_once(cache, "meta_error", "status3d disabled: " .. tostring(err))
    cache.disabled = true
    return
  end
  local has_dirty = dirty and (dirty.players or dirty.turn or dirty.any)
  local has_missing_layer = false
  for _, player in ipairs(game.players or {}) do
    if cache.layers_by_player_id[player.id] == nil then
      has_missing_layer = true
      break
    end
  end
  if not has_dirty and not has_missing_layer then
    return
  end
  for _, player in ipairs(game.players or {}) do
    _ensure_layer_for_player(cache, player)
  end
  for _, player in ipairs(game.players or {}) do
    if cache.layers_by_player_id[player.id] ~= nil then
      _sync_layer_status(cache, player, _resolve_player_status_key(game, player))
    end
  end
end

return ui_status_3d_layer
