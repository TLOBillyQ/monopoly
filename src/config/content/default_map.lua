local tiles_cfg = require("src.config.content.tiles")
local tables = require("src.foundation.tables")

local coord_by_id = {}
local id_by_coord = {}
for _, t in ipairs(tiles_cfg) do
  coord_by_id[t.id] = { row = t.row, col = t.col }
  id_by_coord[tostring(t.row) .. "," .. tostring(t.col)] = t.id
end

-- Keyed by "row_delta,col_delta"; only single-step orthogonal moves are legal.
local _direction_by_delta = {
  ["-1,0"] = "up",
  ["1,0"] = "down",
  ["0,-1"] = "left",
  ["0,1"] = "right",
}

local function _direction(from_id, to_id)
  local a = coord_by_id[from_id]
  local b = coord_by_id[to_id]
  assert(a and b, "missing coord: " .. tostring(from_id) .. " -> " .. tostring(to_id))
  local delta = tostring(b.row - a.row) .. "," .. tostring(b.col - a.col)
  local direction = _direction_by_delta[delta]
  assert(direction, "invalid direction: " .. tostring(from_id) .. " -> " .. tostring(to_id))
  return direction
end

local function _id_at(coord)
  local id = id_by_coord[tostring(coord[1]) .. "," .. tostring(coord[2])]
  assert(id, "missing tile at (" .. tostring(coord[1]) .. "," .. tostring(coord[2]) .. ")")
  return id
end

local function _to_ids(coords)
  local ids = {}
  for i, coord in ipairs(coords) do
    ids[i] = _id_at(coord)
  end
  return ids
end

local turn_left = {
  up = "left",
  left = "down",
  down = "right",
  right = "up",
}

local turn_right = {
  up = "right",
  right = "down",
  down = "left",
  left = "up",
}

local function _add_neighbor(neighbors, a, b)
  local neighbors_a = tables.ensure_absent_field(neighbors, a)
  local neighbors_b = tables.ensure_absent_field(neighbors, b)
  neighbors_a[_direction(a, b)] = b
  neighbors_b[_direction(b, a)] = a
end

local outer_ccw_coords = {
  { 9, 9 }, { 9, 8 }, { 9, 7 }, { 9, 6 }, { 9, 5 }, { 9, 4 }, { 9, 3 }, { 9, 2 }, { 9, 1 },
  { 8, 1 }, { 7, 1 }, { 6, 1 }, { 5, 1 }, { 4, 1 }, { 3, 1 }, { 2, 1 }, { 1, 1 },
  { 1, 2 }, { 1, 3 }, { 1, 4 }, { 1, 5 }, { 1, 6 }, { 1, 7 }, { 1, 8 }, { 1, 9 },
  { 2, 9 }, { 3, 9 }, { 4, 9 }, { 5, 9 }, { 6, 9 }, { 7, 9 }, { 8, 9 },
}

local outer_ccw_ids = _to_ids(outer_ccw_coords)

