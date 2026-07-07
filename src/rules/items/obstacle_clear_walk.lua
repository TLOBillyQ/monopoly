local facing_policy = require("src.rules.board.facing_policy")
local direction_constants = require("src.rules.board.directions")
local tiles = require("src.rules.items.obstacle_clear_tiles")

local _get_sorted_forward_dirs = tiles.sorted_forward_dirs
local _copy_path = tiles.copy_path
local _visit_tile = tiles.visit_tile
local _next_strict_or_turn = tiles.next_strict_or_turn
local _resolve_initial_dirs = tiles.resolve_initial_dirs

local obstacle_clear_walk = {}

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
    local fdir = fork_dirs[j]
    local seed_path = is_fork and _copy_path(first_path) or first_path
    stack[#stack + 1] = { id = first_id, facing = fdir, depth = 1, path = seed_path }
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
version=2
projectHash=1e0c35036da91a31
scope.0.id=chunk:src/rules/items/obstacle_clear_walk.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=117
scope.0.semanticHash=0e8638044bbcc41e
scope.1.id=function:_push_stack_entry:51
scope.1.kind=function
scope.1.startLine=51
scope.1.endLine=56
scope.1.semanticHash=5a4e234599a32246
scope.2.id=function:_resolve_frame_dirs:58
scope.2.kind=function
scope.2.startLine=58
scope.2.endLine=62
scope.2.semanticHash=0f72fede3f6d560b
scope.3.id=function:_process_stack_frame:79
scope.3.kind=function
scope.3.startLine=79
scope.3.endLine=86
scope.3.semanticHash=9382f19b4b0315a1
]]
