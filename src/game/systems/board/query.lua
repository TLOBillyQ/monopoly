local board_query = {}

function board_query.queue_walk(queue, visit)
  local pending = queue or {}
  local head = 1
  while head <= #pending do
    local node = pending[head]
    head = head + 1
    visit(node, function(next_node)
      pending[#pending + 1] = next_node
    end)
  end
end

local function _manhattan_distance(a, b)
  return math.abs(a.row - b.row) + math.abs(a.col - b.col)
end

local function _collect_indices_by_distance(board, start_tile, max_dist)
  local by_dist = {}
  for idx, tile in ipairs(board.path or {}) do
    if idx ~= board:index_of_tile_id(start_tile.id) then
      local distance = _manhattan_distance(start_tile, tile)
      if distance > 0 and distance <= max_dist then
        by_dist[distance] = by_dist[distance] or {}
        table.insert(by_dist[distance], idx)
      end
    end
  end
  return by_dist
end

local function _flatten_by_distance(by_dist, max_dist)
  local list = {}
  for step = 1, max_dist do
    local entries = by_dist[step] or {}
    for _, idx in ipairs(entries) do
      table.insert(list, idx)
    end
  end
  return list
end

function board_query.indices_in_range(board, start, distance)
  assert(board ~= nil, "missing board")
  local start_tile = assert(board:get_tile(start), "missing start tile: " .. tostring(start))
  local max_dist = distance or 0
  if max_dist <= 0 then
    return {}
  end

  local by_dist = _collect_indices_by_distance(board, start_tile, max_dist)
  return _flatten_by_distance(by_dist, max_dist)
end

-- Export helpers for testability
board_query._manhattan_distance = _manhattan_distance
board_query._collect_indices_by_distance = _collect_indices_by_distance
board_query._flatten_by_distance = _flatten_by_distance

return board_query
