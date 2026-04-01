require "vendor.third_party.ClassUtils"

---棋盘管理类，负责路径、地块和分支的管理
local board = Class("Board")

local direction_constants = require("src.rules.board.directions")
local opposite = direction_constants.opposite

local dir_priority = {
  up = 1,
  right = 2,
  down = 3,
  left = 4,
}

local function _sorted_dirs_comparator(a, b)
  local pa = dir_priority[a] or 100
  local pb = dir_priority[b] or 100
  if pa ~= pb then
    return pa < pb
  end
  return tostring(a) < tostring(b)
end

local function _sorted_dirs(neigh)
  local keys = {}
  for dir in pairs(neigh) do
    table.insert(keys, dir)
  end
  table.sort(keys, _sorted_dirs_comparator)
  return keys
end

local function _pick_any_dir(neigh, avoid_dir)
  assert(neigh ~= nil, "missing neighbors")
  for _, dir in ipairs(_sorted_dirs(neigh)) do
    if dir ~= avoid_dir then
      return dir, neigh[dir]
    end
  end
  return nil, nil
end

local function _pick_unique_dir(neigh, avoid_dir)
  assert(neigh ~= nil, "missing neighbors")
  local picked_dir = nil
  local picked_id = nil
  for _, dir in ipairs(_sorted_dirs(neigh)) do
    if dir ~= avoid_dir then
      if picked_dir ~= nil then
        return nil, nil
      end
      picked_dir = dir
      picked_id = neigh[dir]
    end
  end
  return picked_dir, picked_id
end

local function _resolve_outer_next(map, current_id, parity, can_enter_inner)
  if not map.outer_next[current_id] then
    return nil, false
  end
  local next_id = map.outer_next[current_id]
  local entry = map.entry_points[current_id]
  if entry and can_enter_inner and parity and (parity % 2 == 0) then
    next_id = entry.inner_id
    return next_id, true
  end
  return next_id, false
end

local function _resolve_fresh_forward_next(map, current_id, facing)
  if facing ~= nil then
    return nil
  end
  local fresh_forward_next = map.fresh_forward_next or nil
  return fresh_forward_next and fresh_forward_next[current_id] or nil
end

local function _resolve_facing_next(neigh, facing)
  if facing and neigh[facing] then
    return neigh[facing]
  end
  return nil
end

local function _resolve_fallback_next(neigh, facing)
  local back_dir = opposite[facing]
  local _, next_id = _pick_unique_dir(neigh, back_dir)
  if next_id then
    return next_id
  end

  local _, fallback_id = _pick_any_dir(neigh, back_dir)
  if fallback_id then
    return fallback_id
  end

  local _, any_id = _pick_any_dir(neigh, nil)
  return any_id
end

local function _resolve_forward_next_id(map, current_id, neigh, facing, parity, can_enter_inner)
  local outer_next, entered_inner = _resolve_outer_next(map, current_id, parity, can_enter_inner)
  if outer_next then
    return outer_next, entered_inner
  end

  local fresh_next = _resolve_fresh_forward_next(map, current_id, facing)
  if fresh_next ~= nil then
    return fresh_next, false
  end

  local facing_next = _resolve_facing_next(neigh, facing)
  if facing_next then
    return facing_next, false
  end

  return _resolve_fallback_next(neigh, facing), false
end

local function _resolve_forward_facing(map, current_id, facing, step_context)
  local neigh = map.neighbors[current_id]
  if neigh == nil then
    return facing
  end

  local next_id = _resolve_forward_next_id(
    map,
    current_id,
    neigh,
    facing,
    step_context.parity,
    not step_context.entered_inner
  )
  if next_id == nil then
    return facing
  end
  return map.direction(current_id, next_id)
end

local function _normalize_forward_step_context(parity_or_context)
  if type(parity_or_context) == "table" then
    return parity_or_context
  end
  return {
    parity = parity_or_context,
    entered_inner = false,
  }
end

local function _resolve_backward_by_facing(neigh, facing)
  if not facing then
    return nil
  end
  local back_dir = opposite[facing]
  if not back_dir then
    return nil
  end
  return neigh[back_dir]
end

local function _resolve_backward_from_map(map, current_id)
  if map.outer_prev[current_id] then
    return map.outer_prev[current_id]
  end
  local backward_fallback = map.backward_fallback or nil
  if backward_fallback and backward_fallback[current_id] then
    return backward_fallback[current_id]
  end
  return nil
end

