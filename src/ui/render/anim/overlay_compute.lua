local unit_position = require("src.ui.render.unit_position")

local compute = {}

local function _resolve_vector_value(vec, key, index)
  if type(vec) ~= "table" then
    return nil
  end
  return vec[key] or vec[index]
end

local _ZERO_VEC = (math and math.Vector3) and math.Vector3(0.0, 0.0, 0.0) or { x = 0.0, y = 0.0, z = 0.0 }

local function _zero_vector()
  return _ZERO_VEC
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

local function _offset_pos(pos, offset)
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

local _y_offset_cache = {}
local function _y_offset_vector(y_offset)
  local key = y_offset or 1.0
  local cached = _y_offset_cache[key]
  if cached then
    return cached
  end
  cached = math.Vector3(0.0, key, 0.0)
  _y_offset_cache[key] = cached
  return cached
end

function compute.overlay_pos_for_tile(state, tile_index, y_offset)
  return _offset_pos(compute.resolve_tile_pos(state, tile_index), _y_offset_vector(y_offset))
end

function compute.overlay_pos_for_player(state, player_id, y_offset)
  assert(state ~= nil, "missing state")
  assert(player_id ~= nil, "missing player_id")
  local game = assert(state.game, "missing state.game")
  local player = assert(game:find_player_by_id(player_id), "missing player: " .. tostring(player_id))
  return _offset_pos(compute.resolve_tile_pos(state, player.position), _y_offset_vector(y_offset))
end

return compute

--[[ mutate4lua-manifest
version=2
projectHash=3fc548a8050ce86f
scope.0.id=chunk:src/ui/render/anim/overlay_compute.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=101
scope.0.semanticHash=2a23a3aa3d99e2c7
scope.1.id=function:_resolve_vector_value:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=10
scope.1.semanticHash=f5183e388fd057bd
scope.2.id=function:_zero_vector:14
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=16
scope.2.semanticHash=dcf1e694edceb014
scope.3.id=function:compute.resolve_tile_pos:18
scope.3.kind=function
scope.3.startLine=18
scope.3.endLine=38
scope.3.semanticHash=6e3a252e5a1e4feb
scope.4.id=function:_native_add:40
scope.4.kind=function
scope.4.startLine=40
scope.4.endLine=42
scope.4.semanticHash=216841ec3bc3eafc
scope.5.id=function:_try_native_vector_add:44
scope.5.kind=function
scope.5.startLine=44
scope.5.endLine=46
scope.5.semanticHash=564e850dc341a6d2
scope.6.id=function:_resolve_vector_components:48
scope.6.kind=function
scope.6.startLine=48
scope.6.endLine=53
scope.6.semanticHash=a9e5098bc9227b77
scope.7.id=function:_create_offset_vector:55
scope.7.kind=function
scope.7.startLine=55
scope.7.endLine=60
scope.7.semanticHash=8056c18202ce08af
scope.8.id=function:_offset_pos:62
scope.8.kind=function
scope.8.startLine=62
scope.8.endLine=74
scope.8.semanticHash=0a5eb5c16bae45ed
scope.9.id=function:_y_offset_vector:77
scope.9.kind=function
scope.9.startLine=77
scope.9.endLine=86
scope.9.semanticHash=60ea8196db829033
scope.10.id=function:compute.overlay_pos_for_tile:88
scope.10.kind=function
scope.10.startLine=88
scope.10.endLine=90
scope.10.semanticHash=ba91fbaa81c500df
scope.11.id=function:compute.overlay_pos_for_player:92
scope.11.kind=function
scope.11.startLine=92
scope.11.endLine=98
scope.11.semanticHash=be854e3cda8d945e
]]
