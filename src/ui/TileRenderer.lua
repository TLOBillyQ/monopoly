local tiles_cfg = require("Config.Generated.Tiles")

local tiles_by_id = {}
for _, cfg in ipairs(tiles_cfg) do
  tiles_by_id[cfg.id] = cfg
end

local tile_renderer = {}

local default_color = 0xcfcfcf
local owner_colors = {
  [1] = 0x4fc3f7,
  [2] = 0x81c784,
  [3] = 0xffb74d,
  [4] = 0xe57373,
}

local function _resolve_color(owner_id)
  return owner_colors[owner_id] or default_color
end

function tile_renderer.render_tile(unit, tile_id, owner_id)
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
  color_node.set_paint_area_color(1, _resolve_color(owner_id))
end

return tile_renderer
