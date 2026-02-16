require "lib.third_party.ClassUtils"

---棋盘管理类，负责路径、地块和分支的管理
local board = Class("Board")

local opposite = {
  up = "down",
  down = "up",
  left = "right",
  right = "left",
}

local dir_priority = {
  up = 1,
  right = 2,
  down = 3,
  left = 4,
}

local function _sorted_dirs(neigh)
  local keys = {}
  for dir in pairs(neigh) do
    table.insert(keys, dir)
  end
  table.sort(keys, function(a, b)
    local pa = dir_priority[a] or 100
    local pb = dir_priority[b] or 100
    if pa ~= pb then
      return pa < pb
    end
    return tostring(a) < tostring(b)
  end)
  return keys
end

local function _pick_any_dir(neigh, avoid_dir)
  assert(neigh ~= nil, "missing neighbors")
  for _, dir in ipairs(_sorted_dirs(neigh)) do
    if dir ~= avoid_dir then
      return dir, neigh[dir]
    end
  end
  assert(false, "no neighbor available")
end

---创建新棋盘实例
function board:init(data)
  local tile_lookup = data.tile_lookup
  local path = data.path

  local index_by_id = {}
  for idx, tile in ipairs(path) do
    index_by_id[tile.id] = idx
  end

  self.path = path
  self.tile_lookup = tile_lookup
  self.branches = data.branches
  self.index_by_id = index_by_id
  self.map = data.map
  self.overlays = data.overlays
end

---创建新棋盘实例
---获取棋盘长度（地块数）
function board:length()
  return #self.path
end

---根据地块ID获取其在棋盘路径中的索引
function board:index_of_tile_id(id)
  return self.index_by_id[id]
end

---根据索引获取地块
function board:get_tile(index)
  return self.path[index]
end

---根据ID获取地块
function board:get_tile_by_id(id)
  return self.tile_lookup[id]
end

---查找第一个指定类型的地块
function board:find_first_by_type(tile_type)
  for idx, tile in ipairs(self.path) do
    if tile.type == tile_type then
      return idx, tile
    end
  end
  return nil, nil
end

---获取棋盘覆盖物表（包含roadblocks和mines）
function board:get_overlays()
  return self.overlays
end

---在指定位置放置路障
function board:place_roadblock(index)
  self.overlays.roadblocks = self.overlays.roadblocks or {}
  self.overlays.roadblocks[index] = true
end

---检查指定位置是否有路障
function board:has_roadblock(index)
  return self.overlays.roadblocks[index] and true or false
end

---清除指定位置的路障
function board:clear_roadblock(index)
  self.overlays.roadblocks[index] = nil
end

---在指定位置放置地雷
function board:place_mine(index)
  self.overlays.mines = self.overlays.mines or {}
  self.overlays.mines[index] = true
end

---检查指定位置是否有地雷
function board:has_mine(index)
  return self.overlays.mines[index] and true or false
end

---清除指定位置的地雷
function board:clear_mine(index)
  self.overlays.mines[index] = nil
end

---清除指定位置的所有覆盖物（路障和地雷）
function board:clear_all(index)
  self:clear_roadblock(index)
  self:clear_mine(index)
end


---按步数推进棋盘位置（考虑分支和绕圈）
function board:advance(index, steps, branch_parity)
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

---根据朝向向前移动一步（用于精确导航）
function board:step_forward_by_facing(current_index, facing, parity)
  local map = self.map

  local current_tile = self:get_tile(current_index)
  assert(current_tile ~= nil, "missing current tile: " .. tostring(current_index))
  local current_id = current_tile.id
  local neigh = map.neighbors[current_id]

  local next_id = nil

  if map.outer_next[current_id] then
    local entry = map.entry_points[current_id]
    if entry and parity and (parity % 2 == 0) and facing then
      local prev_id = map.outer_prev[current_id]
      local required_facing = map.direction(prev_id, current_id)
      if required_facing == facing then
        next_id = entry.inner_id
      end
    end
    if not next_id then
      next_id = map.outer_next[current_id]
    end
  elseif current_id == map.market_id and facing and parity then
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
      local back_dir = opposite[facing]
      local _, nid = _pick_any_dir(neigh, back_dir)
      next_id = nid
      if not next_id then
        local _, nid2 = _pick_any_dir(neigh, nil)
        next_id = nid2
      end
    end
  end

  assert(next_id ~= nil, "missing next tile id from: " .. tostring(current_id))

  local next_index = self:index_of_tile_id(next_id)
  assert(next_index ~= nil, "missing next tile index: " .. tostring(next_id))
  local passed_start = 0
  if next_id == map.start_id then
    passed_start = 1
  end
  local step_dir = map.direction(current_id, next_id) or facing
  return next_index, passed_start, step_dir
end

---根据朝向向后移动一步
function board:step_backward_by_facing(current_index, facing)
  local map = self.map

  local current_tile = self:get_tile(current_index)
  assert(current_tile ~= nil, "missing current tile: " .. tostring(current_index))
  local current_id = current_tile.id
  local neigh = map.neighbors[current_id]

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
    local _, nid = _pick_any_dir(neigh, facing)
    next_id = nid
  end

  if not next_id then
    local _, nid = _pick_any_dir(neigh, nil)
    next_id = nid
  end

  assert(next_id ~= nil, "missing prev tile id from: " .. tostring(current_id))

  local next_index = self:index_of_tile_id(next_id)
  assert(next_index ~= nil, "missing prev tile index: " .. tostring(next_id))
  local passed_start = 0
  if next_id == map.start_id then
    passed_start = 1
  end
  local step_dir = map.direction(current_id, next_id) or facing
  return next_index, passed_start, step_dir
end

return board
