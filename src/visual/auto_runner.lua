local AutoRunner = {}
AutoRunner.__index = AutoRunner

-- Generate simulated input for auto play without直接调用游戏逻辑
function AutoRunner.new(opts)
  local self = {
    interval = (opts and opts.interval) or 0.15,
    timer = 0,
    enabled = false,
  }
  return setmetatable(self, AutoRunner)
end

function AutoRunner:set_enabled(on)
  self.enabled = on and true or false
  self.timer = 0
end

function AutoRunner:reset_timer()
  self.timer = 0
end

  -- env: { modal_active, modal_buttons, pending_choice, game_finished }
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

  local pending = env.pending_choice
  if pending then
    local first = pending.options and pending.options[1]
    if first then
      return { type = "choice_select", choice_id = pending.id, option_id = first.id or first }
    end
    return { type = "choice_cancel", choice_id = pending.id }
  end

  return { type = "ui_button", id = "next" }
end

return AutoRunner
