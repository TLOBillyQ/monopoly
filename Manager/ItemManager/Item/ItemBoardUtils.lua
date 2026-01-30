local Pricing = require("Manager.LandManager.Land.LandPricing")

local BoardUtils = {}

local DIR_ORDER = { "up", "right", "down", "left" }

function BoardUtils.queue_walk(queue, visit)
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

function BoardUtils.indices_in_range(board, start, distance)
  local map = board and board.map
  local neighbors = map and map.neighbors
  if neighbors then
    local start_tile = board:get_tile(start)
    if not start_tile then
      return {}
    end
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
        local neigh = neighbors[tile_id] or {}
        for _, dir in ipairs(DIR_ORDER) do
          local next_id = neigh[dir]
          if next_id and dist_by_id[next_id] == nil then
            local next_dist = dist + 1
            dist_by_id[next_id] = next_dist
            if next_dist <= max_dist then
              queue[#queue + 1] = next_id
              local idx = board:index_of_tile_id(next_id)
              if idx then
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

  local len = board:length()
  local seen = {}
  local list = {}
  for step = 1, distance do
    local forward = start + step
    if forward > len then
      forward = forward - len
    end
    if not seen[forward] then
      table.insert(list, forward)
      seen[forward] = true
    end

    local back = start - step
    if back < 1 then
      back = len + back
    end
    if not seen[back] then
      table.insert(list, back)
      seen[back] = true
    end
  end
  return list
end

function BoardUtils.total_invested(tile, level)
  if not tile then
    return 0
  end
  return Pricing.total_invested(tile, level or 0)
end

function BoardUtils.find_best_tile(game, player, distance, opts)
  local board = game.board
  local allow_self = opts and opts.allow_self
  local score_fn = opts and opts.score_fn
  local best_idx = nil
  local best_value = nil

  local indices = BoardUtils.indices_in_range(board, player.position, distance or 3)
  if allow_self then
    table.insert(indices, 1, player.position)
  end

  for _, idx in ipairs(indices) do
    if allow_self or idx ~= player.position then
      local tile = board:get_tile(idx)
      local value = score_fn and score_fn(tile, idx)
      if value ~= nil and (best_value == nil or value > best_value) then
        best_value = value
        best_idx = idx
      end
    end
  end
  return best_idx, best_value
end

return BoardUtils
