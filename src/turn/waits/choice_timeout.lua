local constants = require("src.config.content.constants")
local timing = require("src.config.gameplay.timing")
local number_utils = require("src.foundation.number")
local runtime_state = require("src.state.runtime")
local choice_contract = require("src.config.choice.contract")
local output_state_adapter = require("src.turn.output.state_adapter")
local deadlines = require("src.turn.deadlines")
local resolve_port = require("src.turn.loop.resolve_port")

local tick_choice_timeout = {}

local _tick_min_visible_payload = { mode = "tick_min_visible", elapsed_seconds = 0, min_visible_seconds = 0 }
local _tick_timeout_payload = { mode = "tick_timeout", elapsed_seconds = 0, timeout_seconds = 0, min_visible_seconds = 0 }

local function _resolve_output_ports(state)
  return resolve_port.resolve(state, "output", output_state_adapter)
end

local function _resolve_choice_owner_id(game, choice)
  local owner_role_id = choice_contract.resolve_owner_role_id(choice)
  if owner_role_id ~= nil and game.find_player_by_id then
    local player = game:find_player_by_id(owner_role_id)
    if player then
      return player.id
    end
  end
  local current = game.turn and game.turn.current_player_index or nil
  local player = current and game.players and game.players[current] or nil
  return player and player.id or nil
end

local function _ensure_action_actor_role_id(game, choice, action)
  if not action or action.actor_role_id ~= nil then
    return action
  end
  local owner_id = _resolve_choice_owner_id(game, choice)
  if owner_id ~= nil then
    action.actor_role_id = owner_id
  end
  return action
end

local function _assert_step_opts(game, opts)
  assert(game ~= nil, "missing game")
  assert(opts ~= nil, "missing opts")
  assert(opts.on_pending_choice ~= nil, "missing opts.on_pending_choice")
  assert(opts.is_choice_active ~= nil, "missing opts.is_choice_active")
  assert(opts.build_action ~= nil, "missing opts.build_action")
  assert(type(opts.dispatch_action_with_close_choice) == "function", "missing opts.dispatch_action_with_close_choice")
end

local function _resolve_timeout_seconds(game, state, opts)
  local output_ports = _resolve_output_ports(state)
  local timeout = constants.action_timeout_seconds or 0
  if type(opts.get_timeout_seconds) == "function" then
    local override = opts.get_timeout_seconds(game, state)
    if number_utils.is_numeric(override) then
      timeout = override
    end
  end
  return output_ports, timeout
end

local function _sync_pending_choice_ui(game, state, opts, output_ports)
  local pending = game.turn.pending_choice
  local active_choice = output_ports.get_pending_choice(state)
  if pending and (not active_choice or active_choice.id ~= pending.id) then
    output_ports.sync_pending_choice(state, pending)
    opts.on_pending_choice(state, pending)
  elseif not pending then
    output_ports.clear_pending_choice(state)
  end
  return pending, output_ports.get_pending_choice(state)
end

local function _resolve_missing_ui_warning(state, game, opts, pending, active_choice, ui_choice_active)
  local active = pending ~= nil or active_choice ~= nil
  local resolved_ui_gate = nil
  if active and active_choice and type(opts.resolve_choice_ui_state) == "function" then
    resolved_ui_gate = opts.resolve_choice_ui_state(game, state, active_choice)
  end
  local should_warn_missing_ui = active and active_choice and not ui_choice_active
  if type(resolved_ui_gate) == "table" then
    should_warn_missing_ui = resolved_ui_gate.should_warn == true
  end
  return active, should_warn_missing_ui
end

local function _maybe_warn_missing_ui(state, active_choice, should_warn_missing_ui)
  if not should_warn_missing_ui then
    return
  end
  runtime_state.log_once(
    state,
    "warn",
    "choice_runtime_without_ui_" .. tostring(active_choice.id),
    "[Eggy]",
    "runtime pending choice active without ui.choice_active",
    "choice_id=" .. tostring(active_choice.id),
    "kind=" .. tostring(active_choice.kind),
    "owner_role_id=" .. tostring(active_choice.owner_role_id),
    "route_key=" .. tostring(active_choice.route_key)
  )
