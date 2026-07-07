local direction_constants = require("src.rules.board.directions")

local obstacle_clear_tiles = {}

function obstacle_clear_tiles.sorted_forward_dirs(neigh, back_dir)
  local dirs = {}
  for dir, _ in pairs(neigh) do
    if dir ~= back_dir then
      dirs[#dirs + 1] = dir
    end
  end
  table.sort(dirs)
  return dirs
end

function obstacle_clear_tiles.copy_path(src)
  local dst = {}
  for i = 1, #src do
    dst[i] = src[i]
  end
  return dst
end

local function _clear_obstacles_on_tile(game, state, tile_index, had_rb, had_mine)
  if state.cleared_map[tile_index] then return end
  if had_rb then
    game:clear_roadblock(tile_index)
    state.roadblock_cleared = state.roadblock_cleared + 1
  end
  if had_mine then
    game:clear_mine(tile_index)
    state.mine_cleared = state.mine_cleared + 1
  end
  if had_rb or had_mine then
    state.cleared_map[tile_index] = true
    state.cleared = state.cleared + 1
  end
end

function obstacle_clear_tiles.visit_tile(game, board, state, tile_id, tile_index)
  if not state.obstacle_snapshot[tile_id] then
    local had_rb = board:has_roadblock(tile_index)
    local had_mine = board:has_mine(tile_index)
    state.obstacle_snapshot[tile_id] = (had_rb or had_mine) and "yes" or "no"
    _clear_obstacles_on_tile(game, state, tile_index, had_rb, had_mine)
  end
  return state.obstacle_snapshot[tile_id] == "yes"
end

function obstacle_clear_tiles.next_strict_or_turn(neigh, facing, opposite)
  if neigh[facing] then
    return { facing }
  end
  local back_dir = opposite[facing]
  return obstacle_clear_tiles.sorted_forward_dirs(neigh, back_dir)
end

function obstacle_clear_tiles.resolve_initial_dirs(start_neigh, facing)
  if facing == nil then
    return obstacle_clear_tiles.sorted_forward_dirs(start_neigh, nil)
  end
  if start_neigh[facing] then
    return { facing }
  end
  local back_dir = direction_constants.opposite[facing]
  return obstacle_clear_tiles.sorted_forward_dirs(start_neigh, back_dir)
end

return obstacle_clear_tiles

--[[ mutate4lua-manifest
version=2
projectHash=ebb8cb067b21bcdd
scope.0.id=chunk:src/rules/items/obstacle_clear_tiles.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=70
scope.0.semanticHash=81463e1648bb321e
scope.0.lastMutatedAt=2026-07-07T02:44:15Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=survived
scope.0.lastMutationSites=7
scope.0.lastMutationKilled=6
scope.1.id=function:_clear_obstacles_on_tile:24
scope.1.kind=function
scope.1.startLine=24
scope.1.endLine=38
scope.1.semanticHash=007a20be387c45af
scope.1.lastMutatedAt=2026-07-07T02:44:15Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=survived
scope.1.lastMutationSites=10
scope.1.lastMutationKilled=9
scope.2.id=function:obstacle_clear_tiles.visit_tile:40
scope.2.kind=function
scope.2.startLine=40
scope.2.endLine=48
scope.2.semanticHash=a492fc28fe4bf5e5
scope.2.lastMutatedAt=2026-07-07T02:44:15Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=survived
scope.2.lastMutationSites=11
scope.2.lastMutationKilled=10
scope.3.id=function:obstacle_clear_tiles.next_strict_or_turn:50
scope.3.kind=function
scope.3.startLine=50
scope.3.endLine=56
scope.3.semanticHash=50c7020630b86d0d
scope.3.lastMutatedAt=2026-07-07T02:44:15Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=1
scope.3.lastMutationKilled=1
scope.4.id=function:obstacle_clear_tiles.resolve_initial_dirs:58
scope.4.kind=function
scope.4.startLine=58
scope.4.endLine=67
scope.4.semanticHash=808ad68feaa51ed4
scope.4.lastMutatedAt=2026-07-07T02:44:15Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=3
scope.4.lastMutationKilled=3
]]
