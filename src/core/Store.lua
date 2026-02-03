require "vendor.third_party.ClassUtils"
require "vendor.third_party.Utils"

---@class Store
---@field state table
---状态存储类，管理游戏状态持久化
local store = Class("Store")

local deep_copy = Utils.deep_copy

local function _new_dirty()
  return {
    any = false,
    players = false,
    board_tiles = false,
    turn = false,
    market = false,
    turn_countdown = false,
    inventory_ids = {},
  }
end

---创建新状态树
---@param init table? 初始状态表
function store:init(init)
  self.state = deep_copy(init or {})
  self.version = 0
  self.dirty = _new_dirty()
end

---创建新状态树
---@param init table? 初始状态表
---@return Store 新Store对象
---根据路径读取状态值（路径缺失返回 nil）
---@param self Store
---@param path table 路径数组（如{"players", 1, "cash"}）
---@return any 状态值，不存在则返回nil
function store:get(path)
  local node = self.state
  for i, key in ipairs(path) do
    assert(type(node) == "table", "store path not table: " .. tostring(key))
    node = node[key]
    if node == nil and i < #path then
      return nil
    end
  end
  return node
end

---根据路径设置状态值（自动创建中间表）
---@param self Store
---@param path table 路径数组
---@param value any 要设置的值
function store:set(path, value)
  local node = self.state
  for i = 1, #path - 1 do
    local key = path[i]
    local next_node = node[key]
    if next_node == nil then
      next_node = {}
      node[key] = next_node
    end
    assert(type(next_node) == "table", "store path not table: " .. tostring(key))
    node = next_node
  end
  node[path[#path]] = value

  self.version = (self.version or 0) + 1
  if not self.dirty then
    self.dirty = _new_dirty()
  end
  local dirty = self.dirty
  dirty.any = true
  local root = path and path[1]
  if root == "players" then
    dirty.players = true
    if path[3] == "inventory" then
      local pid = path[2]
      if pid ~= nil then
        dirty.inventory_ids[pid] = true
      end
    end
  elseif root == "board" then
    dirty.board_tiles = true
  elseif root == "market" then
    dirty.market = true
  elseif root == "turn" then
    if path[2] == "countdown_seconds" then
      dirty.turn_countdown = true
    else
      dirty.turn = true
    end
  end
end

function store:consume_dirty()
  local dirty = self.dirty or _new_dirty()
  self.dirty = _new_dirty()
  return dirty
end

return store
