local DecisionEngine = require("src.gameplay.decision_engine")

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

local function should_tick(self, dt)
  self.timer = self.timer + dt
  if self.timer < self.interval then
    return false
  end
  self.timer = 0
  return true
end

local function modal_action(env)
  if not env.modal_active then
    return nil
  end
  if env.modal_buttons and #env.modal_buttons > 0 then
    return { type = "modal_button", index = 1 }
  end
  return { type = "modal_confirm" }
end

local function choice_action(env)
  local pending = env.pending_choice
  if not pending then
    return nil
  end
  local action = DecisionEngine.get_choice_action(env.game, pending)
  if action then
    return action
  end
  return DecisionEngine.get_fallback_choice_action(pending)
end

function AutoRunner:next_action(dt, env)
  if not self.enabled then
    return nil
  end
  env = env or {}
  if env.game_finished then
    return nil
  end
  if not should_tick(self, dt) then
    return nil
  end

  local action = modal_action(env)
  if action then
    return action
  end

  action = choice_action(env)
  if action then
    return action
  end

  return { type = "ui_button", id = "next" }
end

return AutoRunner
