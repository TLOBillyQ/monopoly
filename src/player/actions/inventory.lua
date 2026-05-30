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
  self._on_change = function(_) end
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

--[[ mutate4lua-manifest
version=2
projectHash=aed8eb1231d67e72
scope.0.id=chunk:src/player/actions/inventory.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=65
scope.0.semanticHash=2767dd57c8624714
scope.1.id=function:inventory:_notify_change:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=12
scope.1.semanticHash=4923938ec5a2e2c1
scope.2.id=function:anonymous@22:22
scope.2.kind=function
scope.2.startLine=22
scope.2.endLine=22
scope.2.semanticHash=323b2cdbe606879a
scope.3.id=function:inventory:init:15
scope.3.kind=function
scope.3.startLine=15
scope.3.endLine=23
scope.3.semanticHash=59ff0ee3babf2df7
scope.4.id=function:inventory:count:27
scope.4.kind=function
scope.4.startLine=27
scope.4.endLine=29
scope.4.semanticHash=a2dfb055fdc5c48b
scope.5.id=function:inventory:is_full:32
scope.5.kind=function
scope.5.startLine=32
scope.5.endLine=34
scope.5.semanticHash=a3a8c89124f51df4
scope.6.id=function:inventory:add:37
scope.6.kind=function
scope.6.startLine=37
scope.6.endLine=44
scope.6.semanticHash=c39016361b2a50bb
scope.7.id=function:inventory:remove_by_index:47
scope.7.kind=function
scope.7.startLine=47
scope.7.endLine=52
scope.7.semanticHash=fc03e718b351d40a
]]