end

local function _scope_for_choice(active_choice)
  if active_choice and active_choice.kind == "market_buy" then
    return "market_buy"
  end
  return "choice"
end

local function _sync_deadline_for_choice(state, active_choice, timeout)
  local scope = _scope_for_choice(active_choice)
  local other_scope = scope == "choice" and "market_buy" or "choice"
  if deadlines.is_active(state, other_scope) then
    deadlines.cancel(state, other_scope)
  end
  if not deadlines.is_active(state, scope) then
    deadlines.start(state, scope, {
      timeout_seconds = timeout,
      priority = 100,
    })
  end
end

local function _cancel_deadline_when_no_choice(state)
  deadlines.cancel(state, "choice")
  deadlines.cancel(state, "market_buy")
end

local function _reset_choice_tracking(state, output_ports)
  output_ports.set_pending_choice_elapsed(state, 0)
  output_ports.set_pending_choice_id(state, nil)
  _cancel_deadline_when_no_choice(state)
end

local function _sync_elapsed_choice_id(state, output_ports, active_choice)
  if output_ports.get_pending_choice_id(state) ~= active_choice.id then
    output_ports.set_pending_choice_elapsed(state, 0)
    output_ports.set_pending_choice_id(state, active_choice.id)
    deadlines.cancel(state, "choice")
    deadlines.cancel(state, "market_buy")
  end
end

local function _resolve_min_visible_seconds(game, state, active_choice, opts)
  local min_visible = timing.auto_decision_delay_seconds or 0
  if type(opts.get_min_visible_seconds) == "function" then
    local override_min_visible = opts.get_min_visible_seconds(game, state, active_choice)
    if number_utils.is_numeric(override_min_visible) and override_min_visible >= 0 then
      min_visible = override_min_visible
    end
  end
  return min_visible
end

local function _dispatch_choice_tick_action(game, state, choice, output_ports, opts, payload)
  local action = opts.build_action(game, state, choice, payload)
  if not action then
    return false
  end
  _ensure_action_actor_role_id(game, choice, action)
  output_ports.set_pending_choice_elapsed(state, 0)
  opts.dispatch_action_with_close_choice(game, state, action)
  return true
end

function tick_choice_timeout.step(game, state, dt, opts)
  _assert_step_opts(game, opts)
  local output_ports, timeout = _resolve_timeout_seconds(game, state, opts)
  if timeout <= 0 then
    _reset_choice_tracking(state, output_ports)
    return
  end
  local pending, active_choice = _sync_pending_choice_ui(game, state, opts, output_ports)
  local ui_choice_active = opts.is_choice_active(state) == true
  local active, should_warn_missing_ui = _resolve_missing_ui_warning(
    state, game, opts, pending, active_choice, ui_choice_active
  )
  _maybe_warn_missing_ui(state, active_choice, should_warn_missing_ui)
  if not active or not active_choice then
    _reset_choice_tracking(state, output_ports)
    return
  end
  _sync_elapsed_choice_id(state, output_ports, active_choice)
  _sync_deadline_for_choice(state, active_choice, timeout)
  local pending_choice_elapsed = output_ports.get_pending_choice_elapsed(state) + dt
  output_ports.set_pending_choice_elapsed(state, pending_choice_elapsed)
  local min_visible = _resolve_min_visible_seconds(game, state, active_choice, opts)
  if min_visible > 0 and pending_choice_elapsed >= min_visible then
    _tick_min_visible_payload.elapsed_seconds = pending_choice_elapsed
    _tick_min_visible_payload.min_visible_seconds = min_visible
    if _dispatch_choice_tick_action(game, state, active_choice, output_ports, opts, _tick_min_visible_payload) then
      return
    end
  end
  if pending_choice_elapsed >= timeout then
    _tick_timeout_payload.elapsed_seconds = pending_choice_elapsed
    _tick_timeout_payload.timeout_seconds = timeout
    _tick_timeout_payload.min_visible_seconds = min_visible
    local action = opts.build_action(game, state, active_choice, _tick_timeout_payload)
    if action ~= nil and action.type ~= "choice_force_skip" then
      _ensure_action_actor_role_id(game, active_choice, action)
      output_ports.set_pending_choice_elapsed(state, 0)
      opts.dispatch_action_with_close_choice(game, state, action)
      return
    end
    output_ports.set_pending_choice_elapsed(state, 0)
    deadlines.resolve_choice(game, state, active_choice, "tick_timeout")
  end
