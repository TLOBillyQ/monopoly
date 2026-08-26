local host_types = require("src.foundation.host_types")
local unit_position = require("src.ui.render.support.unit_position")

local compute = {}

-- vec 是宿主 Vector3，type() 返回的是宿主类名而不是 "table"（#266），不能拿
-- type(vec) == "table" 把门——那样真机上每个分量都取成 nil。
local function _resolve_vector_value(vec, key, index)
  local value = host_types.field(vec, key)
  if value ~= nil then
    return value
  end
  return host_types.field(vec, index)
end

local _ZERO_VEC = host_types.vec3(0.0, 0.0, 0.0)

local function _zero_vector()
  return _ZERO_VEC
end

local function _validate_tile_query(state, tile_index)
  assert(state ~= nil, "missing state")
  assert(tile_index ~= nil, "missing tile_index")
  local scene = assert(state.board_scene, "missing board_scene")
  local tiles = assert(scene.tiles, "missing scene.tiles")
  return scene, tiles
end

local function _read_position_from_table(tbl, index)
  if type(tbl) ~= "table" then
    return nil
  end
  return unit_position.read_unit_position(tbl[index])
end

function compute.resolve_tile_pos(state, tile_index)
  local scene, tiles = _validate_tile_query(state, tile_index)
  local tile_pos = _read_position_from_table(tiles, tile_index)
  if tile_pos ~= nil then
    return tile_pos
  end

  local building_pos = _read_position_from_table(scene.buildings, tile_index)
  if building_pos ~= nil then
    return building_pos
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
version=4
projectHash=541ae7af84f65001
scope.0.id=chunk:src/ui/render/anim/overlay_compute.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=113
scope.0.semanticHash=31abea8e5bd8fd82
scope.1.id=function:_resolve_vector_value
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=14
scope.1.semanticHash=b33aa7b4b0f25ec7
scope.2.id=function:_zero_vector
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=20
scope.2.semanticHash=1136505bd37c301e
scope.3.id=function:_validate_tile_query
scope.3.kind=function
scope.3.startLine=22
scope.3.endLine=28
scope.3.semanticHash=63bbd93e364eb3f1
scope.4.id=function:_read_position_from_table
scope.4.kind=function
scope.4.startLine=30
scope.4.endLine=35
scope.4.semanticHash=6dfbdf7b4f6283eb
scope.5.id=function:compute.resolve_tile_pos
scope.5.kind=function
scope.5.startLine=37
scope.5.endLine=50
scope.5.semanticHash=d8c7af8848b5b1e8
scope.6.id=function:_native_add
scope.6.kind=function
scope.6.startLine=52
scope.6.endLine=54
scope.6.semanticHash=e456a1347b703661
scope.7.id=function:_try_native_vector_add
scope.7.kind=function
scope.7.startLine=56
scope.7.endLine=58
scope.7.semanticHash=b24edc9efb4ea62a
scope.8.id=function:_resolve_vector_components
scope.8.kind=function
scope.8.startLine=60
scope.8.endLine=65
scope.8.semanticHash=32d81c1d4e27a0dd
scope.9.id=function:_create_offset_vector
scope.9.kind=function
scope.9.startLine=67
scope.9.endLine=72
scope.9.semanticHash=50e2cf06849729de
scope.10.id=function:_offset_pos
scope.10.kind=function
scope.10.startLine=74
scope.10.endLine=86
scope.10.semanticHash=87d5b27163764203
scope.11.id=function:_y_offset_vector
scope.11.kind=function
scope.11.startLine=89
scope.11.endLine=98
scope.11.semanticHash=4ce1d570650309cb
scope.12.id=function:compute.overlay_pos_for_tile
scope.12.kind=function
scope.12.startLine=100
scope.12.endLine=102
scope.12.semanticHash=97ceea78605eb7e7
scope.13.id=function:compute.overlay_pos_for_player
scope.13.kind=function
scope.13.startLine=104
scope.13.endLine=110
scope.13.semanticHash=1a2a43a857ae555d
]]
