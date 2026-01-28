local tiles_cfg = require("src.config.tiles")

local TileRenderer = {}

local DEFAULT_COLOR = 0xCFCFCF
local OWNER_COLORS = {
  [1] = 0x4FC3F7,
  [2] = 0x81C784,
  [3] = 0xFFB74D,
  [4] = 0xE57373,
}

local function resolve_color(owner_id)
  return OWNER_COLORS[owner_id] or DEFAULT_COLOR
end

function TileRenderer.render_tile(unit, tile_id, owner_id)
  local cfg = tiles_cfg[tile_id]
  if not (cfg and unit and unit.get_child_by_name) then
    return
  end

  local name_node = unit.get_child_by_name("name")
  if name_node and name_node.set_billboard_text then
    name_node.set_billboard_text(cfg.name or "")
  end

  local price_node = unit.get_child_by_name("price")
  if price_node and price_node.set_billboard_text then
    local price = cfg.price
    if price then
      price_node.set_billboard_text("￥" .. tostring(price))
    else
      price_node.set_billboard_text("")
    end
  end

  local color_node = unit.get_child_by_name("color")
  if color_node and color_node.set_paint_area_color then
    color_node.set_paint_area_color(1, resolve_color(owner_id))
  end
end

return TileRenderer
