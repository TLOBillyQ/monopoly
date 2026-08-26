local tiles_cfg = require("src.config.content.tiles")
local number_utils = require("src.foundation.number")
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
      text = owner_name .. "\n租 " .. number_utils.format_integer_part(rent)
    else
      text = owner_name
    end
  else
    text = "售 " .. number_utils.format_integer_part(cfg.price)
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

local function _resolve_tile_cfg(unit, tile_id)
  local cfg = tiles_by_id[tile_id]
  assert(cfg ~= nil, "missing tile cfg: " .. tostring(tile_id))
  assert(unit ~= nil and unit.get_child_by_name ~= nil, "invalid tile unit")
  return cfg
end

local function _assert_tile_fields(cfg, tile_id, is_land)
  assert(cfg.name ~= nil, "missing tile name: " .. tostring(tile_id))
  if is_land then
    assert(cfg.price ~= nil, "missing tile price: " .. tostring(tile_id))
  end
end

function tile_renderer.render_tile(unit, tile_id, owner_id, owner_name, level, contiguous_rent)
  local cfg = _resolve_tile_cfg(unit, tile_id)
  local is_land = cfg.type == "land"
  _assert_tile_fields(cfg, tile_id, is_land)
  _render_name(unit, cfg, is_land)
  _render_price(unit, cfg, is_land, owner_name, level, contiguous_rent)
  _render_color(unit, owner_id, is_land)
end

return tile_renderer

--[[ mutate4lua-manifest
version=4
projectHash=2dd9cf1bd309347a
scope.0.id=chunk:src/ui/render/board/tile.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=95
scope.0.semanticHash=0427bb91dbfc42c6
scope.1.id=function:_set_billboard_text
scope.1.kind=function
scope.1.startLine=13
scope.1.endLine=19
scope.1.semanticHash=a596bf6727a7e871
scope.2.id=function:_assert_land_node_present
scope.2.kind=function
scope.2.startLine=21
scope.2.endLine=25
scope.2.semanticHash=1b9318e3d7faf71c
scope.3.id=function:_render_name
scope.3.kind=function
scope.3.startLine=27
scope.3.endLine=33
scope.3.semanticHash=a6f79a12ece95ad8
scope.4.id=function:_display_rent
scope.4.kind=function
scope.4.startLine=35
scope.4.endLine=40
scope.4.semanticHash=a7202b373ffc8fad
scope.5.id=function:_render_price
scope.5.kind=function
scope.5.startLine=42
scope.5.endLine=59
scope.5.semanticHash=a93be186dc7a04eb
scope.6.id=function:_render_color
scope.6.kind=function
scope.6.startLine=61
scope.6.endLine=69
scope.6.semanticHash=68c61495b21498d7
scope.7.id=function:_resolve_tile_cfg
scope.7.kind=function
scope.7.startLine=71
scope.7.endLine=76
scope.7.semanticHash=c6b8195bb4ab4b48
scope.8.id=function:_assert_tile_fields
scope.8.kind=function
scope.8.startLine=78
scope.8.endLine=83
scope.8.semanticHash=089ae68421d8e13d
scope.9.id=function:tile_renderer.render_tile
scope.9.kind=function
scope.9.startLine=85
scope.9.endLine=92
scope.9.semanticHash=a011a1463592f822
]]
