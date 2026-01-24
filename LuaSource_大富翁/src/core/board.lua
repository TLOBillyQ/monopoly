local Board = {}
Board.__index = Board

function Board.new(data)
  local tile_lookup = data.tile_lookup
  local path = data.path

  local index_by_id = {}
  for idx, tile in ipairs(path) do
    index_by_id[tile.id] = idx
  end

  local b = {
    path = path,
    tile_lookup = tile_lookup,
    branches = data.branches,
    index_by_id = index_by_id,
    map = data.map,
    overlays = data.overlays,
  }
  return setmetatable(b, Board)
end

function Board:length()
  return #self.path
end

function Board:index_of_tile_id(id)
  return self.index_by_id[id]
end

function Board:get_tile(index)
  return self.path[index]
end

function Board:get_tile_by_id(id)
  return self.tile_lookup[id]
end

function Board:find_first_by_type(tile_type)
  for idx, tile in ipairs(self.path) do
    if tile.type == tile_type then
      return idx, tile
    end
  end
  return nil, nil
end

function Board:get_overlays()
  return self.overlays
end

function Board:place_roadblock(index)
  self.overlays.roadblocks = self.overlays.roadblocks or {}
  self.overlays.roadblocks[index] = true
end

function Board:has_roadblock(index)
  return self.overlays.roadblocks and self.overlays.roadblocks[index] ~= nil
end

function Board:clear_roadblock(index)
  if self.overlays.roadblocks then
    self.overlays.roadblocks[index] = nil
  end
end

function Board:place_mine(index)
  self.overlays.mines = self.overlays.mines or {}
  self.overlays.mines[index] = true
end

function Board:has_mine(index)
  return self.overlays.mines and self.overlays.mines[index] ~= nil
end

function Board:clear_mine(index)
  if self.overlays.mines then
    self.overlays.mines[index] = nil
  end
end

function Board:clear_all(index)
  self:clear_roadblock(index)
  self:clear_mine(index)
end


function Board:advance(index, steps, branch_parity)
  local length = self:length()
  if length == 0 then
    return index, 0
  end
  local current = index
  local passed_start = 0
  for _ = 1, steps do
    local branch = self.branches[current]
    if branch and branch_parity then
      if branch_parity % 2 == 1 then
        current = branch.odd
      else
        current = branch.even
      end
    else
      current = current + 1
    end
    if current > length then
      current = current - length
      passed_start = passed_start + 1
    end
  end
  return current, passed_start
end

local DIR_ORDER = { "up", "right", "down", "left" }
local OPPOSITE = { up = "down", down = "up", left = "right", right = "left" }

local function pick_any_dir(neigh, blocked_dir)
  for _, d in ipairs(DIR_ORDER) do
    if (not blocked_dir) or d ~= blocked_dir then
      local nid = neigh[d]
      if nid then
        return d, nid
      end
    end
  end
  return nil, nil
end

function Board:step_forward_by_facing(current_index, facing, parity)
  local map = self.map

  local current_tile = self:get_tile(current_index)
  if not current_tile then
    return current_index, 0, facing
  end
  local current_id = current_tile.id
  local neigh = map.neighbors[current_id]

  local next_id = nil

  if map.outer_next and map.outer_next[current_id] then
    local entry = map.entry_points[current_id]
    if entry and parity and (parity % 2 == 0) and facing then
      local prev_id = map.outer_prev[current_id]
      local required_facing = map.direction(prev_id, current_id)
      if required_facing and required_facing == facing then
        next_id = entry.inner_id
      end
    end
    if not next_id then
      next_id = map.outer_next[current_id]
    end
  elseif map.market_id and current_id == map.market_id and facing and parity and map.turn_left and map.turn_right then
    local exit_dir = map.turn_right[facing]
    if parity % 2 == 1 then
      exit_dir = map.turn_left[facing]
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
      local back_dir = OPPOSITE[facing]
      local _, nid = pick_any_dir(neigh, back_dir)
      next_id = nid
      if not next_id then
        local _, nid2 = pick_any_dir(neigh, nil)
        next_id = nid2
      end
    end
  end

  if not next_id then
    return current_index, 0, facing
  end

  local next_index = self:index_of_tile_id(next_id)
  if not next_index then
    return current_index, 0, facing
  end
  local passed_start = 0
  if next_id == map.start_id then
    passed_start = 1
  end
  local step_dir = map.direction(current_id, next_id) or facing
  return next_index, passed_start, step_dir
end

function Board:step_backward_by_facing(current_index, facing, _parity)
  local map = self.map

  local current_tile = self:get_tile(current_index)
  if not current_tile then
    return current_index, 0, facing
  end
  local current_id = current_tile.id
  local neigh = map.neighbors[current_id]

  local next_id = nil
  if facing then
    local back_dir = OPPOSITE[facing]
    if back_dir and neigh[back_dir] then
      next_id = neigh[back_dir]
    end
  end

  if not next_id and map.outer_prev and map.outer_prev[current_id] then
    next_id = map.outer_prev[current_id]
  end

  if not next_id and facing then
    local _, nid = pick_any_dir(neigh, facing)
    next_id = nid
  end

  if not next_id then
    local _, nid = pick_any_dir(neigh, nil)
    next_id = nid
  end

  if not next_id then
    return current_index, 0, facing
  end

  local next_index = self:index_of_tile_id(next_id)
  if not next_index then
    return current_index, 0, facing
  end
  local passed_start = 0
  if next_id == map.start_id then
    passed_start = 1
  end
  local step_dir = map.direction(current_id, next_id) or facing
  return next_index, passed_start, step_dir
end

return Board
