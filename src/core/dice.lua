local Dice = {}
Dice.__index = Dice

function Dice.roll(count, override_values)
  local results = {}
  local total = 0
  if override_values and #override_values > 0 then
    for i = 1, count do
      local v = override_values[i] or override_values[#override_values]
      table.insert(results, v)
      total = total + v
    end
    return results, total
  end
  for _ = 1, count do
    local v = math.random(1, 6)
    table.insert(results, v)
    total = total + v
  end
  return results, total
end

return Dice
