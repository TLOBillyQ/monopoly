local Pricing = require("Manager.LandManager.LandPricing")

local BoardUtils = {}

local DIR_ORDER = { "up", "right", "down", "left" }

function BoardUtils.QueueWalk(queue, visit)
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

function BoardUtils.IndicesInRange(board, start, distance)
  assert(board ~= nil, "missing board")
  assert(board.map ~= nil, "missing board.map")
  local neighbors = assert(board.map.neighbors, "missing board.map.neighbors")
  local start_tile = assert(board:GetTile(start), "missing start tile: " .. tostring(start))
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
      for _, dir in ipairs(DIR_ORDER) do
        local next_id = neigh[dir]
        if next_id then
          if dist_by_id[next_id] then
          else
            local next_dist = dist + 1
            dist_by_id[next_id] = next_dist
            if next_dist <= max_dist then
              queue[#queue + 1] = next_id
              local idx = assert(board:IndexOfTileId(next_id), "missing tile index: " .. tostring(next_id))
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

function BoardUtils.TotalInvested(tile, level)
  assert(tile ~= nil, "missing tile")
  return Pricing.TotalInvested(tile, level or 0)
end

function BoardUtils.FindBestTile(game, player, distance, opts)
  local board = game.board
  assert(opts ~= nil, "missing opts")
  local allow_self = opts.allow_self
  local score_fn = assert(opts.score_fn, "missing score_fn")
  local best_idx = nil
  local best_value = nil
  local has_best = false

  local indices = BoardUtils.IndicesInRange(board, player.position, distance or 3)
  if allow_self then
    table.insert(indices, 1, player.position)
  end

  for _, idx in ipairs(indices) do
    if allow_self or idx ~= player.position then
      local tile = board:GetTile(idx)
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

return BoardUtils
