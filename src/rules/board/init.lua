require "vendor.third_party.ClassUtils"

---棋盘管理类，负责路径、地块和分支的管理
local board = Class("Board")

local direction = require("src.rules.board.direction")

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
---第三返回值表示"落点后的下一步前进朝向"，不是刚刚走过来的那一步方向。
function board:step_forward_by_facing(current_index, facing, parity)
  local map = self.map
  local step_context = direction.normalize_forward_step_context(parity)

  local current_tile = self:get_tile(current_index)
  assert(current_tile ~= nil, "missing current tile: " .. tostring(current_index))
  local current_id = current_tile.id
  local neigh = map.neighbors[current_id]
  local next_id, entered_inner = direction.resolve_forward_next_id(
    map,
    current_id,
    neigh,
    facing,
    step_context.parity,
    not step_context.entered_inner,
    step_context.skip_entry_on_tile_id
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
  local next_facing = direction.resolve_forward_facing(map, next_id, travel_dir, next_step_context)
  return next_index, passed_start, next_facing, entered_inner
end

---根据朝向向后移动一步
---第三返回值表示"落点后的下一步前进朝向"，供后续继续后退时取反使用。
function board:step_backward_by_facing(current_index, facing)
  local map = self.map

  local current_tile = self:get_tile(current_index)
  assert(current_tile ~= nil, "missing current tile: " .. tostring(current_index))
  local current_id = current_tile.id
  local neigh = map.neighbors[current_id]

  local next_result = direction.resolve_backward_next_source(map, current_id, neigh, facing)
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

board._M_test = direction._M_test

return board

--[[ mutate4lua-manifest
version=2
projectHash=273f7d55be64c11b
scope.0.id=chunk:src/rules/board/init.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=218
scope.0.semanticHash=df546926921390bd
scope.1.id=function:board:length:27
scope.1.kind=function
scope.1.startLine=27
scope.1.endLine=29
scope.1.semanticHash=9091d0e0f4c2e67f
scope.2.id=function:board:index_of_tile_id:32
scope.2.kind=function
scope.2.startLine=32
scope.2.endLine=34
scope.2.semanticHash=08bd7da858293bb2
scope.3.id=function:board:get_tile:37
scope.3.kind=function
scope.3.startLine=37
scope.3.endLine=39
scope.3.semanticHash=0b5a6eec069d0def
scope.4.id=function:board:get_tile_by_id:42
scope.4.kind=function
scope.4.startLine=42
scope.4.endLine=44
scope.4.semanticHash=e48a170f85c93235
scope.5.id=function:board:get_overlays:57
scope.5.kind=function
scope.5.startLine=57
scope.5.endLine=59
scope.5.semanticHash=42dbf51d7ace2620
scope.6.id=function:board:place_roadblock:62
scope.6.kind=function
scope.6.startLine=62
scope.6.endLine=65
scope.6.semanticHash=395d10d22384734e
scope.7.id=function:board:has_roadblock:68
scope.7.kind=function
scope.7.startLine=68
scope.7.endLine=70
scope.7.semanticHash=6d7688623c8ef073
scope.8.id=function:board:clear_roadblock:73
scope.8.kind=function
scope.8.startLine=73
scope.8.endLine=75
scope.8.semanticHash=31adebc70e0d6f49
scope.9.id=function:board:has_mine:92
scope.9.kind=function
scope.9.startLine=92
scope.9.endLine=94
scope.9.semanticHash=ceb9b9a2cee62f21
scope.10.id=function:board:get_mine:97
scope.10.kind=function
scope.10.startLine=97
scope.10.endLine=99
scope.10.semanticHash=662c3b8e7b1e9142
scope.11.id=function:board:arm_mine:102
scope.11.kind=function
scope.11.startLine=102
scope.11.endLine=112
scope.11.semanticHash=2288eccd41aa790f
scope.12.id=function:board:clear_mine:115
scope.12.kind=function
scope.12.startLine=115
scope.12.endLine=117
scope.12.semanticHash=dadc9c5829d9ba47
scope.13.id=function:board:clear_all:120
scope.13.kind=function
scope.13.startLine=120
scope.13.endLine=123
scope.13.semanticHash=2937ee847df61b02
scope.14.id=function:board:step_forward_by_facing:155
scope.14.kind=function
scope.14.startLine=155
scope.14.endLine=188
scope.14.semanticHash=51ed089fd2f8babb
scope.15.id=function:board:step_backward_by_facing:192
scope.15.kind=function
scope.15.startLine=192
scope.15.endLine=213
scope.15.semanticHash=ecfd5f8fefae39c4
]]
