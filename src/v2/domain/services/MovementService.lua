local common = require("src.v2.domain.services.Common")

local movement_service = {}

local opposite = {
  up = "down",
  down = "up",
  left = "right",
  right = "left",
}

local function _tile_id(state, index)
  return state.board.path[index]
end

local function _index_of(state, tile_id)
  return state.board.index_by_tile_id[tile_id]
end

local function _pick_any_dir(neigh, avoid_dir)
  for dir, next_id in pairs(neigh or {}) do
    if dir ~= avoid_dir then
      return dir, next_id
    end
  end
  return nil, nil
end

local function _step_forward(state, current_index, facing, parity)
  local map = state.board.map
  local current_id = _tile_id(state, current_index)
  local neigh = map.neighbors[current_id] or {}

  local next_id = nil

  if map.outer_next[current_id] then
    local entry = map.entry_points[current_id]
    if entry and parity and (parity % 2 == 0) and facing then
      local prev_id = map.outer_prev[current_id]
      local required_facing = map.direction and map.direction(prev_id, current_id) or nil
      if required_facing == facing then
        next_id = entry.inner_id
      end
    end
    if not next_id then
      next_id = map.outer_next[current_id]
    end
  elseif current_id == map.market_id and facing and parity then
    local exit_dir = map.turn_right and map.turn_right[facing] or nil
    if parity % 2 == 1 then
      exit_dir = map.turn_left and map.turn_left[facing] or exit_dir
    end
    if exit_dir then
      next_id = neigh[exit_dir]
    end
    if not next_id then
      next_id = neigh[facing]
    end
  else
    if facing and neigh[facing] then
      next_id = neigh[facing]
    else
      local back_dir = opposite[facing]
      local _, candidate = _pick_any_dir(neigh, back_dir)
      next_id = candidate
      if not next_id then
        local _, any_id = _pick_any_dir(neigh, nil)
        next_id = any_id
      end
    end
  end

  local next_index = _index_of(state, next_id)
  local passed_start = 0
  if next_id == map.start_id then
    passed_start = 1
  end
  local step_dir = map.direction and map.direction(current_id, next_id) or facing
  return next_index, passed_start, step_dir
end

local function _step_backward(state, current_index, facing)
  local map = state.board.map
  local current_id = _tile_id(state, current_index)
  local neigh = map.neighbors[current_id] or {}

  local next_id = nil
  if facing then
    local back_dir = opposite[facing]
    if back_dir and neigh[back_dir] then
      next_id = neigh[back_dir]
    end
  end

  if not next_id and map.outer_prev[current_id] then
    next_id = map.outer_prev[current_id]
  end

  if not next_id and facing then
    local _, candidate = _pick_any_dir(neigh, facing)
    next_id = candidate
  end

  if not next_id then
    local _, any_id = _pick_any_dir(neigh, nil)
    next_id = any_id
  end

  local next_index = _index_of(state, next_id)
  local passed_start = 0
  if next_id == map.start_id then
    passed_start = 1
  end
  local step_dir = map.direction and map.direction(current_id, next_id) or facing
  return next_index, passed_start, step_dir
end

local function _players_on_index(state, index, self_seat)
  local list = {}
  for seat, player in ipairs(state.players) do
    if seat ~= self_seat and (not player.eliminated) and player.position == index then
      list[#list + 1] = seat
    end
  end
  return list
end

function movement_service.indices_in_range(state, origin_index, distance)
  local result = {}
  local seen = {}
  local origin = origin_index
  for step = 1, distance do
    local forward, _, _ = _step_forward(state, origin, nil, 1)
    origin = forward
    if forward and not seen[forward] then
      seen[forward] = true
      result[#result + 1] = forward
    end
  end
  origin = origin_index
  for _ = 1, distance do
    local backward, _, _ = _step_backward(state, origin, nil)
    origin = backward
    if backward and not seen[backward] then
      seen[backward] = true
      result[#result + 1] = backward
    end
  end
  return result
end

function movement_service.move(state, seat, steps, opts)
  opts = opts or {}
  local player = state.players[seat]
  if not player then
    return nil
  end

  local abs_steps = steps < 0 and -steps or steps
  local branch_parity = opts.branch_parity or abs_steps
  local encountered = {}
  local visited = {}
  local pass_start = 0
  local stopped_on_roadblock = false
  local market_interrupt = nil
  local steal_interrupt = nil
  local current = player.position
  local facing = opts.direction or player.move_dir
  local backward = steps < 0

  for step = 1, abs_steps do
    local next_index, passed, step_dir
    if backward then
      next_index, passed, step_dir = _step_backward(state, current, facing)
    else
      next_index, passed, step_dir = _step_forward(state, current, facing, branch_parity)
    end
    current = next_index
    pass_start = pass_start + (passed or 0)
    facing = step_dir or facing
    visited[#visited + 1] = current

    local encountered_step = _players_on_index(state, current, seat)
    for _, other_seat in ipairs(encountered_step) do
      encountered[#encountered + 1] = other_seat
    end

    if state.board.overlays.roadblocks[current] then
      stopped_on_roadblock = true
      break
    end

    if (not opts.skip_steal_check) and #encountered_step > 0 and common.has_item(player, common.item_ids.steal) then
      local remaining = abs_steps - step
      if remaining > 0 then
        steal_interrupt = {
          position = current,
          remaining_steps = remaining,
          facing = facing,
          branch_parity = branch_parity,
          encountered_ids = encountered_step,
        }
        break
      end
    end

    if (not backward) and (not opts.skip_market_check) then
      local tile_id = _tile_id(state, current)
      local tile = state.board.tile_defs[tile_id]
      if tile and tile.type == "market" and step < abs_steps then
        market_interrupt = {
          position = current,
          remaining_steps = abs_steps - step,
          facing = facing,
          branch_parity = branch_parity,
        }
        break
      end
    end
  end

  return {
    from_index = player.position,
    to_index = current,
    steps = steps,
    visited = visited,
    encountered_players = encountered,
    passed_start = pass_start,
    stopped_on_roadblock = stopped_on_roadblock,
    market_interrupt = market_interrupt,
    steal_interrupt = steal_interrupt,
    facing = facing,
    branch_parity = branch_parity,
  }
end

return movement_service