local function _resolve_backward_from_neighbors(neigh, facing)
  local _, next_id = _pick_unique_dir(neigh, facing)
  if next_id then
    return next_id
  end

  local _, fallback_id = _pick_any_dir(neigh, facing)
  if fallback_id then
    return fallback_id
  end

  local _, any_id = _pick_any_dir(neigh, nil)
  return any_id
end

local _resolve_backward_next_source

local function _resolve_backward_next_id(map, current_id, neigh, facing)
  return _resolve_backward_next_source(map, current_id, neigh, facing).next_id
end

function _resolve_backward_next_source(map, current_id, neigh, facing)
  local reverse_facing_next_id = _resolve_backward_by_facing(neigh, facing)
  if reverse_facing_next_id then
    return {
      next_id = reverse_facing_next_id,
      source = "facing_reverse_neighbor",
    }
  end

  local mapped_next_id = _resolve_backward_from_map(map, current_id)
  if mapped_next_id then
    local outer_prev = map.outer_prev or nil
    if outer_prev and outer_prev[current_id] then
      return {
        next_id = mapped_next_id,
        source = "outer_prev",
      }
    end
    return {
      next_id = mapped_next_id,
      source = "backward_fallback",
    }
  end

  local fallback_next_id = _resolve_backward_from_neighbors(neigh, facing)
  if fallback_next_id then
    return {
      next_id = fallback_next_id,
      source = "neighbor_fallback",
    }
  end

  return {
    next_id = nil,
    source = nil,
  }
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
function board:place_mine(index, data)
  self.overlays.mines = self.overlays.mines or {}
  if data == nil then
    self.overlays.mines[index] = true
    return
  end
  local mine = {}
  for key, value in pairs(data) do
    mine[key] = value
  end
  self.overlays.mines[index] = mine
end

---检查指定位置是否有地雷
function board:has_mine(index)
  return self.overlays.mines[index] and true or false
end

---获取指定位置的地雷数据
function board:get_mine(index)
  return self.overlays.mines[index]
end

---激活指定位置的地雷
function board:arm_mine(index)
  local mine = self.overlays.mines[index]
  if type(mine) ~= "table" then
    return false
  end
  if mine.armed == true then
    return false
  end
  mine.armed = true
  return true
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
---第三返回值表示“落点后的下一步前进朝向”，不是刚刚走过来的那一步方向。
function board:step_forward_by_facing(current_index, facing, parity)
  local map = self.map
  local step_context = _normalize_forward_step_context(parity)

  local current_tile = self:get_tile(current_index)
  assert(current_tile ~= nil, "missing current tile: " .. tostring(current_index))
  local current_id = current_tile.id
  local neigh = map.neighbors[current_id]
  local next_id, entered_inner = _resolve_forward_next_id(
    map,
    current_id,
    neigh,
    facing,
    step_context.parity,
    not step_context.entered_inner
  )

  assert(next_id ~= nil, "missing next tile id from: " .. tostring(current_id))

  local next_index = self:index_of_tile_id(next_id)
  assert(next_index ~= nil, "missing next tile index: " .. tostring(next_id))
  local passed_start = 0
  if next_id == map.start_id then
    passed_start = 1
  end
  local travel_dir = map.direction(current_id, next_id)
  local next_step_context = {
    parity = step_context.parity,
    entered_inner = step_context.entered_inner or entered_inner,
  }
  local next_facing = _resolve_forward_facing(map, next_id, travel_dir, next_step_context)
  return next_index, passed_start, next_facing, entered_inner
end

---根据朝向向后移动一步
---第三返回值表示“落点后的下一步前进朝向”，供后续继续后退时取反使用。
function board:step_backward_by_facing(current_index, facing)
  local map = self.map

  local current_tile = self:get_tile(current_index)
  assert(current_tile ~= nil, "missing current tile: " .. tostring(current_index))
  local current_id = current_tile.id
  local neigh = map.neighbors[current_id]

  local next_result = _resolve_backward_next_source(map, current_id, neigh, facing)
  local next_id = next_result.next_id

  assert(next_id ~= nil, "missing prev tile id from: " .. tostring(current_id))

  local next_index = self:index_of_tile_id(next_id)
  assert(next_index ~= nil, "missing prev tile index: " .. tostring(next_id))
  local passed_start = 0
  if next_id == map.start_id then
    passed_start = 1
  end
  local next_facing = map.direction(next_id, current_id)
  return next_index, passed_start, next_facing
end

board._M_test = {
  _sorted_dirs_comparator = _sorted_dirs_comparator,
  _pick_any_dir = _pick_any_dir,
}

return board