end

tick_choice_timeout._resolve_choice_owner_id = _resolve_choice_owner_id

return tick_choice_timeout

--[[ mutate4lua-manifest
version=2
projectHash=3b18689fe7247720
scope.0.id=chunk:src/turn/waits/choice_timeout.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=217
scope.0.semanticHash=fc23792ae00d2d3b
scope.1.id=function:_resolve_output_ports:15
scope.1.kind=function
scope.1.startLine=15
scope.1.endLine=17
scope.1.semanticHash=aebf133fe2f9be6a
scope.2.id=function:_resolve_choice_owner_id:19
scope.2.kind=function
scope.2.startLine=19
scope.2.endLine=30
scope.2.semanticHash=a7fa570a9218a3ed
scope.3.id=function:_ensure_action_actor_role_id:32
scope.3.kind=function
scope.3.startLine=32
scope.3.endLine=41
scope.3.semanticHash=3466035d9adbd902
scope.4.id=function:_assert_step_opts:43
scope.4.kind=function
scope.4.startLine=43
scope.4.endLine=50
scope.4.semanticHash=6679d4f16fd52371
scope.5.id=function:_resolve_timeout_seconds:52
scope.5.kind=function
scope.5.startLine=52
scope.5.endLine=62
scope.5.semanticHash=8561f71068611664
scope.6.id=function:_sync_pending_choice_ui:64
scope.6.kind=function
scope.6.startLine=64
scope.6.endLine=74
scope.6.semanticHash=4fcc940b9b66b803
scope.7.id=function:_resolve_missing_ui_warning:76
scope.7.kind=function
scope.7.startLine=76
scope.7.endLine=87
scope.7.semanticHash=6c9b9f8d2f6006b1
scope.8.id=function:_maybe_warn_missing_ui:89
scope.8.kind=function
scope.8.startLine=89
scope.8.endLine=104
scope.8.semanticHash=85d10413935d9ed9
scope.9.id=function:_scope_for_choice:106
scope.9.kind=function
scope.9.startLine=106
scope.9.endLine=111
scope.9.semanticHash=e6f4b028e48643eb
scope.10.id=function:_sync_deadline_for_choice:113
scope.10.kind=function
scope.10.startLine=113
scope.10.endLine=125
scope.10.semanticHash=2b5ec9a1be21abf0
scope.11.id=function:_cancel_deadline_when_no_choice:127
scope.11.kind=function
scope.11.startLine=127
scope.11.endLine=130
scope.11.semanticHash=68712ca609f58733
scope.12.id=function:_reset_choice_tracking:132
scope.12.kind=function
scope.12.startLine=132
scope.12.endLine=136
scope.12.semanticHash=276c64546f4fbecb
scope.13.id=function:_sync_elapsed_choice_id:138
scope.13.kind=function
scope.13.startLine=138
scope.13.endLine=145
scope.13.semanticHash=66c2f6d487b3d196
scope.14.id=function:_resolve_min_visible_seconds:147
scope.14.kind=function
scope.14.startLine=147
scope.14.endLine=156
scope.14.semanticHash=df41309b474210c1
scope.15.id=function:_dispatch_choice_tick_action:158
scope.15.kind=function
scope.15.startLine=158
scope.15.endLine=167
scope.15.semanticHash=6c03ee4aea3ffd41
scope.16.id=function:tick_choice_timeout.step:169
scope.16.kind=function
scope.16.startLine=169
scope.16.endLine=212
scope.16.semanticHash=f7f2fdef325c61f5
]]
