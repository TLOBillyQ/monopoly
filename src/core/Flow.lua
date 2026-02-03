require "vendor.third_party.ClassUtils"

---@class Flow
---@field states table
---@field current string?
---@field args table
---@field running boolean
---状态机类，管理游戏状态流转
local flow = Class("Flow")

---创建新状态机实例
---@param opts table 选项表（states/start/args）
function flow:init(opts)
  self.states = opts.states or {}
  self.current = opts.start or nil
  self.args = opts.args or {}
  self.running = false
end

---创建新状态机实例
---@param opts table 选项表（states/start/args）
---@return Flow 新状态机对象
---执行一步状态转移
---@param self Flow
---@return string? 下一个状态名，nil表示完成
function flow:step()
  assert(self.current ~= nil, "flow current state missing")
  local fn = self.states[self.current]
  assert(fn, "flow state not found: " .. tostring(self.current))
  local next_state, next_args = fn(self.args)
  self.current = next_state
  self.args = next_args or {}
  return self.current
end

return flow
