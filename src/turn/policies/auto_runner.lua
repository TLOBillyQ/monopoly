require "vendor.third_party.ClassUtils"

local choice_auto_policy = require("src.turn.policies.choice_auto")
local timing = require("src.config.gameplay.timing")

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
  self:reset_timer()
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

local _choice_ctx = { mode = "wait_choice" }

local function _resolve_choice_action(env)
  if not (env and env.pending_choice and env.game) then
    return nil
  end
  local action = choice_auto_policy.decide(env.game, env.state, env.pending_choice, _choice_ctx)
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
    return timing.auto_decision_delay_seconds or 0
  end
  return self.interval or 0
end

local function _wait_signature_changed(self, actor_role_id, wait_kind, choice_id)
  return actor_role_id ~= self.last_actor_role_id
      or wait_kind ~= self.last_wait_kind
      or choice_id ~= self.last_choice_id
end

local function _sync_wait_signature(self, env)
  local actor_role_id = env and (env.current_player_id or env.current_player_index) or nil
  local wait_kind = _resolve_wait_kind(env)
  local choice = env and env.pending_choice or nil
  local choice_id = choice and choice.id or nil
  local changed = _wait_signature_changed(self, actor_role_id, wait_kind, choice_id)
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

local _modal_button_action = { type = "modal_button", index = 1 }
local _modal_confirm_action = { type = "modal_confirm" }
local _next_button_action = { type = "ui_button", id = "next", actor_role_id = nil }

local function _resolve_modal_action(env)
  if not env.modal_active then
    return nil
  end
  if env.modal_buttons and #env.modal_buttons > 0 then
    return _modal_button_action
  end
  return _modal_confirm_action
end

local function _resolve_next_button_action(env)
  _next_button_action.actor_role_id = env.current_player_id or env.current_player_index
  return _next_button_action
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

--[[ mutate4lua-manifest
version=2
projectHash=918b4d4553ac6b93
scope.0.id=chunk:src/turn/policies/auto_runner.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=168
scope.0.semanticHash=70671792de57cc92
scope.1.id=function:auto_runner:init:9
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=18
scope.1.semanticHash=225a225b9f611b05
scope.2.id=function:auto_runner:set_enabled:21
scope.2.kind=function
scope.2.startLine=21
scope.2.endLine=24
scope.2.semanticHash=fd437518daf8f3d7
scope.3.id=function:auto_runner:reset_timer:27
scope.3.kind=function
scope.3.startLine=27
scope.3.endLine=33
scope.3.semanticHash=298df59a0e44d287
scope.4.id=function:_resolve_choice_actor_role_id:35
scope.4.kind=function
scope.4.startLine=35
scope.4.endLine=41
scope.4.semanticHash=dec1536eef23668d
scope.5.id=function:_resolve_choice_action:45
scope.5.kind=function
scope.5.startLine=45
scope.5.endLine=54
scope.5.semanticHash=819ff49f9959f2b2
scope.6.id=function:_resolve_wait_kind:56
scope.6.kind=function
scope.6.startLine=56
scope.6.endLine=64
scope.6.semanticHash=a9fdd4769336bda0
scope.7.id=function:_resolve_interval_seconds:66
scope.7.kind=function
scope.7.startLine=66
scope.7.endLine=72
scope.7.semanticHash=81e9e0a46d1e5c06
scope.8.id=function:_wait_signature_changed:74
scope.8.kind=function
scope.8.startLine=74
scope.8.endLine=78
scope.8.semanticHash=50f5e9c2e6890230
scope.9.id=function:_sync_wait_signature:80
scope.9.kind=function
scope.9.startLine=80
scope.9.endLine=93
scope.9.semanticHash=5ab178608f766fbe
scope.10.id=function:_should_skip_action:95
scope.10.kind=function
scope.10.startLine=95
scope.10.endLine=107
scope.10.semanticHash=15d92dc167808c26
scope.11.id=function:_should_wait_interval:109
scope.11.kind=function
scope.11.startLine=109
scope.11.endLine=115
scope.11.semanticHash=456624c5cba280dc
scope.12.id=function:_reset_timer_state:117
scope.12.kind=function
scope.12.startLine=117
scope.12.endLine=120
scope.12.semanticHash=126f9e817fd51102
scope.13.id=function:_resolve_modal_action:126
scope.13.kind=function
scope.13.startLine=126
scope.13.endLine=134
scope.13.semanticHash=6f0b044cb40fe78b
scope.14.id=function:_resolve_next_button_action:136
scope.14.kind=function
scope.14.startLine=136
scope.14.endLine=139
scope.14.semanticHash=817916ac382b563a
scope.15.id=function:auto_runner:next_action:141
scope.15.kind=function
scope.15.startLine=141
scope.15.endLine=165
scope.15.semanticHash=c0832c5428663fc8
]]
