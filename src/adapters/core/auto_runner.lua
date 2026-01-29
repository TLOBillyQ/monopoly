---@class AutoRunner
---自动运行器，用于定时执行游戏逻辑
local AutoRunner = {}
AutoRunner.__index = AutoRunner

---创建新自动运行器
---@param opts table 选项表（interval等）
---@return AutoRunner 新AutoRunner对象
function AutoRunner.new(opts)
  opts = opts or {}
  local self = {
    interval = opts.interval or 0.15,
    timer = 0,
    enabled = false,
  }
  return setmetatable(self, AutoRunner)
end

---启用或禁用自动运行
---@param self AutoRunner
---@param on boolean 启用状态
function AutoRunner:set_enabled(on)
  self.enabled = on
  self.timer = 0
end

---重置计时器
---@param self AutoRunner
function AutoRunner:reset_timer()
  self.timer = 0
end


---获取下一个自动行动（基于计时器）
---@param self AutoRunner
---@param dt number 增量时间（秒）
---@param env table? 环境表（game_finished/modal_active等）
---@return table? 自动行动对象或nil
function AutoRunner:next_action(dt, env)
  if not self.enabled then
    return nil
  end
  env = env or {}
  if env.game_finished then
    return nil
  end

  self.timer = self.timer + dt
  if self.timer < self.interval then
    return nil
  end
  self.timer = 0

  if env.modal_active then
    if env.modal_buttons and #env.modal_buttons > 0 then
      return { type = "modal_button", index = 1 }
    end
    return { type = "modal_confirm" }
  end

  return { type = "ui_button", id = "next" }
end

return AutoRunner
