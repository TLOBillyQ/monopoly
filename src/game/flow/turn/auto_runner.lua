require "vendor.third_party.ClassUtils"

local choice_auto_policy = require("src.game.flow.turn.choice_auto_policy")

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

local function _resolve_choice_actor_role_id(env)
  local choice = env and env.pending_choice or nil
  if choice and choice.owner_role_id ~= nil then
    return choice.owner_role_id
  end
  return env and (env.current_player_id or env.current_player_index) or nil
end

local function _resolve_choice_action(env)
  if not (env and env.pending_choice and env.game) then
    return nil
  end
  local action = choice_auto_policy.decide(env.game, env.state, env.pending_choice, {
    mode = "wait_choice",
  })
  if action and action.actor_role_id == nil then
    action.actor_role_id = _resolve_choice_actor_role_id(env)
  end
  return action
end

function auto_runner:next_action(dt, env)
  if not self.enabled then
    return nil
  end
  env = env or {}
  if env.game_finished then
    return nil
  end
  if env.current_player_auto ~= true then
    return nil
  end

  self.timer = self.timer + dt
  if self.timer < self.interval then
    return nil
  end
  self.timer = 0

  local choice_action = _resolve_choice_action(env)
  if choice_action then
    return choice_action
  end

  if env.modal_active then
    if env.modal_buttons and #env.modal_buttons > 0 then
      return { type = "modal_button", index = 1 }
    end
    return { type = "modal_confirm" }
  end

  local actor_role_id = env.current_player_id or env.current_player_index
  return { type = "ui_button", id = "next", actor_role_id = actor_role_id }
end

return auto_runner
