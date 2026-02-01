require "Library.ClassUtils"

---@class Inventory
---@field items table[]
---@field max_slots number
---@field _on_change fun(inv: Inventory)?
---@field _suspend_on_change boolean?
---背包管理类，管理玩家物品
local Inventory = Class("Inventory")

---通知背包有变化
---@param self Inventory
function Inventory:_notify_change()
  if self._suspend_on_change then
    return
  end
  local cb = self._on_change
  if cb then
    cb(self)
  end
end

---创建新背包实例
---@param opts table 选项表（max_slots或constants）
function Inventory:init(opts)
  opts = opts or {}
  local max_slots = opts.max_slots or (opts.constants and opts.constants.inventory_slots)
  assert(max_slots ~= nil, "Inventory.new(opts) requires opts.max_slots or opts.constants.inventory_slots")

  self.items = {}
  self.max_slots = max_slots
end

---创建新背包实例
---@param opts table 选项表（max_slots或constants）
---@return Inventory 新背包对象
---获取背包中的物品数量
---@param self Inventory
---@return number 物品数量
function Inventory:count()
  return #self.items
end

---检查背包是否已满
---@param self Inventory
---@return boolean 是否已满
function Inventory:is_full()
  return self:count() >= self.max_slots
end

---向背包添加物品
---@param self Inventory
---@param item table 物品对象
---@return boolean 是否成功（背包满则失败）
function Inventory:add(item)
  if self:is_full() then
    return false
  end
  table.insert(self.items, item)
  self:_notify_change()
  return true
end

---根据索引删除背包中的物品
---@param self Inventory
---@param idx number 物品索引（1-based）
---@return table? 被删除的物品
function Inventory:remove_by_index(idx)
  local item = self.items[idx]
  table.remove(self.items, idx)
  self:_notify_change()
  return item
end

---根据谓词查找物品索引
---@param self Inventory
---@param predicate fun(item: table): boolean 判断函数
---@return number? 物品索引，或nil
function Inventory:find_index(predicate)
  for i, it in ipairs(self.items) do
    if predicate(it) then
      return i
    end
  end
  return nil
end

return Inventory
