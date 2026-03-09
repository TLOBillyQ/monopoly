local logger = require("src.core.utils.logger")
local unit_position = require("src.presentation.view.render.unit_position")

local compute = {}

local function _resolve_vector_value(vec, key, index)
  if type(vec) ~= "table" then
    return nil
  end
  return vec[key] or vec[index]
end

local function _zero_vector()
  if math and math.Vector3 then
    return math.Vector3(0.0, 0.0, 0.0)
  end
  return {
    x = 0.0,
    y = 0.0,
    z = 0.0,
  }
end

function compute.resolve_tile_pos(state, tile_index)
  assert(state ~= nil, "missing state")
  assert(tile_index ~= nil, "missing tile_index")
  local scene = assert(state.board_scene, "missing board_scene")
  local tiles = assert(scene.tiles, "missing scene.tiles")
  local tile = tiles[tile_index]
  local tile_pos = unit_position.read_unit_position(tile)
  if tile_pos ~= nil then
    return tile_pos
  end

  local buildings = scene.buildings
  if type(buildings) == "table" then
    local building_pos = unit_position.read_unit_position(buildings[tile_index])
    if building_pos ~= nil then
      return building_pos
    end
  end

  logger.warn(
    "[OverlayDebug]",
    "resolve_tile_pos fallback_zero",
    "tile_index=" .. tostring(tile_index),
    "tile_exists=" .. tostring(tile ~= nil),
    "building_exists=" .. tostring(type(buildings) == "table" and buildings[tile_index] ~= nil or false)
  )
  return _zero_vector()
end

function compute.offset_pos(pos, offset)
  local ok, result = pcall(function()
    return pos + offset
  end)
  if ok then
    return result
  end
  local pos_x = _resolve_vector_value(pos, "x", 1) or 0
  local pos_y = _resolve_vector_value(pos, "y", 2) or 0
  local pos_z = _resolve_vector_value(pos, "z", 3) or 0
  local offset_x = _resolve_vector_value(offset, "x", 1) or 0
  local offset_y = _resolve_vector_value(offset, "y", 2) or 0
  local offset_z = _resolve_vector_value(offset, "z", 3) or 0
  if math and math.Vector3 then
    return math.Vector3(pos_x + offset_x, pos_y + offset_y, pos_z + offset_z)
  end
  return pos
end

function compute.overlay_pos_for_tile(state, tile_index)
  return compute.offset_pos(compute.resolve_tile_pos(state, tile_index), math.Vector3(0.0, 1.0, 0.0))
end

function compute.overlay_pos_for_player(state, player_id)
  assert(state ~= nil, "missing state")
  assert(player_id ~= nil, "missing player_id")
  local game = assert(state.game, "missing state.game")
  local player = assert(game:find_player_by_id(player_id), "missing player: " .. tostring(player_id))
  return compute.offset_pos(compute.resolve_tile_pos(state, player.position), math.Vector3(0.0, 1.0, 0.0))
end

return compute
