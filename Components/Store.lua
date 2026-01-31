require "Library.ClassUtils"
require "Library.Utils"

---@class Store
---@field state table
---状态存储类，管理游戏状态持久化
local Store = Class("Store")
Store.__class_new = Store.new

local deep_copy = Utils.deep_copy

---创建新状态树
---@param init table? 初始状态表
function Store:init(init)
  self.state = deep_copy(init or {})
end

---创建新状态树
---@param init table? 初始状态表
---@return Store 新Store对象
function Store.new(init)
  return Store.__class_new(Store, init)
end

---根据路径读取状态值
---@param self Store
---@param path table 路径数组（如{"players", 1, "cash"}）
---@return any 状态值，不存在则返回nil
function Store:get(path)
  local node = self.state
  for _, key in ipairs(path) do
    if type(node) ~= "table" then
      return nil
    end
    node = node[key]
  end
  return node
end

---根据路径设置状态值（自动创建中间表）
---@param self Store
---@param path table 路径数组
---@param value any 要设置的值
function Store:set(path, value)
  local node = self.state
  for i = 1, #path - 1 do
    local key = path[i]
    if node[key] == nil or type(node[key]) ~= "table" then
      node[key] = {}
    end
    node = node[key]
  end
  node[path[#path]] = value
end

return Store
