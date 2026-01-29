---@class RNG
---随机数生成器（使用GameAPI.random_int）
local RNG = {}
RNG.__index = RNG

---创建新随机数生成器
---@param seed number? 随机种子（保留参数以兼容现有代码）
---@param state number? 初始状态（保留参数以兼容现有代码）
---@return RNG 新RNG对象
function RNG.new(seed, state)
  local self = {
    seed = seed or 1,
    state = state or (seed or 1),
  }
  return setmetatable(self, RNG)
end

---生成在[min, max]范围内的整数
---@param self RNG
---@param min number? 最小值（默认0）
---@param max number? 最大值（默认1）
---@return number 随机整数
function RNG:next_int(min, max)
  min = min or 0
  max = max or 1
  return GameAPI.random_int(min, max)
end

---获取RNG的快照（用于序列化）
---@param self RNG
---@return table 包含seed和state的快照表
function RNG:snapshot()
  return { seed = self.seed, state = self.state }
end

return RNG
