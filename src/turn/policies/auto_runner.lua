local Class = require("src.foundation.class")

local choice_auto_policy = require("src.turn.policies.choice_auto")
local choice_contract = require("src.config.choice.contract")
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

local function _env_pending_choice(env)
  return env and env.pending_choice or nil
end

local function _env_actor_role_id(env)
  return env and (env.current_player_id or env.current_player_index) or nil
end

local function _resolve_choice_actor_role_id(env)
  local choice = _env_pending_choice(env)
  local owner_role_id = choice_contract.resolve_owner_role_id(choice)
  if owner_role_id ~= nil then
    return owner_role_id
  end
  return _env_actor_role_id(env)
end

local _choice_ctx = { mode = "wait_choice" }

local function _choice_env_ready(env)
  return env and env.pending_choice and env.game
end

local function _resolve_choice_action(env)
  if not _choice_env_ready(env) then
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

local function _env_choice_id(env)
  local choice = _env_pending_choice(env)
  return choice and choice.id or nil
end

local function _sync_wait_signature(self, env)
  local actor_role_id = _env_actor_role_id(env)
  local wait_kind = _resolve_wait_kind(env)
  local choice_id = _env_choice_id(env)
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
  if env.current_player_computer_controlled ~= true then
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
version=4
projectHash=675e8156efc297d0
scope.0.id=chunk:src/turn/policies/auto_runner.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=186
scope.0.semanticHash=fe2d80f6d28ae920
scope.1.id=function:auto_runner:init
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=19
scope.1.semanticHash=cd0b8834980b12e3
scope.2.id=function:auto_runner:set_enabled
scope.2.kind=function
scope.2.startLine=22
scope.2.endLine=25
scope.2.semanticHash=d9865bc65df52544
scope.3.id=function:auto_runner:reset_timer
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=34
scope.3.semanticHash=42520278bb4906b3
scope.4.id=function:_env_pending_choice
scope.4.kind=function
scope.4.startLine=36
scope.4.endLine=38
scope.4.semanticHash=616a2ca60599c94f
scope.5.id=function:_env_actor_role_id
scope.5.kind=function
scope.5.startLine=40
scope.5.endLine=42
scope.5.semanticHash=d692619e49063104
scope.6.id=function:_resolve_choice_actor_role_id
scope.6.kind=function
scope.6.startLine=44
scope.6.endLine=51
scope.6.semanticHash=a5c974aa9d19c82f
scope.7.id=function:_choice_env_ready
scope.7.kind=function
scope.7.startLine=55
scope.7.endLine=57
scope.7.semanticHash=d593bec6fe5e2543
scope.8.id=function:_resolve_choice_action
scope.8.kind=function
scope.8.startLine=59
scope.8.endLine=68
scope.8.semanticHash=1fb33f9b3e61b6fd
scope.9.id=function:_resolve_wait_kind
scope.9.kind=function
scope.9.startLine=70
scope.9.endLine=78
scope.9.semanticHash=412bd6d44e161720
scope.10.id=function:_resolve_interval_seconds
scope.10.kind=function
scope.10.startLine=80
scope.10.endLine=86
scope.10.semanticHash=923d900a357c9cc9
scope.11.id=function:_wait_signature_changed
scope.11.kind=function
scope.11.startLine=88
scope.11.endLine=92
scope.11.semanticHash=97ba04fcc4b62532
scope.12.id=function:_env_choice_id
scope.12.kind=function
scope.12.startLine=94
scope.12.endLine=97
scope.12.semanticHash=9225cfe7b87d962b
scope.13.id=function:_sync_wait_signature
scope.13.kind=function
scope.13.startLine=99
scope.13.endLine=111
scope.13.semanticHash=3344af619983d3c2
scope.14.id=function:_should_skip_action
scope.14.kind=function
scope.14.startLine=113
scope.14.endLine=125
scope.14.semanticHash=cbf1e77e756b5e66
scope.15.id=function:_should_wait_interval
scope.15.kind=function
scope.15.startLine=127
scope.15.endLine=133
scope.15.semanticHash=0549d0a3d1dc32cd
scope.16.id=function:_reset_timer_state
scope.16.kind=function
scope.16.startLine=135
scope.16.endLine=138
scope.16.semanticHash=710dce099b6f2faa
scope.17.id=function:_resolve_modal_action
scope.17.kind=function
scope.17.startLine=144
scope.17.endLine=152
scope.17.semanticHash=134ed3e6cf44f18c
scope.18.id=function:_resolve_next_button_action
scope.18.kind=function
scope.18.startLine=154
scope.18.endLine=157
scope.18.semanticHash=16ff333915d2cf9e
scope.19.id=function:auto_runner:next_action
scope.19.kind=function
scope.19.startLine=159
scope.19.endLine=183
scope.19.semanticHash=551889539015e871
]]
