local pricing = require("src.game.systems.land.land_pricing")

local board_utils = {}

local dir_order = { "up", "right", "down", "left" }

function board_utils.queue_walk(queue, visit)
  local q = queue or {}
  local head = 1
  while head <= #q do
    local node = q[head]
    head = head + 1
    visit(node, function(next_node)
      q[#q + 1] = next_node
    end)
  end
end

function board_utils.indices_in_range(board, start, distance)
  assert(board ~= nil, "missing board")
  assert(board.map ~= nil, "missing board.map")
  local neighbors = assert(board.map.neighbors, "missing board.map.neighbors")
  local start_tile = assert(board:get_tile(start), "missing start tile: " .. tostring(start))
  local max_dist = distance or 0
  if max_dist <= 0 then
    return {}
  end
  local dist_by_id = { [start_tile.id] = 0 }
  local queue = { start_tile.id }
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
        if next_id then
          if not dist_by_id[next_id] then
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
  end

  local list = {}
  for step = 1, max_dist do
    local entries = by_dist[step] or {}
    for _, idx in ipairs(entries) do
      table.insert(list, idx)
    end
  end
  return list
end

function board_utils.total_invested(tile, level)
  assert(tile ~= nil, "missing tile")
  return pricing.total_invested(tile, level or 0)
end

function board_utils.find_best_tile(game, player, distance, opts)
  local board = game.board
  assert(opts ~= nil, "missing opts")
  local allow_self = opts.allow_self
  local score_fn = assert(opts.score_fn, "missing score_fn")
  local best_idx = nil
  local best_value = nil
  local has_best = false

  local indices = board_utils.indices_in_range(board, player.position, distance or 3)
  if allow_self then
    table.insert(indices, 1, player.position)
  end

  for _, idx in ipairs(indices) do
    if allow_self or idx ~= player.position then
      local tile = board:get_tile(idx)
      local value = assert(score_fn(tile, idx), "missing score for tile: " .. tostring(idx))
      if has_best then
        if value > best_value then
          best_value = value
          best_idx = idx
        end
      else
        has_best = true
        best_value = value
        best_idx = idx
      end
    end
  end
  return best_idx, best_value
end

return board_utils
