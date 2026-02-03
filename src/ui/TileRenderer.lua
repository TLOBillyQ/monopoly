local TilesCfg = require("Config.Generated.Tiles")

local tiles_by_id = {}
for _, cfg in ipairs(TilesCfg) do
  tiles_by_id[cfg.id] = cfg
end

local TileRenderer = {}

local DEFAULT_COLOR = 0xCFCFCF
local OWNER_COLORS = {
  [1] = 0x4FC3F7,
  [2] = 0x81C784,
  [3] = 0xFFB74D,
  [4] = 0xE57373,
}

local function _ResolveColor(owner_id)
  return OWNER_COLORS[owner_id] or DEFAULT_COLOR
end

function TileRenderer.RenderTile(unit, tile_id, owner_id)
  local cfg = tiles_by_id[tile_id]
  assert(cfg ~= nil, "missing tile cfg: " .. tostring(tile_id))
  assert(unit ~= nil and unit.get_child_by_name ~= nil, "invalid tile unit")

  local name_node = unit.get_child_by_name("name")
  assert(name_node ~= nil and name_node.set_billboard_text ~= nil, "missing name node")
  assert(cfg.name ~= nil, "missing tile name: " .. tostring(tile_id))
  name_node.set_billboard_text(cfg.name)

  local price_node = unit.get_child_by_name("price")
  assert(price_node ~= nil and price_node.set_billboard_text ~= nil, "missing price node")
  assert(cfg.price ~= nil, "missing tile price: " .. tostring(tile_id))
  price_node.set_billboard_text("￥" .. tostring(cfg.price))

  local color_node = unit.get_child_by_name("color")
  assert(color_node ~= nil and color_node.set_paint_area_color ~= nil, "missing color node")
  color_node.set_paint_area_color(1, _ResolveColor(owner_id))
end

return TileRenderer
