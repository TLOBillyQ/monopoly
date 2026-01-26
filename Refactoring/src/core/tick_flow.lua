local TickFlow = {}
TickFlow.__index = TickFlow

function TickFlow.new()
  return setmetatable({ tickables = {} }, TickFlow)
end

function TickFlow:add_tickable(obj)
  assert(obj and obj.update, "tickable requires update")
  table.insert(self.tickables, obj)
end

function TickFlow:remove_tickable(obj)
  for i, v in ipairs(self.tickables) do
    if v == obj then
      table.remove(self.tickables, i)
      break
    end
  end
end

function TickFlow:tick(dt)
  for _, v in ipairs(self.tickables) do
    v:update(dt)
  end
end

return TickFlow
