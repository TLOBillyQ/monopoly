local direction = require("src.rules.board.direction")
local target_direction = require("src.rules.board.target_direction")

local target_layout = {}

local ui_slot_count = 7
local center_slot = 4

local function _manhattan_distance(a, b)
  return math.abs(a.row - b.row) + math.abs(a.col - b.col)
end

local function _max_key(t)
  local max = 0
  for k in pairs(t) do
    if k > max then max = k end
  end
  return max
end

local function _build_candidate_map(board, player_position, candidate_indices, start_tile)
  local by_dist = {}
  local has_self = false
  for _, idx in ipairs(candidate_indices) do
    if idx == player_position then
      has_self = true
    else
      local tile = board:get_tile(idx)
      local dist = _manhattan_distance(start_tile, tile)
      if dist <= 0 then dist = 1 end
      by_dist[dist] = by_dist[dist] or {}
      table.insert(by_dist[dist], idx)
    end
  end
  return by_dist, _max_key(by_dist), has_self
end

local function _make_slots(has_self, player_position)
  local slots = {}
  for i = 1, ui_slot_count do slots[i] = nil end
  if has_self then slots[center_slot] = player_position end
  return slots
end

local function _fill_primary_slots(slots, backward_queue, forward_queue)
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
  return bi, fi
end

local function _fill_overflow_fwd(slots, queue, qi)
  for slot = center_slot + 1, ui_slot_count do
    if slots[slot] == nil and queue[qi] then
      slots[slot] = queue[qi]
      qi = qi + 1
    end
  end
end

local function _fill_overflow_bwd(slots, queue, qi)
  for slot = center_slot - 1, 1, -1 do
    if slots[slot] == nil and queue[qi] then
      slots[slot] = queue[qi]
      qi = qi + 1
    end
  end
end

local function _center_out_order(board, player, candidate_indices)
  assert(board ~= nil, "missing board")
  assert(player ~= nil, "missing player")
  local player_position = player.position
  assert(player_position ~= nil, "missing player.position")

  local start_tile = assert(board:get_tile(player_position), "missing start tile")
  local by_dist, max_dist, has_self = _build_candidate_map(board, player_position, candidate_indices, start_tile)

  local fwd = direction.collect_forward_indices(board, player, max_dist)
  local bwd = direction.collect_backward_indices(board, player, max_dist)
  local backward_queue, forward_queue = target_direction.build_queues(by_dist, max_dist, board, fwd, bwd, start_tile)

  local slots = _make_slots(has_self, player_position)
  local bi, fi = _fill_primary_slots(slots, backward_queue, forward_queue)
  _fill_overflow_fwd(slots, backward_queue, bi)
  _fill_overflow_bwd(slots, forward_queue, fi)

  return slots
end

local function _extract_candidates(options)
  local index_by_id = {}
  local candidate_indices = {}
  for _, option in ipairs(options) do
    local id = type(option) == "table" and option.id or option
    if id ~= nil then
      candidate_indices[#candidate_indices + 1] = id
      index_by_id[id] = option
    end
  end
  return candidate_indices, index_by_id
end

local function _densify_slots(slots, index_by_id)
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

function target_layout.arrange_target_options(board, player, options)
  assert(board ~= nil, "missing board")
  assert(player ~= nil, "missing player")

  local candidate_indices, index_by_id = _extract_candidates(options)
  local slots = _center_out_order(board, player, candidate_indices)
  return _densify_slots(slots, index_by_id)
end

return target_layout

--[[ mutate4lua-manifest
version=2
projectHash=b1046bb87edfaaf8
scope.0.id=chunk:src/rules/board/target_layout.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=137
scope.0.semanticHash=3d8efc4ff5c6f947
scope.1.id=function:_manhattan_distance:9
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=11
scope.1.semanticHash=0a50097a9188cf6a
scope.2.id=function:_center_out_order:81
scope.2.kind=function
scope.2.startLine=81
scope.2.endLine=100
scope.2.semanticHash=a35de4fbf1a1d9a9
scope.3.id=function:target_layout.arrange_target_options:127
scope.3.kind=function
scope.3.startLine=127
scope.3.endLine=134
scope.3.semanticHash=361120203f7c5063
]]
