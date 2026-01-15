local AutoRunner = {}
AutoRunner.__index = AutoRunner


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
