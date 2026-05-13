local player_colors = require("src.ui.view.player_colors")
local base_nodes = require("src.ui.schema.base")
local number_utils = require("src.foundation.lang.number")

local panel_player_slots = {}

local player_label_patterns = {
  base_nodes.player_name,
  base_nodes.player_cash,
  base_nodes.player_cash_delta,
  base_nodes.player_land_count,
  base_nodes.player_total_assets,
}

local _player_nodes = {}
for _i = 1, 4 do
  local labels = {}
  for _, pattern in ipairs(player_label_patterns) do
    labels[#labels + 1] = string.format(pattern, _i)
  end
  _player_nodes[_i] = {
    name = string.format(base_nodes.player_name, _i),
    cash = string.format(base_nodes.player_cash, _i),
    land_count = string.format(base_nodes.player_land_count, _i),
    total_assets = string.format(base_nodes.player_total_assets, _i),
    crown = string.format(base_nodes.player_crown, _i),
    avatar = string.format(base_nodes.player_avatar, _i),
    color = string.format(base_nodes.player_color, _i),
    labels = labels,
  }
end

local function _set_visible_safe(ui, name, visible)
  if not ui or type(ui.set_visible) ~= "function" then
    return false
  end
  local ok = pcall(ui.set_visible, ui, name, visible)
  return ok
end

local function _resolve_avatar_key(row, empty_avatar_key)
  if row and row.avatar ~= nil then
    return row.avatar
  end
  return empty_avatar_key
end

local function _resolve_integer_field(row, key)
  if not row then
    return nil
  end
  return number_utils.to_integer(row[key])
end

local function _set_player_avatar(ui, runtime, avatar_name, image_key)
  if image_key == nil then
    return
  end
  local avatar_node = ui.query_node and ui.query_node(avatar_name) or runtime.query_node(avatar_name)
  runtime.set_node_texture_native_size(avatar_node, image_key)
end

local function _for_each_player_label_name(index, callback)
  local nodes = _player_nodes[index]
  if nodes then
    for _, name in ipairs(nodes.labels) do
      callback(name)
    end
  end
end

function panel_player_slots.force_item_slots_visible_for_player(ui, ctx)
  if not ui or not ui.set_visible then
    return
  end
  if not ctx or ctx.is_player_role ~= true then
    return
  end
  local slots = ui.item_slots or {}
  for _, slot_name in ipairs(slots) do
    ui:set_visible(slot_name, true)
  end
end

function panel_player_slots.refresh_player_crowns(ui, player_rows)
  local top_total_assets = nil
  for i = 1, 4 do
    local row = player_rows[i]
    local total_assets_value = _resolve_integer_field(row, "total_assets_value")
    if row and row.eliminated ~= true and total_assets_value ~= nil
        and (top_total_assets == nil or total_assets_value > top_total_assets) then
      top_total_assets = total_assets_value
    end
  end
  for i = 1, 4 do
    local row = player_rows[i]
    local total_assets_value = _resolve_integer_field(row, "total_assets_value")
    local visible = row and row.eliminated ~= true and top_total_assets ~= nil
        and total_assets_value ~= nil and total_assets_value == top_total_assets
    _set_visible_safe(ui, _player_nodes[i].crown, visible == true)
  end
end

local _lc_runtime
local _lc_fn
local _lc_role
local _lc_color

local function _apply_label_color_callback(name)
  local ok, label_node = pcall(_lc_runtime.query_node, name)
  if ok then
    pcall(_lc_fn, _lc_role, label_node, _lc_color, 0)
  end
end

function panel_player_slots.apply_player_colors(role, runtime, player, index)
  if not role then
    return
  end
  local set_image_color = role.set_image_color
  local set_label_color = role.set_label_color
  if not set_image_color and not set_label_color then
    return
  end
  local player_id = player and player.id or nil
  local color = player_colors.resolve_owner_color(player_id)
  if set_image_color then
    local image_node = runtime.query_node(_player_nodes[index].color)
    pcall(set_image_color, role, image_node, color, 0)
  end
  if set_label_color then
    _lc_runtime = runtime
    _lc_fn = set_label_color
    _lc_role = role
    _lc_color = color
    _for_each_player_label_name(index, _apply_label_color_callback)
  end
end

function panel_player_slots.render_player_slot(ui, runtime, row, index, empty_avatar_key, refresh_cash_delta_label)
  assert(row ~= nil, "missing player row: " .. tostring(index))
  local nodes = _player_nodes[index]
  ui:set_label(nodes.name, row.name)
  ui:set_label(nodes.cash, row.cash)
  ui:set_label(nodes.land_count, row.land_count)
  ui:set_label(nodes.total_assets, row.total_assets)
  refresh_cash_delta_label(ui, index, row)
  _set_player_avatar(ui, runtime, nodes.avatar, _resolve_avatar_key(row, empty_avatar_key))
end

return panel_player_slots
