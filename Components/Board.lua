require "Library.ClassUtils"

---@class Board
---@field path Tile[]
---@field tile_lookup table
---@field branches table
---@field index_by_id table
---@field map table
---@field overlays table
---棋盘管理类，负责路径、地块和分支的管理
local Board = Class("Board")

local OPPOSITE = {
  up = "down",
  down = "up",
  left = "right",
  right = "left",
}

local function _PickAnyDir(neigh, avoid_dir)
  assert(neigh ~= nil, "missing neighbors")
  for dir, next_id in pairs(neigh) do
    if dir ~= avoid_dir then
      return dir, next_id
    end
  end
  assert(false, "no neighbor available")
end

---创建新棋盘实例
---@param data table 棋盘数据（包含path/tile_lookup/branches/map/overlays）
function Board:Init(data)
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
---@param data table 棋盘数据（包含path/tile_lookup/branches/map/overlays）
---@return Board 新棋盘对象
---获取棋盘长度（地块数）
---@param self Board
---@return number 棋盘上的地块总数
function Board:Length()
  return #self.path
end

---根据地块ID获取其在棋盘路径中的索引
---@param self Board
---@param id string|number 地块ID
---@return number? 索引，1-based；如不存在则返回nil
function Board:IndexOfTileId(id)
  return self.index_by_id[id]
end

---根据索引获取地块
---@param self Board
---@param index number 地块索引（1-based）
---@return Tile? 地块对象，或nil
function Board:GetTile(index)
  return self.path[index]
end

---根据ID获取地块
---@param self Board
---@param id string|number 地块ID
---@return Tile? 地块对象，或nil
function Board:GetTileById(id)
  return self.tile_lookup[id]
end

---查找第一个指定类型的地块
---@param self Board
---@param tile_type string 地块类型（如"land"）
---@return number?, Tile? 索引和地块对象；如不存在返回nil, nil
function Board:FindFirstByType(tile_type)
  for idx, tile in ipairs(self.path) do
    if tile.type == tile_type then
      return idx, tile
    end
  end
  return nil, nil
end

---获取棋盘覆盖物表（包含roadblocks和mines）
---@param self Board
---@return table 覆盖物表
function Board:GetOverlays()
  return self.overlays
end

---在指定位置放置路障
---@param self Board
---@param index number 位置索引
function Board:PlaceRoadblock(index)
  self.overlays.roadblocks = self.overlays.roadblocks or {}
  self.overlays.roadblocks[index] = true
end

---检查指定位置是否有路障
---@param self Board
---@param index number 位置索引
---@return boolean 是否有路障
function Board:HasRoadblock(index)
  return self.overlays.roadblocks[index] and true or false
end

---清除指定位置的路障
---@param self Board
---@param index number 位置索引
function Board:ClearRoadblock(index)
  self.overlays.roadblocks[index] = nil
end

---在指定位置放置地雷
---@param self Board
---@param index number 位置索引
function Board:PlaceMine(index)
  self.overlays.mines = self.overlays.mines or {}
  self.overlays.mines[index] = true
end

---检查指定位置是否有地雷
---@param self Board
---@param index number 位置索引
---@return boolean 是否有地雷
function Board:HasMine(index)
  return self.overlays.mines[index] and true or false
end

---清除指定位置的地雷
---@param self Board
---@param index number 位置索引
function Board:ClearMine(index)
  self.overlays.mines[index] = nil
end

---清除指定位置的所有覆盖物（路障和地雷）
---@param self Board
---@param index number 位置索引
function Board:ClearAll(index)
  self:ClearRoadblock(index)
  self:ClearMine(index)
end


---按步数推进棋盘位置（考虑分支和绕圈）
---@param self Board
---@param index number 当前位置索引
---@param steps number 要移动的步数
---@param branch_parity number? 分支奇偶性（用于分支选择）
---@return number, number 新位置索引和绕圈次数
function Board:Advance(index, steps, branch_parity)
  local length = self:Length()
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
---@param self Board
---@param current_index number 当前位置索引
---@param facing string? 面向方向（如"up"、"right"等）
---@param parity number? 奇偶性用于市场出口
---@return number, number, string 新位置、绕圈次数、新方向
function Board:StepForwardByFacing(current_index, facing, parity)
  local map = self.map

  local current_tile = self:GetTile(current_index)
  assert(current_tile ~= nil, "missing current tile: " .. tostring(current_index))
  local current_id = current_tile.id
  local neigh = map.neighbors[current_id]

  local next_id = nil

  if map.outer_next[current_id] then
    local entry = map.entry_points[current_id]
    if entry and parity and (parity % 2 == 0) and facing then
      local prev_id = map.outer_prev[current_id]
      local required_facing = map.Direction(prev_id, current_id)
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
      local back_dir = OPPOSITE[facing]
      local _, nid = _PickAnyDir(neigh, back_dir)
      next_id = nid
      if not next_id then
        local _, nid2 = _PickAnyDir(neigh, nil)
        next_id = nid2
      end
    end
  end

  assert(next_id ~= nil, "missing next tile id from: " .. tostring(current_id))

  local next_index = self:IndexOfTileId(next_id)
  assert(next_index ~= nil, "missing next tile index: " .. tostring(next_id))
  local passed_start = 0
  if next_id == map.start_id then
    passed_start = 1
  end
  local step_dir = map.Direction(current_id, next_id) or facing
  return next_index, passed_start, step_dir
end

---根据朝向向后移动一步
---@param self Board
---@param current_index number 当前位置索引
---@param facing string? 面向方向
---@param _parity number? 奇偶性（后退时不使用）
---@return number, number, string 新位置、绕圈次数、新方向
function Board:StepBackwardByFacing(current_index, facing, _parity)
  local map = self.map

  local current_tile = self:GetTile(current_index)
  assert(current_tile ~= nil, "missing current tile: " .. tostring(current_index))
  local current_id = current_tile.id
  local neigh = map.neighbors[current_id]

  local next_id = nil
  if facing then
    local back_dir = OPPOSITE[facing]
    if back_dir and neigh[back_dir] then
      next_id = neigh[back_dir]
    end
  end

  if not next_id and map.outer_prev[current_id] then
    next_id = map.outer_prev[current_id]
  end

  if not next_id and facing then
    local _, nid = _PickAnyDir(neigh, facing)
    next_id = nid
  end

  if not next_id then
    local _, nid = _PickAnyDir(neigh, nil)
    next_id = nid
  end

  assert(next_id ~= nil, "missing prev tile id from: " .. tostring(current_id))

  local next_index = self:IndexOfTileId(next_id)
  assert(next_index ~= nil, "missing prev tile index: " .. tostring(next_id))
  local passed_start = 0
  if next_id == map.start_id then
    passed_start = 1
  end
  local step_dir = map.Direction(current_id, next_id) or facing
  return next_index, passed_start, step_dir
end

return Board
