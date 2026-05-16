local direction = require("src.rules.board.direction")

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

local function _sort_by_distance_bucket(board, entries)
  table.sort(entries, function(left, right)
    local left_tile = board:get_tile(left)
    local right_tile = board:get_tile(right)
    if left_tile.id ~= right_tile.id then
      return left_tile.id < right_tile.id
    end
    return left < right
  end)
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
  for _, entries in pairs(by_dist) do
    _sort_by_distance_bucket(board, entries)
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

local ui_slot_count = 7
local center_slot = 4

local function _center_out_order(board, player, candidate_indices)
  assert(board ~= nil, "missing board")
  assert(player ~= nil, "missing player")
  local player_position = player.position
  assert(player_position ~= nil, "missing player.position")

  local start_tile = assert(board:get_tile(player_position), "missing start tile")
  local max_dist = 0
  local by_dist = {}
  local has_self = false

  for _, idx in ipairs(candidate_indices) do
    if idx == player_position then
      has_self = true
    else
      local tile = board:get_tile(idx)
      local dist = _manhattan_distance(start_tile, tile)
      if dist <= 0 then
        dist = 1
      end
      if dist > max_dist then
        max_dist = dist
      end
      by_dist[dist] = by_dist[dist] or {}
      table.insert(by_dist[dist], idx)
    end
  end

  local fwd = direction.collect_forward_indices(board, player, max_dist)
  local bwd = direction.collect_backward_indices(board, player, max_dist)

  local function classify(idx)
    if fwd.set[idx] then
      return "forward"
    end
    if bwd.set[idx] then
      return "backward"
    end
    local tile = board:get_tile(idx)
    if start_tile and tile then
      local dr = tile.row - start_tile.row
      local dc = tile.col - start_tile.col
      if math.abs(dr) > math.abs(dc) then
        return dr < 0 and "forward" or "backward"
      elseif math.abs(dc) > 0 then
        return dc > 0 and "forward" or "backward"
      end
    end
    return "forward"
  end

  local backward_queue = {}
  local forward_queue = {}

  for dist = 1, max_dist do
    for _, idx in ipairs(by_dist[dist] or {}) do
      local dir = classify(idx)
      if dir == "backward" then
        backward_queue[#backward_queue + 1] = idx
      else
        forward_queue[#forward_queue + 1] = idx
      end
    end
  end

  local slots = {}
  for i = 1, ui_slot_count do
    slots[i] = nil
  end

  if has_self then
    slots[center_slot] = player_position
  end

  local bi = 1
  for slot = center_slot - 1, 1, -1 do
    if backward_queue[bi] then
      slots[slot] = backward_queue[bi]
      bi = bi + 1
    end
  end

  local fi = 1
  for slot = center_slot + 1, ui_slot_count do
    if forward_queue[fi] then
      slots[slot] = forward_queue[fi]
      fi = fi + 1
    end
  end

  -- Overflow: if one side has fewer candidates, spill extras to the other side
  for slot = center_slot + 1, ui_slot_count do
    if slots[slot] == nil and backward_queue[bi] then
      slots[slot] = backward_queue[bi]
      bi = bi + 1
    end
  end
  for slot = center_slot - 1, 1, -1 do
    if slots[slot] == nil and forward_queue[fi] then
      slots[slot] = forward_queue[fi]
      fi = fi + 1
    end
  end

  return slots
end

function board_query.arrange_target_options(board, player, options)
  assert(board ~= nil, "missing board")
  assert(player ~= nil, "missing player")

  local index_by_id = {}
  local candidate_indices = {}
  for _, option in ipairs(options) do
    local id = type(option) == "table" and option.id or option
    if id ~= nil then
      candidate_indices[#candidate_indices + 1] = id
      index_by_id[id] = option
    end
  end

  local slots = _center_out_order(board, player, candidate_indices)

  local dense_options = {}
  local slot_layout = {}
  for i = 1, ui_slot_count do
    if slots[i] ~= nil then
      dense_options[#dense_options + 1] = index_by_id[slots[i]]
      slot_layout[#slot_layout + 1] = i
    end
  end
  return dense_options, slot_layout
end

-- Export helpers for testability
board_query._manhattan_distance = _manhattan_distance
board_query._collect_indices_by_distance = _collect_indices_by_distance
board_query._flatten_by_distance = _flatten_by_distance

return board_query
