local board_query = {}

local dir_order = { "up", "right", "down", "left" }

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

local function _bfs_collect_indices(board, neighbors, start_tile_id, max_dist)
  local dist_by_id = { [start_tile_id] = 0 }
  local queue = { start_tile_id }
  local qhead = 1
  local by_dist = {}

  while qhead <= #queue do
    local tile_id = queue[qhead]
    qhead = qhead + 1
    local dist = dist_by_id[tile_id] or 0
    if dist < max_dist then
      local neigh = assert(neighbors[tile_id], "missing neighbors: " .. tostring(tile_id))
      for _, dir in ipairs(dir_order) do
        local next_id = neigh[dir]
        if next_id and not dist_by_id[next_id] then
          local next_dist = dist + 1
          dist_by_id[next_id] = next_dist
          if next_dist <= max_dist then
            queue[#queue + 1] = next_id
            local idx = assert(board:index_of_tile_id(next_id), "missing tile index: " .. tostring(next_id))
            by_dist[next_dist] = by_dist[next_dist] or {}
            table.insert(by_dist[next_dist], idx)
          end
        end
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
  assert(board.map ~= nil, "missing board.map")
  local neighbors = assert(board.map.neighbors, "missing board.map.neighbors")
  local start_tile = assert(board:get_tile(start), "missing start tile: " .. tostring(start))
  local max_dist = distance or 0
  if max_dist <= 0 then
    return {}
  end

  local by_dist = _bfs_collect_indices(board, neighbors, start_tile.id, max_dist)
  return _flatten_by_distance(by_dist, max_dist)
end

-- Export helpers for testability
board_query._bfs_collect_indices = _bfs_collect_indices
board_query._flatten_by_distance = _flatten_by_distance

return board_query
