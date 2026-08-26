local facing_policy = require("src.rules.board.facing_policy")
local direction_constants = require("src.rules.board.directions")
local tiles = require("src.rules.items.obstacle_clear_tiles")

local _get_sorted_forward_dirs = tiles.sorted_forward_dirs
local _copy_path = tiles.copy_path
local _visit_tile = tiles.visit_tile
local _next_strict_or_turn = tiles.next_strict_or_turn
local _resolve_initial_dirs = tiles.resolve_initial_dirs

local obstacle_clear_walk = {}

-- fork 场景复制路径,单支路直接复用同一路径。
local function _seed_path_for(is_fork, first_path)
  return is_fork and _copy_path(first_path) or first_path
end

local function _push_seed(stack, first_id, fdir, seed_path)
  stack[#stack + 1] = { id = first_id, facing = fdir, depth = 1, path = seed_path }
end

local function _push_branch_or_seed_to_stack(state, is_multi_start, stack, first_id, first_path, first_neigh, opposite, dir)
  if not first_neigh then
    state.branches[#state.branches + 1] = first_path
    return
  end
  local back_from_first = opposite[dir]
  local fork_dirs = _get_sorted_forward_dirs(first_neigh, back_from_first)
  if #fork_dirs == 0 then
    state.branches[#state.branches + 1] = first_path
    return
  end
  local is_fork = is_multi_start or #fork_dirs > 1
  for j = #fork_dirs, 1, -1 do
    _push_seed(stack, first_id, fork_dirs[j], _seed_path_for(is_fork, first_path))
  end
end

local function _seed_stack(game, board, state, start_neigh, initial_dirs, neighbors, opposite)
  local stack = {}
  local is_multi_start = #initial_dirs > 1
  for i = #initial_dirs, 1, -1 do
    local dir = initial_dirs[i]
    local first_id = start_neigh[dir]
    if first_id then
      local first_index = board:index_of_tile_id(first_id)
      if first_index then
        local first_had_obstacle = _visit_tile(game, board, state, first_id, first_index)
        local first_path = { { tile_index = first_index, has_obstacle = first_had_obstacle } }
        local first_neigh = neighbors[first_id]
        _push_branch_or_seed_to_stack(state, is_multi_start, stack, first_id, first_path, first_neigh, opposite, dir)
      end
    end
  end
  return stack
end

local function _push_stack_entry(stack, board, branching, frame, dir, next_id, next_index, had_obstacle)
  local entry = { tile_index = next_index, has_obstacle = had_obstacle }
  local new_path = branching and _copy_path(frame.path) or frame.path
  new_path[#new_path + 1] = entry
  stack[#stack + 1] = { id = next_id, facing = dir, depth = frame.depth + 1, path = new_path }
end

local function _resolve_frame_dirs(frame, state, neighbors, opposite)
  local neigh = frame.depth < state.distance and neighbors[frame.id] or nil
  local dirs = neigh and _next_strict_or_turn(neigh, frame.facing, opposite) or nil
  return neigh, dirs
end

local function _expand_frame_children(game, board, frame, state, dirs, neigh, stack)
  local branching = #dirs > 1
  for i = #dirs, 1, -1 do
    local dir = dirs[i]
    local next_id = neigh[dir]
    local next_index = next_id and board:index_of_tile_id(next_id) or nil
    if next_index then
      local had_obstacle = _visit_tile(game, board, state, next_id, next_index)
      _push_stack_entry(stack, board, branching, frame, dir, next_id, next_index, had_obstacle)
    else
      state.branches[#state.branches + 1] = frame.path
    end
  end
end

local function _process_stack_frame(game, board, frame, state, neighbors, opposite, stack)
  local neigh, dirs = _resolve_frame_dirs(frame, state, neighbors, opposite)
  if not dirs or #dirs == 0 then
    state.branches[#state.branches + 1] = frame.path
    return
  end
  _expand_frame_children(game, board, frame, state, dirs, neigh, stack)
end

function obstacle_clear_walk.walk_and_clear(game, player, board, state, context)
  local map = assert(board.map, "missing board.map")
  local neighbors = assert(map.neighbors, "missing board.map.neighbors")
  local opposite = direction_constants.opposite

  local facing = facing_policy.resolve_initial_facing("relative_forward", player, context)
  local start_tile = assert(board:get_tile(player.position), "missing start tile")
  local start_id = assert(start_tile.id, "missing start tile id")

  local start_neigh = neighbors[start_id]
  if not start_neigh then
    return
  end

  local initial_dirs = _resolve_initial_dirs(start_neigh, facing)
  if #initial_dirs == 0 then
    return
  end

  local stack = _seed_stack(game, board, state, start_neigh, initial_dirs, neighbors, opposite)

  while #stack > 0 do
    local frame = stack[#stack]
    stack[#stack] = nil
    _process_stack_frame(game, board, frame, state, neighbors, opposite, stack)
  end
end

return obstacle_clear_walk

--[[ mutate4lua-manifest
version=4
projectHash=c84ff6680cefbb5e
scope.0.id=chunk:src/rules/items/obstacle_clear_walk.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=117
scope.0.semanticHash=57118d0479795aed
scope.1.id=function:_push_branch_or_seed_to_stack
scope.1.kind=function
scope.1.startLine=13
scope.1.endLine=30
scope.1.semanticHash=45400b50bf101361
scope.2.id=function:_seed_stack
scope.2.kind=function
scope.2.startLine=32
scope.2.endLine=49
scope.2.semanticHash=5393ff1cdb8d16cc
scope.3.id=function:_push_stack_entry
scope.3.kind=function
scope.3.startLine=51
scope.3.endLine=56
scope.3.semanticHash=2d0c9ea5ea0ccf6b
scope.4.id=function:_resolve_frame_dirs
scope.4.kind=function
scope.4.startLine=58
scope.4.endLine=62
scope.4.semanticHash=5c61acc0ff514ecf
scope.5.id=function:_expand_frame_children
scope.5.kind=function
scope.5.startLine=64
scope.5.endLine=77
scope.5.semanticHash=4482f23ce2b89ae5
scope.6.id=function:_process_stack_frame
scope.6.kind=function
scope.6.startLine=79
scope.6.endLine=86
scope.6.semanticHash=70761fbccb3a392b
scope.7.id=function:obstacle_clear_walk.walk_and_clear
scope.7.kind=function
scope.7.startLine=88
scope.7.endLine=114
scope.7.semanticHash=34d75d03a6129e6a
]]
