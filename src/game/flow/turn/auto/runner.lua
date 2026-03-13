require "vendor.third_party.ClassUtils"

local choice_auto_policy = require("src.game.flow.turn.auto.choice_auto_policy")
local gameplay_rules = require("src.core.config.gameplay_rules")

local auto_runner = Class("AutoRunner")


function auto_runner:init(opts)
  opts = opts or {}
  self.interval = opts.interval or 0.15
  self.timer = 0
  self.enabled = false
  self.waiting_for_interval = false
  self.last_actor_role_id = nil
  self.last_wait_kind = nil
  self.last_choice_id = nil
end


function auto_runner:set_enabled(on)
  self.enabled = on
  self.timer = 0
  self.waiting_for_interval = false
  self.last_actor_role_id = nil
  self.last_wait_kind = nil
  self.last_choice_id = nil
end


function auto_runner:reset_timer()
  self.timer = 0
  self.waiting_for_interval = false
  self.last_actor_role_id = nil
  self.last_wait_kind = nil
  self.last_choice_id = nil
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

local function _resolve_wait_kind(env)
  if env and env.pending_choice then
    return "choice"
  end
  if env and env.modal_active then
    return "modal"
  end
  return "next"
end

local function _resolve_interval_seconds(self, env)
  local wait_kind = _resolve_wait_kind(env)
  if wait_kind == "choice" then
    return gameplay_rules.auto_choice_min_visible_seconds or 0
  end
  return self.interval or 0
end

local function _sync_wait_signature(self, env)
  local actor_role_id = env and (env.current_player_id or env.current_player_index) or nil
  local wait_kind = _resolve_wait_kind(env)
  local choice = env and env.pending_choice or nil
  local choice_id = choice and choice.id or nil
  local changed = actor_role_id ~= self.last_actor_role_id
      or wait_kind ~= self.last_wait_kind
      or choice_id ~= self.last_choice_id
  if changed then
    self.timer = 0
    self.waiting_for_interval = false
    self.last_actor_role_id = actor_role_id
    self.last_wait_kind = wait_kind
    self.last_choice_id = choice_id
  end
end

local function _should_skip_action(self, env)
  if not self.enabled then
    return true
  end
  env = env or {}
  if env.game_finished then
    return true
  end
  if env.current_player_auto ~= true then
    return true
  end
  return false
end

local function _should_wait_interval(self, interval)
  if self.timer < interval then
    self.waiting_for_interval = true
    return true
  end
  return false
end

local function _reset_timer_state(self)
  self.timer = 0
  self.waiting_for_interval = false
end

local function _resolve_modal_action(env)
  if not env.modal_active then
    return nil
  end
  if env.modal_buttons and #env.modal_buttons > 0 then
    return { type = "modal_button", index = 1 }
  end
  return { type = "modal_confirm" }
end

local function _resolve_next_button_action(env)
  local actor_role_id = env.current_player_id or env.current_player_index
  return { type = "ui_button", id = "next", actor_role_id = actor_role_id }
end

function auto_runner:next_action(dt, env)
  if _should_skip_action(self, env) then
    return nil
  end

  _sync_wait_signature(self, env)
  local interval = _resolve_interval_seconds(self, env)
  self.timer = self.timer + dt
  if _should_wait_interval(self, interval) then
    return nil
  end
  _reset_timer_state(self)

  local choice_action = _resolve_choice_action(env)
  if choice_action then
    return choice_action
  end

  local modal_action = _resolve_modal_action(env)
  if modal_action then
    return modal_action
  end

  return _resolve_next_button_action(env)
end

return auto_runner
