require "Library.ClassUtils"

---@class Dice
---骰子摇摇类，用于生成随机摇骰结果
local Dice = Class("Dice")

---掷骰子
---@param count number 骰子数量
---@param override_values number[]? 覆盖值列表（用于测试）
---@param rng RNG 随机数生成器
---@return number[] 每个骰子的结果
---@return number 总和
function Dice.roll(count, override_values, rng)
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
  assert(rng and rng.next_int, "Dice.roll requires rng")
  for _ = 1, count do
    local v = rng:next_int(1, 6)
    table.insert(results, v)
    total = total + v
  end
  return results, total
end

return Dice
