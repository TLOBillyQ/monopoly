local tiles_cfg = require("src.config.content.tiles")
local player_colors = require("src.presentation.view.support.player_colors")

local tiles_by_id = {}
for _, cfg in ipairs(tiles_cfg) do
  tiles_by_id[cfg.id] = cfg
end

local tile_renderer = {}

local function _set_billboard_text(node, text)
  if node and node.set_billboard_text then
    node.set_billboard_text(text)
    return true
  end
  return false
end

local function _assert_land_node_present(is_land, node_name)
  if is_land then
    assert(false, "missing " .. node_name .. " node")
  end
end

local function _render_name(unit, cfg, tile_id, is_land)
  local name_node = unit.get_child_by_name("name")
  if _set_billboard_text(name_node, cfg.name) then
    return
  end
  _assert_land_node_present(is_land, "name")
end

local function _render_price(unit, cfg, tile_id, is_land)
  local price_node = unit.get_child_by_name("price")
  if _set_billboard_text(price_node, "价格：" .. tostring(cfg.price)) then
    return
  end
  _assert_land_node_present(is_land, "price")
end

local function _render_color(unit, owner_id, is_land)
  local color_node = unit.get_child_by_name("color")
  if color_node and color_node.set_paint_area_color then
    local color = player_colors.resolve_owner_color(owner_id)
    color_node.set_paint_area_color(1, color)
    return
  end
  _assert_land_node_present(is_land, "color")
end

function tile_renderer.render_tile(unit, tile_id, owner_id)
  local cfg = tiles_by_id[tile_id]
  assert(cfg ~= nil, "missing tile cfg: " .. tostring(tile_id))
  assert(unit ~= nil and unit.get_child_by_name ~= nil, "invalid tile unit")
  local is_land = cfg.type == "land"
  assert(cfg.name ~= nil, "missing tile name: " .. tostring(tile_id))
  if is_land then
    assert(cfg.price ~= nil, "missing tile price: " .. tostring(tile_id))
  end
  _render_name(unit, cfg, tile_id, is_land)
  _render_price(unit, cfg, tile_id, is_land)
  _render_color(unit, owner_id, is_land)
end

return tile_renderer
