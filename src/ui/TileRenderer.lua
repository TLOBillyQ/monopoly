local tiles_cfg = require("Config.Generated.Tiles")
local player_colors = require("src.ui.PlayerColors")

local tiles_by_id = {}
for _, cfg in ipairs(tiles_cfg) do
  tiles_by_id[cfg.id] = cfg
end

local tile_renderer = {}

function tile_renderer.render_tile(unit, tile_id, owner_id)
  local cfg = tiles_by_id[tile_id]
  assert(cfg ~= nil, "missing tile cfg: " .. tostring(tile_id))
  assert(unit ~= nil and unit.get_child_by_name ~= nil, "invalid tile unit")
  local is_land = cfg.type == "land"

  local name_node = unit.get_child_by_name("name")
  if name_node and name_node.set_billboard_text then
    assert(cfg.name ~= nil, "missing tile name: " .. tostring(tile_id))
    name_node.set_billboard_text(cfg.name)
  elseif is_land then
    assert(false, "missing name node")
  end

  local price_node = unit.get_child_by_name("price")
  if price_node and price_node.set_billboard_text then
    assert(cfg.price ~= nil, "missing tile price: " .. tostring(tile_id))
    price_node.set_billboard_text("价格：" .. tostring(cfg.price))
  elseif is_land then
    assert(false, "missing price node")
  end

  local color_node = unit.get_child_by_name("color")
  if color_node and color_node.set_paint_area_color then
    local color = player_colors.resolve_owner_color(owner_id)
    color_node.set_paint_area_color(1, color)
  elseif is_land then
    assert(false, "missing color node")
  end
end

return tile_renderer
