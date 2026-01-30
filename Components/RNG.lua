require "Library.ClassUtils"

---@class RNG
---@field seed number
---@field state number
---随机数生成器（使用GameAPI.random_int）
local RNG = Class("RNG")
RNG.__class_new = RNG.new

---创建新随机数生成器
---@param seed number? 随机种子（保留参数以兼容现有代码）
---@param state number? 初始状态（保留参数以兼容现有代码）
function RNG:init(seed, state)
  self.seed = seed or 1
  self.state = state or (seed or 1)
end

---创建新随机数生成器
---@param seed number? 随机种子（保留参数以兼容现有代码）
---@param state number? 初始状态（保留参数以兼容现有代码）
---@return RNG 新RNG对象
function RNG.new(seed, state)
  return RNG.__class_new(RNG, seed, state)
end

---生成在[min, max]范围内的整数
---@param self RNG
---@param min number? 最小值（默认0）
---@param max number? 最大值（默认1）
---@return number 随机整数
function RNG:next_int(min, max)
  min = min or 0
  max = max or 1
  if GameAPI and GameAPI.random_int then
    return GameAPI.random_int(min, max)
  end
  local state = self.state or self.seed or 1
  state = (state * 1103515245 + 12345) % 2147483648
  self.state = state
  local span = max - min + 1
  if span <= 0 then
    return min
  end
  return min + (state % span)
end

---获取RNG的快照（用于序列化）
---@param self RNG
---@return table 包含seed和state的快照表
function RNG:snapshot()
  return { seed = self.seed, state = self.state }
end

return RNG
