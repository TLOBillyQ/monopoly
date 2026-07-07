local target_layout = require("src.rules.board.target_layout")

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

board_query.arrange_target_options = target_layout.arrange_target_options

-- Export helpers for testability
board_query._manhattan_distance = _manhattan_distance
board_query._collect_indices_by_distance = _collect_indices_by_distance
board_query._flatten_by_distance = _flatten_by_distance

return board_query

--[[ mutate4lua-manifest
version=2
projectHash=0539119136c0ae7a
scope.0.id=chunk:src/rules/board/query.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=80
scope.0.semanticHash=81ade9bfde586ca5
scope.1.id=function:anonymous@11:11
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=13
scope.1.semanticHash=7710734b5ac60685
scope.2.id=function:_manhattan_distance:17
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=19
scope.2.semanticHash=0a50097a9188cf6a
scope.3.id=function:anonymous@22:22
scope.3.kind=function
scope.3.startLine=22
scope.3.endLine=29
scope.3.semanticHash=be8543385eb907d1
scope.4.id=function:_sort_by_distance_bucket:21
scope.4.kind=function
scope.4.startLine=21
scope.4.endLine=30
scope.4.semanticHash=ba2cbafa83a14ec4
scope.5.id=function:board_query.indices_in_range:60
scope.5.kind=function
scope.5.startLine=60
scope.5.endLine=70
scope.5.semanticHash=6415b6518c7bb1e1
]]
