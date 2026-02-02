local TilesCfg = require("Config.Generated.Tiles")

local coord_by_id = {}
local id_by_coord = {}
for _, t in ipairs(TilesCfg) do
  coord_by_id[t.id] = { row = t.row, col = t.col }
  id_by_coord[t.row .. "," .. t.col] = t.id
end

local function direction(from_id, to_id)
  local a = coord_by_id[from_id]
  local b = coord_by_id[to_id]
  assert(a and b, "missing coord: " .. tostring(from_id) .. " -> " .. tostring(to_id))
  local dr = b.row - a.row
  local dc = b.col - a.col
  if dr == -1 and dc == 0 then
    return "up"
  elseif dr == 1 and dc == 0 then
    return "down"
  elseif dr == 0 and dc == -1 then
    return "left"
  elseif dr == 0 and dc == 1 then
    return "right"
  end
  assert(false, "invalid direction: " .. tostring(from_id) .. " -> " .. tostring(to_id))
end

local function id_at(coord)
  local id = id_by_coord[coord[1] .. "," .. coord[2]]
  assert(id, "missing tile at (" .. tostring(coord[1]) .. "," .. tostring(coord[2]) .. ")")
  return id
end

local function to_ids(coords)
  local ids = {}
  for i, coord in ipairs(coords) do
    ids[i] = id_at(coord)
  end
  return ids
end

local TURN_LEFT = {
  up = "left",
  left = "down",
  down = "right",
  right = "up",
}

local TURN_RIGHT = {
  up = "right",
  right = "down",
  down = "left",
  left = "up",
}

local function add_neighbor(neighbors, a, b)
  local d_ab = direction(a, b)
  local d_ba = direction(b, a)
  assert(d_ab and d_ba, "invalid edge (not orthogonal adjacent): " .. tostring(a) .. " <-> " .. tostring(b))
  neighbors[a] = neighbors[a] or {}
  neighbors[b] = neighbors[b] or {}
  neighbors[a][d_ab] = b
  neighbors[b][d_ba] = a
end

local outer_ccw_coords = {
  { 9, 9 }, { 9, 8 }, { 9, 7 }, { 9, 6 }, { 9, 5 }, { 9, 4 }, { 9, 3 }, { 9, 2 }, { 9, 1 },
  { 8, 1 }, { 7, 1 }, { 6, 1 }, { 5, 1 }, { 4, 1 }, { 3, 1 }, { 2, 1 }, { 1, 1 },
  { 1, 2 }, { 1, 3 }, { 1, 4 }, { 1, 5 }, { 1, 6 }, { 1, 7 }, { 1, 8 }, { 1, 9 },
  { 2, 9 }, { 3, 9 }, { 4, 9 }, { 5, 9 }, { 6, 9 }, { 7, 9 }, { 8, 9 },
}

local outer_ccw_ids = to_ids(outer_ccw_coords)

local outer_next = {}
local outer_prev = {}
for i, id in ipairs(outer_ccw_ids) do
  local next_id = outer_ccw_ids[(i % #outer_ccw_ids) + 1]
  local prev_id = outer_ccw_ids[((i - 2) % #outer_ccw_ids) + 1]
  outer_next[id] = next_id
  outer_prev[id] = prev_id
end

local edges = {}
local function chain(coords)
  for i = 1, #coords - 1 do
    table.insert(edges, { coords[i], coords[i + 1] })
  end
end

chain(outer_ccw_coords)
table.insert(edges, { outer_ccw_coords[#outer_ccw_coords], outer_ccw_coords[1] })

chain({ { 9, 5 }, { 8, 5 }, { 7, 5 }, { 6, 5 }, { 5, 5 }, { 4, 5 }, { 3, 5 }, { 2, 5 }, { 1, 5 } })
chain({ { 5, 1 }, { 5, 2 }, { 5, 3 }, { 5, 4 }, { 5, 5 }, { 5, 6 }, { 5, 7 }, { 5, 8 }, { 5, 9 } })

local neighbors = {}
for _, e in ipairs(edges) do
  add_neighbor(neighbors, id_at(e[1]), id_at(e[2]))
end

local entry_points = {}
entry_points[id_at({ 9, 5 })] = { inner_id = id_at({ 8, 5 }) }
entry_points[id_at({ 5, 1 })] = { inner_id = id_at({ 5, 2 }) }
entry_points[id_at({ 1, 5 })] = { inner_id = id_at({ 2, 5 }) }
entry_points[id_at({ 5, 9 })] = { inner_id = id_at({ 5, 8 }) }

local path = {}
for _, id in ipairs(outer_ccw_ids) do
  table.insert(path, id)
end
for _, id in ipairs(to_ids({
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
  entry_points = entry_points,
  branches = {},
  start_id = id_at({ 9, 9 }),
  market_id = id_at({ 5, 5 }),
  direction = direction,
  turn_left = TURN_LEFT,
  turn_right = TURN_RIGHT,
}
