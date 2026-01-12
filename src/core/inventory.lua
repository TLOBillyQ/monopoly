local Inventory = {}
Inventory.__index = Inventory

function Inventory.new(opts)
  opts = opts or {}
  local max_slots = opts.max_slots or (opts.constants and opts.constants.inventory_slots)
  assert(max_slots ~= nil, "Inventory.new(opts) requires opts.max_slots or opts.constants.inventory_slots")

  local inv = { items = {}, max_slots = max_slots }
  return setmetatable(inv, Inventory)
end

function Inventory:count()
  return #self.items
end

function Inventory:is_full()
  return self:count() >= self.max_slots
end

function Inventory:add(item)
  if self:is_full() then
    return false
  end
  table.insert(self.items, item)
  return true
end

function Inventory:remove_by_index(idx)
  local item = self.items[idx]
  table.remove(self.items, idx)
  return item
end

function Inventory:remove_first(predicate)
  for i, it in ipairs(self.items) do
    if predicate(it) then
      return self:remove_by_index(i)
    end
  end
  return nil
end

function Inventory:find_index(predicate)
  for i, it in ipairs(self.items) do
    if predicate(it) then
      return i
    end
  end
  return nil
end

return Inventory
