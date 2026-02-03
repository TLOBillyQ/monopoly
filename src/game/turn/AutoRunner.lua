require "vendor.third_party.ClassUtils"


local auto_runner = Class("AutoRunner")


function auto_runner:init(opts)
  opts = opts or {}
  self.interval = opts.interval or 0.15
  self.timer = 0
  self.enabled = false
end


function auto_runner:set_enabled(on)
  self.enabled = on
  self.timer = 0
end


function auto_runner:reset_timer()
  self.timer = 0
end


function auto_runner:next_action(dt, env)
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

return auto_runner
