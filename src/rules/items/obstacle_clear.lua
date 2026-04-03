local logger = require("src.core.utils.logger")
local action_anim_port = require("src.core.ports.action_anim")
local facing_policy = require("src.rules.board.facing_policy")
local direction_constants = require("src.rules.board.directions")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local timing = require("src.config.gameplay.timing")

local obstacle_clear = {}
local action_anim_duration = timing.action_anim_default_seconds or 1.0

local function _new_state(distance, context)
  assert(context ~= nil, "missing context")
  return {
    cleared = 0,
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

local function _visit_tile(game, board, state, tile_id, tile_index)
  if not state.obstacle_snapshot[tile_id] then
    local had_rb = board:has_roadblock(tile_index)
    local had_mine = board:has_mine(tile_index)
    local had = had_rb or had_mine
    state.obstacle_snapshot[tile_id] = had and "yes" or "no"
    if not state.cleared_map[tile_index] then
      if had_rb then
        game:clear_roadblock(tile_index)
        state.cleared_map[tile_index] = true
        state.cleared = state.cleared + 1
      end
      if had_mine then
        game:clear_mine(tile_index)
        state.cleared_map[tile_index] = true
        state.cleared = state.cleared + 1
      end
    end
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
  local fwd = start_neigh[facing]
  return fwd and { facing } or {}
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
        if not first_neigh then
          state.branches[#state.branches + 1] = first_path
        else
          local back_from_first = opposite[dir]
          local fork_dirs = _get_sorted_forward_dirs(first_neigh, back_from_first)
          if #fork_dirs == 0 then
            state.branches[#state.branches + 1] = first_path
          else
            local is_fork = is_multi_start or #fork_dirs > 1
            for j = #fork_dirs, 1, -1 do
              local fdir = fork_dirs[j]
              local seed_path = is_fork and _copy_path(first_path) or first_path
              stack[#stack + 1] = { id = first_id, facing = fdir, depth = 1, path = seed_path }
            end
          end
        end
      end
    end
  end
  return stack
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

    if frame.depth >= state.distance then
      state.branches[#state.branches + 1] = frame.path
    else
      local neigh = neighbors[frame.id]
      if not neigh then
        state.branches[#state.branches + 1] = frame.path
      else
        local dirs = _next_strict_or_turn(neigh, frame.facing, opposite)
        if #dirs == 0 then
          state.branches[#state.branches + 1] = frame.path
        else
          local branching = #dirs > 1
          for i = #dirs, 1, -1 do
            local dir = dirs[i]
            local next_id = neigh[dir]
            local next_index = next_id and board:index_of_tile_id(next_id) or nil
            if next_index then
              local had_obstacle = _visit_tile(game, board, state, next_id, next_index)
              local entry = { tile_index = next_index, has_obstacle = had_obstacle }
              local new_path = branching and _copy_path(frame.path) or frame.path
              new_path[#new_path + 1] = entry
              stack[#stack + 1] = { id = next_id, facing = dir, depth = frame.depth + 1, path = new_path }
            else
              state.branches[#state.branches + 1] = frame.path
            end
          end
        end
      end
    end
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
    logger.event(player.name .. " 清除前方障碍数：" .. state.cleared)
  end
  return _queue_anim(game, player, state)
end

return obstacle_clear