local outer_next = {}
local outer_prev = {}
for i, id in ipairs(outer_ccw_ids) do
  local next_id = outer_ccw_ids[(i % #outer_ccw_ids) + 1]
  local prev_id = outer_ccw_ids[((i - 2) % #outer_ccw_ids) + 1]
  outer_next[id] = next_id
  outer_prev[id] = prev_id
end

local edges = {}
local function _chain(coords)
  for i = 1, #coords - 1 do
    table.insert(edges, { coords[i], coords[i + 1] })
  end
end

_chain(outer_ccw_coords)
table.insert(edges, { outer_ccw_coords[#outer_ccw_coords], outer_ccw_coords[1] })

_chain({ { 9, 5 }, { 8, 5 }, { 7, 5 }, { 6, 5 }, { 5, 5 }, { 4, 5 }, { 3, 5 }, { 2, 5 }, { 1, 5 } })
_chain({ { 5, 1 }, { 5, 2 }, { 5, 3 }, { 5, 4 }, { 5, 5 }, { 5, 6 }, { 5, 7 }, { 5, 8 }, { 5, 9 } })

local neighbors = {}
for _, e in ipairs(edges) do
  _add_neighbor(neighbors, _id_at(e[1]), _id_at(e[2]))
end

local entry_points = {}
entry_points[_id_at({ 9, 5 })] = { inner_id = _id_at({ 8, 5 }) }
entry_points[_id_at({ 5, 1 })] = { inner_id = _id_at({ 5, 2 }) }
entry_points[_id_at({ 1, 5 })] = { inner_id = _id_at({ 2, 5 }) }
entry_points[_id_at({ 5, 9 })] = { inner_id = _id_at({ 5, 8 }) }

local backward_fallback = {
  [_id_at({ 8, 5 })] = _id_at({ 9, 5 }),
  [_id_at({ 7, 5 })] = _id_at({ 8, 5 }),
  [_id_at({ 6, 5 })] = _id_at({ 7, 5 }),
  [_id_at({ 5, 5 })] = _id_at({ 5, 4 }),
  [_id_at({ 5, 2 })] = _id_at({ 5, 1 }),
  [_id_at({ 5, 3 })] = _id_at({ 5, 2 }),
  [_id_at({ 5, 4 })] = _id_at({ 5, 3 }),
  [_id_at({ 4, 5 })] = _id_at({ 5, 5 }),
  [_id_at({ 3, 5 })] = _id_at({ 4, 5 }),
  [_id_at({ 2, 5 })] = _id_at({ 3, 5 }),
  [_id_at({ 5, 7 })] = _id_at({ 5, 6 }),
  [_id_at({ 5, 8 })] = _id_at({ 5, 7 }),
  [_id_at({ 5, 6 })] = _id_at({ 5, 5 }),
}

local fresh_forward_next = {
  [_id_at({ 5, 2 })] = _id_at({ 5, 3 }),
  [_id_at({ 5, 3 })] = _id_at({ 5, 4 }),
  [_id_at({ 5, 4 })] = _id_at({ 5, 5 }),
  [_id_at({ 4, 5 })] = _id_at({ 5, 5 }),
  [_id_at({ 3, 5 })] = _id_at({ 4, 5 }),
  [_id_at({ 2, 5 })] = _id_at({ 3, 5 }),
  [_id_at({ 7, 5 })] = _id_at({ 6, 5 }),
  [_id_at({ 6, 5 })] = _id_at({ 5, 5 }),
  [_id_at({ 5, 7 })] = _id_at({ 5, 6 }),
  [_id_at({ 5, 8 })] = _id_at({ 5, 7 }),
  [_id_at({ 5, 6 })] = _id_at({ 5, 5 }),
  [_id_at({ 8, 5 })] = _id_at({ 7, 5 }),
}

local path = {}
for _, id in ipairs(outer_ccw_ids) do
  table.insert(path, id)
end
for _, id in ipairs(_to_ids({
  { 5, 2 }, { 5, 3 }, { 5, 4 }, { 4, 5 }, { 3, 5 }, { 2, 5 }, { 7, 5 },
  { 6, 5 }, { 5, 7 }, { 5, 8 }, { 5, 5 }, { 5, 6 }, { 8, 5 },
})) do
  table.insert(path, id)
end

return {
  path = path,
  neighbors = neighbors,
  outer_next = outer_next,
  outer_prev = outer_prev,
  backward_fallback = backward_fallback,
  entry_points = entry_points,
  fresh_forward_next = fresh_forward_next,
  branches = {},
  start_id = _id_at({ 9, 9 }),
  market_id = _id_at({ 5, 5 }),
  direction = _direction,
  turn_left = turn_left,
  turn_right = turn_right,
}

--[[ mutate4lua-manifest
version=4
projectHash=7df3babe6dd16433
scope.0.id=chunk:src/config/content/default_map.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=163
scope.0.semanticHash=588bff896e19aac5
scope.1.id=function:_direction
scope.1.kind=function
scope.1.startLine=19
scope.1.endLine=27
scope.1.semanticHash=68f77a5950824ed6
scope.2.id=function:_id_at
scope.2.kind=function
scope.2.startLine=29
scope.2.endLine=33
scope.2.semanticHash=cd80614a727bb28b
scope.3.id=function:_to_ids
scope.3.kind=function
scope.3.startLine=35
scope.3.endLine=41
scope.3.semanticHash=a42861a62f41a049
scope.4.id=function:_add_neighbor
scope.4.kind=function
scope.4.startLine=57
scope.4.endLine=62
scope.4.semanticHash=90bfc20615b7dd3b
scope.5.id=function:_chain
scope.5.kind=function
scope.5.startLine=83
scope.5.endLine=87
scope.5.semanticHash=a1347e99955e6015
]]
