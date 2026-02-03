require "vendor.third_party.ClassUtils"
require "vendor.third_party.Utils"

---@class Store
---@field state table
---状态存储类，管理游戏状态持久化
local Store = Class("Store")

local deep_copy = Utils.deep_copy

---创建新状态树
---@param init table? 初始状态表
function Store:Init(init)
  self.state = deep_copy(init or {})
end

---创建新状态树
---@param init table? 初始状态表
---@return Store 新Store对象
---根据路径读取状态值（路径缺失返回 nil）
---@param self Store
---@param path table 路径数组（如{"players", 1, "cash"}）
---@return any 状态值，不存在则返回nil
function Store:Get(path)
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
function Store:Set(path, value)
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
end

return Store
