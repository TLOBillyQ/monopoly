local player_colors = require("src.ui.pres.player_colors")
local base_nodes = require("src.ui.schema.base")
local number_utils = require("src.core.utils.number")

local panel_player_slots = {}

local player_label_patterns = {
  base_nodes.player_name,
  base_nodes.player_cash,
  base_nodes.player_cash_delta,
  base_nodes.player_land_count,
  base_nodes.player_total_assets,
}

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
  for _, pattern in ipairs(player_label_patterns) do
    callback(string.format(pattern, index))
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
    _set_visible_safe(ui, string.format(base_nodes.player_crown, i), visible == true)
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
    local image_node = runtime.query_node(string.format(base_nodes.player_color, index))
    pcall(set_image_color, role, image_node, color, 0)
  end
  if set_label_color then
    _for_each_player_label_name(index, function(name)
      local ok, label_node = pcall(runtime.query_node, name)
      if ok then
        pcall(set_label_color, role, label_node, color, 0)
      end
    end)
  end
end

function panel_player_slots.render_player_slot(ui, runtime, row, index, empty_avatar_key, refresh_cash_delta_label)
  assert(row ~= nil, "missing player row: " .. tostring(index))
  ui:set_label(string.format(base_nodes.player_name, index), row.name)
  ui:set_label(string.format(base_nodes.player_cash, index), row.cash)
  ui:set_label(string.format(base_nodes.player_land_count, index), row.land_count)
  ui:set_label(string.format(base_nodes.player_total_assets, index), row.total_assets)
  refresh_cash_delta_label(ui, index, row)
  _set_player_avatar(ui, runtime, string.format(base_nodes.player_avatar, index), _resolve_avatar_key(row, empty_avatar_key))
end

return panel_player_slots
