local tiles_cfg = require("src.config.content.tiles")
local tile_rent = require("src.ui.view.tile_rent")
local player_colors = require("src.ui.view.player_colors")

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

local function _render_name(unit, cfg, is_land)
  local name_node = unit.get_child_by_name("name")
  if _set_billboard_text(name_node, cfg.name) then
    return
  end
  _assert_land_node_present(is_land, "name")
end

local function _display_rent(cfg, level, contiguous_rent)
  if contiguous_rent and contiguous_rent > 0 then
    return contiguous_rent
  end
  return tile_rent.for_level(cfg, level)
end

local function _render_price(unit, cfg, is_land, owner_name, level, contiguous_rent)
  local price_node = unit.get_child_by_name("price")
  local text
  if owner_name then
    local rent = _display_rent(cfg, level, contiguous_rent)
    if rent and rent > 0 then
      text = owner_name .. "\n租 " .. tostring(rent)
    else
      text = owner_name
    end
  else
    text = "售 " .. tostring(cfg.price)
  end
  if _set_billboard_text(price_node, text) then
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

function tile_renderer.render_tile(unit, tile_id, owner_id, owner_name, level, contiguous_rent)
  local cfg = tiles_by_id[tile_id]
  assert(cfg ~= nil, "missing tile cfg: " .. tostring(tile_id))
  assert(unit ~= nil and unit.get_child_by_name ~= nil, "invalid tile unit")
  local is_land = cfg.type == "land"
  assert(cfg.name ~= nil, "missing tile name: " .. tostring(tile_id))
  if is_land then
    assert(cfg.price ~= nil, "missing tile price: " .. tostring(tile_id))
  end
  _render_name(unit, cfg, is_land)
  _render_price(unit, cfg, is_land, owner_name, level, contiguous_rent)
  _render_color(unit, owner_id, is_land)
end

return tile_renderer

--[[ mutate4lua-manifest
version=2
projectHash=1ce6e6ed11a7a57a
scope.0.id=chunk:src/ui/render/tile.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=90
scope.0.semanticHash=01910df4fbee6bd8
scope.1.id=function:_set_billboard_text:11
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=17
scope.1.semanticHash=ed7d38d52d8b3118
scope.2.id=function:_assert_land_node_present:19
scope.2.kind=function
scope.2.startLine=19
scope.2.endLine=23
scope.2.semanticHash=f373c9d5ea7ab38e
scope.3.id=function:_render_name:25
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=31
scope.3.semanticHash=cb00aff17281bcc9
scope.4.id=function:_rent_for_level:33
scope.4.kind=function
scope.4.startLine=33
scope.4.endLine=40
scope.4.semanticHash=5c28b883b24823ba
scope.5.id=function:_render_price:42
scope.5.kind=function
scope.5.startLine=42
scope.5.endLine=63
scope.5.semanticHash=3645c52d0f84fc49
scope.6.id=function:_render_color:65
scope.6.kind=function
scope.6.startLine=65
scope.6.endLine=73
scope.6.semanticHash=1258dbbd951cf218
scope.7.id=function:tile_renderer.render_tile:75
scope.7.kind=function
scope.7.startLine=75
scope.7.endLine=87
scope.7.semanticHash=bcdbd455731b19b5
]]
