
local tiles = require("src.config.tiles")

local START_ID = 35
local MARKET_ID = 39

local coord_by_id = {}
for _, t in ipairs(tiles) do
  coord_by_id[t.id] = { row = t.row, col = t.col }
end

local function direction(from_id, to_id)
  local a = coord_by_id[from_id]
  local b = coord_by_id[to_id]
  if not a or not b then
    return nil
  end
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
  return nil
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

-- 外圈：默认向前为逆时针
local outer_ccw = {
  35, 1, 2, 3, 45, 4, 5, 6, 38,
  7, 8, 9, 40, 10, 11, 12, 37,
  13, 14, 15, 44, 16, 17, 18, 36,
  19, 20, 21, 43, 22, 23, 24,
}

local outer_next = {}
local outer_prev = {}
for i, id in ipairs(outer_ccw) do
  local next_id = outer_ccw[(i % #outer_ccw) + 1]
  local prev_id = outer_ccw[((i - 2) % #outer_ccw) + 1]
  outer_next[id] = next_id
  outer_prev[id] = prev_id
end

-- 内圈“十字通道”连接（与外圈四个中点相连）
-- 45(下中) <-> 42 <-> 31 <-> 32 <-> 39 <-> 28 <-> 29 <-> 30 <-> 44(上中)
-- 40(左中) <-> 25 <-> 26 <-> 27 <-> 39 <-> 41 <-> 33 <-> 34 <-> 43(右中)
local edges = {}
local function chain(list)
  for i = 1, #list - 1 do
    table.insert(edges, { list[i], list[i + 1] })
  end
end

chain(outer_ccw)
table.insert(edges, { 24, 35 })

chain({ 45, 42, 31, 32, 39, 28, 29, 30, 44 })
chain({ 40, 25, 26, 27, 39, 41, 33, 34, 43 })

local neighbors = {}
for _, e in ipairs(edges) do
  add_neighbor(neighbors, e[1], e[2])
end

-- 四个入口点：偶数点数进入内圈（仅当从外圈逆时针方向抵达入口点时触发）
local entry_points = {
  [45] = { inner_id = 42 },
  [40] = { inner_id = 25 },
  [44] = { inner_id = 30 },
  [43] = { inner_id = 34 },
}

-- board.path 只用于提供 tile->index 的索引；实际移动按 neighbors/规则计算。
local path = {}
for _, id in ipairs(outer_ccw) do
  table.insert(path, id)
end
for _, id in ipairs({ 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 39, 41, 42 }) do
  table.insert(path, id)
end

return {
  path = path,
  neighbors = neighbors,
  outer_next = outer_next,
  outer_prev = outer_prev,
  entry_points = entry_points,
  start_id = START_ID,
  market_id = MARKET_ID,
  direction = direction,
  turn_left = TURN_LEFT,
  turn_right = TURN_RIGHT,
}
