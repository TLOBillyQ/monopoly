local unit_position = require("src.ui.render.unit_position")

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

  return _zero_vector()
end

local function _native_add(a, b)
  return a + b
end

local function _try_native_vector_add(pos, offset)
  return pcall(_native_add, pos, offset)
end

local function _resolve_vector_components(vec)
  local x = _resolve_vector_value(vec, "x", 1) or 0
  local y = _resolve_vector_value(vec, "y", 2) or 0
  local z = _resolve_vector_value(vec, "z", 3) or 0
  return x, y, z
end

local function _create_offset_vector(pos_x, pos_y, pos_z, offset_x, offset_y, offset_z)
  if math and math.Vector3 then
    return math.Vector3(pos_x + offset_x, pos_y + offset_y, pos_z + offset_z)
  end
  return nil
end

function compute.offset_pos(pos, offset)
  local ok, result = _try_native_vector_add(pos, offset)
  if ok then
    return result
  end
  local pos_x, pos_y, pos_z = _resolve_vector_components(pos)
  local offset_x, offset_y, offset_z = _resolve_vector_components(offset)
  local vector = _create_offset_vector(pos_x, pos_y, pos_z, offset_x, offset_y, offset_z)
  if vector then
    return vector
  end
  return pos
end

local function _y_offset_vector(y_offset)
  return math.Vector3(0.0, y_offset or 1.0, 0.0)
end

function compute.overlay_pos_for_tile(state, tile_index, y_offset)
  return compute.offset_pos(compute.resolve_tile_pos(state, tile_index), _y_offset_vector(y_offset))
end

function compute.overlay_pos_for_player(state, player_id, y_offset)
  assert(state ~= nil, "missing state")
  assert(player_id ~= nil, "missing player_id")
  local game = assert(state.game, "missing state.game")
  local player = assert(game:find_player_by_id(player_id), "missing player: " .. tostring(player_id))
  return compute.offset_pos(compute.resolve_tile_pos(state, player.position), _y_offset_vector(y_offset))
end

return compute
