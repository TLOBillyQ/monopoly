local event_kinds = require("src.config.gameplay.event_kinds")
local action_anim_port = require("src.foundation.ports.action_anim")
local facing_policy = require("src.rules.board.facing_policy")
local direction_constants = require("src.rules.board.directions")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local timing = require("src.config.gameplay.timing")
local event_feed = require("src.rules.ports.event_feed")

local obstacle_clear = {}
local action_anim_duration = timing.action_anim_default_seconds or 1.0

local function _new_state(distance, context)
  assert(context ~= nil, "missing context")
  return {
    cleared = 0,
    roadblock_cleared = 0,
    mine_cleared = 0,
    cleared_map = {},
    obstacle_snapshot = {},
    branches = {},
    distance = distance,
    parity = context.branch_parity or distance,
  }
end

local function _get_sorted_forward_dirs(neigh, back_dir)
  local dirs = {}
  for dir, _ in pairs(neigh) do
    if dir ~= back_dir then
      dirs[#dirs + 1] = dir
    end
  end
  table.sort(dirs)
  return dirs
end

local function _copy_path(src)
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

local function _visit_tile(game, board, state, tile_id, tile_index)
  if not state.obstacle_snapshot[tile_id] then
    local had_rb = board:has_roadblock(tile_index)
    local had_mine = board:has_mine(tile_index)
    state.obstacle_snapshot[tile_id] = (had_rb or had_mine) and "yes" or "no"
    _clear_obstacles_on_tile(game, state, tile_index, had_rb, had_mine)
  end
  return state.obstacle_snapshot[tile_id] == "yes"
end

local function _next_strict_or_turn(neigh, facing, opposite)
  if neigh[facing] then
    return { facing }
  end
  local back_dir = opposite[facing]
  return _get_sorted_forward_dirs(neigh, back_dir)
end

local function _resolve_initial_dirs(start_neigh, facing)
  if facing == nil then
    return _get_sorted_forward_dirs(start_neigh, nil)
  end
  if start_neigh[facing] then
    return { facing }
  end
  local back_dir = direction_constants.opposite[facing]
  return _get_sorted_forward_dirs(start_neigh, back_dir)
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

local function _process_stack_frame(game, board, frame, state, neighbors, opposite, stack)
  local neigh = frame.depth < state.distance and neighbors[frame.id] or nil
  local dirs = neigh and _next_strict_or_turn(neigh, frame.facing, opposite) or nil
  if not dirs or #dirs == 0 then
    state.branches[#state.branches + 1] = frame.path
    return
  end
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

local function _walk_and_clear(game, player, board, state, context)
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

local function _queue_anim(game, player, state)
  local longest = 0
  for _, branch in ipairs(state.branches) do
    if #branch > longest then
      longest = #branch
    end
  end
  local step_time = 3.0 / runtime_constants.robot_speed
  local duration = longest * step_time
  if duration <= 0 then
    duration = action_anim_duration
  end

  local queued = action_anim_port.queue(game, {
    kind = "clear_obstacles",
    player_id = player.id,
    branches = state.branches,
    roadblock_cleared = state.roadblock_cleared,
    mine_cleared = state.mine_cleared,
    duration = duration,
  })
  if queued then
    return { ok = true, action_anim = true }
  end
  return true
end

function obstacle_clear.handle(game, player, cfg, context)
  local board = game.board
  local distance = cfg.distance or 12
  local state = _new_state(distance, context)
  _walk_and_clear(game, player, board, state, context)
  if state.cleared > 0 then
    event_feed.publish(game, {
      kind = event_kinds.obstacle_cleared,
      text = player.name .. " 清除前方障碍数：" .. state.cleared,
    })
  end
  return _queue_anim(game, player, state)
end

return obstacle_clear

--[[ mutate4lua-manifest
version=2
projectHash=fd2885e99d5e77da
scope.0.id=chunk:src/rules/items/obstacle_clear.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=228
scope.0.semanticHash=b529e467dc0a9ed5
scope.1.id=function:_new_state:12
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=24
scope.1.semanticHash=b1ea513c15726e16
scope.2.id=function:_visit_tile:45
scope.2.kind=function
scope.2.startLine=45
scope.2.endLine=67
scope.2.semanticHash=807f686cff974292
scope.3.id=function:_next_strict_or_turn:69
scope.3.kind=function
scope.3.startLine=69
scope.3.endLine=75
scope.3.semanticHash=e180e0b804dbaf5c
scope.4.id=function:_resolve_initial_dirs:77
scope.4.kind=function
scope.4.startLine=77
scope.4.endLine=86
scope.4.semanticHash=160d9471751909b4
scope.5.id=function:obstacle_clear.handle:213
scope.5.kind=function
scope.5.startLine=213
scope.5.endLine=225
scope.5.semanticHash=18c96fe3b0acd1d9
]]
