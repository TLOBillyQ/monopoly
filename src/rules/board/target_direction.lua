local target_direction = {}

function target_direction.manhattan_distance(a, b)
  return math.abs(a.row - b.row) + math.abs(a.col - b.col)
end

local function _sign_direction(value)
  return value < 0 and "forward" or "backward"
end

local function _direction_from_geometry(start_tile, tile)
  local dr = tile.row - start_tile.row
  local dc = tile.col - start_tile.col
  if math.abs(dr) > math.abs(dc) then
    return _sign_direction(dr)
  elseif math.abs(dc) > 0 then
    return _sign_direction(dc)
  end
  return "forward"
end

local function _classify_by_direction(idx, fwd_set, bwd_set, start_tile, board)
  if fwd_set[idx] then return "forward" end
  if bwd_set[idx] then return "backward" end
  local tile = board:get_tile(idx)
  if start_tile == nil or tile == nil then return "forward" end
  return _direction_from_geometry(start_tile, tile)
end

function target_direction.build_queues(by_dist, max_dist, board, fwd, bwd, start_tile)
  local backward_queue = {}
  local forward_queue = {}
  for dist = 1, max_dist do
    for _, idx in ipairs(by_dist[dist] or {}) do
      if _classify_by_direction(idx, fwd.set, bwd.set, start_tile, board) == "backward" then
        backward_queue[#backward_queue + 1] = idx
      else
        forward_queue[#forward_queue + 1] = idx
      end
    end
  end
  return backward_queue, forward_queue
end

return target_direction

--[[ mutate4lua-manifest
version=2
projectHash=0d3db68af46435f1
scope.0.id=chunk:src/rules/board/target_direction.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=42
scope.0.semanticHash=56645c602858c3a4
scope.1.id=function:_sign_direction:3
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=5
scope.1.semanticHash=f62be3aa5b47b3f7
scope.2.id=function:_direction_from_geometry:7
scope.2.kind=function
scope.2.startLine=7
scope.2.endLine=16
scope.2.semanticHash=9956b328c6074c62
scope.3.id=function:_classify_by_direction:18
scope.3.kind=function
scope.3.startLine=18
scope.3.endLine=24
scope.3.semanticHash=acfa1d0f62f1ce03
]]
