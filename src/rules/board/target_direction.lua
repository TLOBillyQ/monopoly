local target_direction = {}

function target_direction.manhattan_distance(a, b)
  return math.abs(a.row - b.row) + math.abs(a.col - b.col)
end

-- Direction is a boolean decision: a tile is either behind the target
-- (backward) or everything else falls into the forward queue. Co-located
-- tiles (zero delta on both axes) count as forward.
local function _geometry_is_backward(start_tile, tile)
  local dr = tile.row - start_tile.row
  local dc = tile.col - start_tile.col
  local dominant = math.abs(dr) > math.abs(dc) and dr or dc
  return dominant >= 0 and (dr ~= 0 or dc ~= 0)
end

local function _is_backward(idx, fwd_set, bwd_set, start_tile, board)
  if fwd_set[idx] then return false end
  if bwd_set[idx] then return true end
  local tile = board:get_tile(idx)
  if start_tile == nil or tile == nil then return false end
  return _geometry_is_backward(start_tile, tile)
end

function target_direction.build_queues(by_dist, max_dist, board, fwd, bwd, start_tile)
  local backward_queue = {}
  local forward_queue = {}
  for dist = 1, max_dist do
    for _, idx in ipairs(by_dist[dist] or {}) do
      if _is_backward(idx, fwd.set, bwd.set, start_tile, board) then
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
projectHash=f29265f8606f8cfa
scope.0.id=chunk:src/rules/board/target_direction.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=41
scope.0.semanticHash=f66ddd7e91cdb790
scope.0.lastMutatedAt=2026-07-07T02:52:38Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=7
scope.0.lastMutationKilled=7
scope.1.id=function:target_direction.manhattan_distance:3
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=5
scope.1.semanticHash=50a1b27b90585294
scope.1.lastMutatedAt=2026-07-07T02:52:38Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=3
scope.1.lastMutationKilled=3
scope.2.id=function:_geometry_is_backward:10
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=15
scope.2.semanticHash=b645f574f49837fc
scope.2.lastMutatedAt=2026-07-07T02:52:38Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=survived
scope.2.lastMutationSites=15
scope.2.lastMutationKilled=13
scope.3.id=function:_is_backward:17
scope.3.kind=function
scope.3.startLine=17
scope.3.endLine=23
scope.3.semanticHash=35ed61c9087f5194
scope.3.lastMutatedAt=2026-07-07T02:52:38Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=8
scope.3.lastMutationKilled=8
]]
