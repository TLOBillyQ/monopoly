require "vendor.third_party.ClassUtils"

---背包管理类，管理玩家物品
local inventory = Class("Inventory")

---通知背包有变化
function inventory:_notify_change()
  if self._suspend_on_change then
    return
  end
  self._on_change(self)
end

---创建新背包实例
function inventory:init(opts)
  opts = opts or {}
  local max_slots = opts.max_slots or (opts.constants and opts.constants.inventory_slots)
  assert(max_slots ~= nil, "Inventory.new(opts) requires opts.max_slots or opts.constants.inventory_slots")

  self.items = {}
  self.max_slots = max_slots
  self._on_change = function() end
end

---创建新背包实例
---获取背包中的物品数量
function inventory:count()
  return #self.items
end

---检查背包是否已满
function inventory:is_full()
  return self:count() >= self.max_slots
end

---向背包添加物品
function inventory:add(item)
  if self:is_full() then
    return false
  end
  table.insert(self.items, item)
  self:_notify_change()
  return true
end

---根据索引删除背包中的物品
function inventory:remove_by_index(idx)
  local item = self.items[idx]
  table.remove(self.items, idx)
  self:_notify_change()
  return item
end

---根据谓词查找物品索引
function inventory:find_index(predicate)
  for i, it in ipairs(self.items) do
    if predicate(it) then
      return i
    end
  end
  return nil
end

return inventory
