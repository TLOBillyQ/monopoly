local constants = require("src.config.content.constants")
local timing = require("src.config.gameplay.timing")
local turn_dispatch = require("src.turn.actions.action_dispatcher")
local resolve_port = require("src.turn.loop.resolve_port")
local number_utils = require("src.foundation.number")
local choice_auto_policy = require("src.turn.policies.choice_auto")
local tick_ui_gate = require("src.turn.waits.ui_gate")
local tick_choice_timeout = require("src.turn.waits.choice_timeout")
local output_state_adapter = require("src.turn.output.state_adapter")
local runtime_state = require("src.state.runtime")

local tick_timeout = {}

function tick_timeout.resolve_choice_timeout_seconds(game, state, choice)
  local pending_choice = choice
    or (game and game.turn and game.turn.pending_choice)
    or (state and runtime_state.get_pending_choice(state))
    or nil
  local kind = pending_choice and pending_choice.kind or nil
  local scope_timeouts = timing.scope_timeouts
  if type(scope_timeouts) == "table" then
    local scoped = kind and scope_timeouts[kind] or nil
    if number_utils.is_numeric(scoped) and scoped > 0 then
      return scoped
    end
    local default_choice = scope_timeouts.choice
    if number_utils.is_numeric(default_choice) and default_choice > 0 then
      return default_choice
    end
  end
  return constants.action_timeout_seconds or 0
end

local function _resolve_modal_ports(state)
  local modal_ports = state and state.gameplay_loop_ports and state.gameplay_loop_ports.modal or nil
  if type(modal_ports) ~= "table" then
    return nil
  end
  return (type(modal_ports.close_choice_modal) == "function" or type(modal_ports.close_popup) == "function") and modal_ports or nil
end

local _dispatch_close_opts = { on_close_choice = nil }
local _cached_dispatch_modal_ref = nil
local function _dispatch_action_with_close_choice(game, state, action)
  local modal_ports = _resolve_modal_ports(state)
  if not modal_ports then
    return turn_dispatch.dispatch_action(game, state, action, nil)
  end
  if _cached_dispatch_modal_ref ~= modal_ports then
    _cached_dispatch_modal_ref = modal_ports
    _dispatch_close_opts.on_close_choice = function(ctx)
      modal_ports.close_choice_modal(ctx)
    end
  end
  return turn_dispatch.dispatch_action(game, state, action, _dispatch_close_opts)
end

function tick_timeout.resolve_modal_timeout_seconds(_, state, ui_sync_ports)
  return tick_ui_gate.resolve_modal_timeout_seconds(state, ui_sync_ports)
end

tick_timeout.resolve_modal_gate = tick_ui_gate.resolve_ui_gate

function tick_timeout.step_choice_timeout(game, state, dt, opts)
  return tick_choice_timeout.step(game, state, dt, {
    on_pending_choice = opts.on_pending_choice,
    is_choice_active = opts.is_choice_active,
    resolve_choice_ui_state = opts.resolve_choice_ui_state,
    build_action = opts.build_action,
    get_timeout_seconds = opts.get_timeout_seconds,
    get_min_visible_seconds = opts.get_min_visible_seconds,
    dispatch_action_with_close_choice = _dispatch_action_with_close_choice,
  })
end

local function _resolve_modal_timeout(opts, state)
  local timeout = constants.action_timeout_seconds or 0
  if opts and opts.get_timeout_seconds then
    local override = opts.get_timeout_seconds(state)
    if override ~= nil and number_utils.is_numeric(override) then
      timeout = override
    end
  end
  return timeout
end

local function _resolve_modal_output_ports(state)
  return resolve_port.resolve(state, "output", output_state_adapter)
end

local function _assert_modal_opts(opts)
  assert(opts ~= nil, "missing opts")
  assert(opts.is_active ~= nil, "missing opts.is_active")
  assert(opts.on_timeout ~= nil, "missing opts.on_timeout")
  assert(opts.get_ref ~= nil, "missing opts.get_ref")
end

local _modal_timer_reset = { ref = nil, elapsed_seconds = 0 }
local _modal_timer_update = { ref = nil, elapsed_seconds = 0 }
local _modal_timer_empty = {}

local function _resolve_modal_ref(output_ports, state, opts)
  local ref = assert(opts.get_ref(state), "missing modal ref")
  if output_ports.get_modal_ref(state) ~= ref then
    _modal_timer_reset.ref = ref
    _modal_timer_reset.elapsed_seconds = 0
    output_ports.sync_modal_timer(state, _modal_timer_reset)
  end
  return ref
end

local function _update_modal_elapsed(output_ports, state, ref, dt)
  local next_elapsed = output_ports.get_modal_elapsed(state) + (dt or 0)
  _modal_timer_update.ref = ref
  _modal_timer_update.elapsed_seconds = next_elapsed
  output_ports.sync_modal_timer(state, _modal_timer_update)
  return next_elapsed
end

local function _handle_modal_timeout(output_ports, state, ref, on_timeout)
  _modal_timer_reset.ref = ref
  _modal_timer_reset.elapsed_seconds = 0
  output_ports.sync_modal_timer(state, _modal_timer_reset)
  on_timeout(state)
end

function tick_timeout.step_modal_timeout(state, dt, opts)
  local output_ports = _resolve_modal_output_ports(state)
  local timeout = _resolve_modal_timeout(opts, state)
  if timeout <= 0 then
    output_ports.sync_modal_timer(state, _modal_timer_empty)
    return
  end
  _assert_modal_opts(opts)
  if not opts.is_active(state) then
    output_ports.sync_modal_timer(state, _modal_timer_empty)
    return
  end
  local ref = _resolve_modal_ref(output_ports, state, opts)
  local next_elapsed = _update_modal_elapsed(output_ports, state, ref, dt)
  if next_elapsed >= timeout then
    _handle_modal_timeout(output_ports, state, ref, opts.on_timeout)
  end
end

local function _resolve_ui_sync_ports(state)
  return resolve_port.resolve(state, "ui_sync", nil)
end

local default_policy = {
  choice = {
    get_timeout_seconds = function(game, state)
      return tick_timeout.resolve_choice_timeout_seconds(game, state)
    end,
    get_min_visible_seconds = function()
      return timing.auto_decision_delay_seconds or 0
    end,
    build_action = function(game_ctx, state_ctx, choice, action_ctx)
      return choice_auto_policy.decide(game_ctx, state_ctx, choice, action_ctx)
    end,
  },
  modal = {
    get_timeout_seconds = function(game, state)
      return tick_timeout.resolve_modal_timeout_seconds(game, state)
    end,
    on_timeout = function(ctx)
      local ports = _resolve_modal_ports(ctx)
      if ports and ports.close_popup then
        ports.close_popup(ctx)
        return
      end
    end,
  },
}

local function _clone_policy(policy)
  local copied = {}
  for key, value in pairs(policy) do
    if type(value) == "table" then
      local item = {}
      for sub_key, sub_value in pairs(value) do
        item[sub_key] = sub_value
      end
      copied[key] = item
    else
      copied[key] = value
    end
  end
  return copied
end

function tick_timeout.default_policy()
  return _clone_policy(default_policy)
end

local _choice_ui_fallback = { route_key = nil, should_warn = false }

local _default_choice_opts = {
  _game = nil,
  _ui_sync_ports = nil,
  dispatch_action_with_close_choice = _dispatch_action_with_close_choice,
  build_action = default_policy.choice.build_action,
  get_timeout_seconds = default_policy.choice.get_timeout_seconds,
  get_min_visible_seconds = default_policy.choice.get_min_visible_seconds,
}

_default_choice_opts.on_pending_choice = function(state_ctx, pending)
  local ports = _default_choice_opts._ui_sync_ports
  if ports and type(ports.on_pending_choice) == "function" then
    return ports.on_pending_choice(_default_choice_opts._game, state_ctx, pending)
  end
end

_default_choice_opts.is_choice_active = function(ctx)
  local ports = _default_choice_opts._ui_sync_ports
  if ports and type(ports.is_choice_active) == "function" then
    return ports.is_choice_active(ctx)
  end
  return ctx.pending_choice ~= nil
end

_default_choice_opts.resolve_choice_ui_state = function(game_ctx, state_ctx, choice)
  local ports = _default_choice_opts._ui_sync_ports
  if ports and type(ports.resolve_choice_ui_state) == "function" then
    return ports.resolve_choice_ui_state(game_ctx, state_ctx, choice)
  end
  _choice_ui_fallback.route_key = choice and choice.route_key or nil
  _choice_ui_fallback.should_warn = false
  return _choice_ui_fallback
end

function tick_timeout.step_default_choice(game, state, dt)
  _default_choice_opts._game = game
  _default_choice_opts._ui_sync_ports = _resolve_ui_sync_ports(state)
  tick_choice_timeout.step(game, state, dt, _default_choice_opts)
  _default_choice_opts._game = nil
  _default_choice_opts._ui_sync_ports = nil
end

local _default_modal_opts = {
  _game = nil,
  on_timeout = default_policy.modal.on_timeout,
}

_default_modal_opts.is_active = function(ctx)
  local gate = tick_ui_gate.resolve_ui_gate(ctx)
  return gate.popup_active == true
end

_default_modal_opts.get_ref = function(ctx)
  local gate = tick_ui_gate.resolve_ui_gate(ctx)
  assert(gate.popup_active, "popup not active")
  return assert(gate.popup_seq, "missing popup_seq")
end

_default_modal_opts.get_timeout_seconds = function(state_ctx)
  return default_policy.modal.get_timeout_seconds(
    _default_modal_opts._game,
    state_ctx
  )
end

function tick_timeout.step_default_modal(game, state, dt)
  _default_modal_opts._game = game
  tick_timeout.step_modal_timeout(state, dt, _default_modal_opts)
  _default_modal_opts._game = nil
end

return tick_timeout

--[[ mutate4lua-manifest
version=2
projectHash=e03821e8062027f5
scope.0.id=chunk:src/turn/waits/timeout.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=270
scope.0.semanticHash=c66359b67316b332
scope.1.id=function:tick_timeout.resolve_choice_timeout_seconds:14
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=32
scope.1.semanticHash=4edad81517c07229
scope.2.id=function:_resolve_modal_ports:34
scope.2.kind=function
scope.2.startLine=34
scope.2.endLine=40
scope.2.semanticHash=3fc7011611601c56
scope.3.id=function:anonymous@51:51
scope.3.kind=function
scope.3.startLine=51
scope.3.endLine=53
scope.3.semanticHash=66532c346ee9305e
scope.4.id=function:_dispatch_action_with_close_choice:44
scope.4.kind=function
scope.4.startLine=44
scope.4.endLine=56
scope.4.semanticHash=2d381e67ede6b6b0
scope.5.id=function:tick_timeout.resolve_modal_timeout_seconds:58
scope.5.kind=function
scope.5.startLine=58
scope.5.endLine=60
scope.5.semanticHash=2b30abd41d2df9ba
scope.6.id=function:tick_timeout.step_choice_timeout:64
scope.6.kind=function
scope.6.startLine=64
scope.6.endLine=74
scope.6.semanticHash=6aaae9b88960f48a
scope.7.id=function:_resolve_modal_timeout:76
scope.7.kind=function
scope.7.startLine=76
scope.7.endLine=85
scope.7.semanticHash=d76c98460a1af223
scope.8.id=function:_resolve_modal_output_ports:87
scope.8.kind=function
scope.8.startLine=87
scope.8.endLine=89
scope.8.semanticHash=5c25aa75d788384c
scope.9.id=function:_assert_modal_opts:91
scope.9.kind=function
scope.9.startLine=91
scope.9.endLine=96
scope.9.semanticHash=7115e6f8fe8af5f3
scope.10.id=function:_resolve_modal_ref:102
scope.10.kind=function
scope.10.startLine=102
scope.10.endLine=110
scope.10.semanticHash=53eced8208470336
scope.11.id=function:_update_modal_elapsed:112
scope.11.kind=function
scope.11.startLine=112
scope.11.endLine=118
scope.11.semanticHash=0bc180b92c8be787
scope.12.id=function:_handle_modal_timeout:120
scope.12.kind=function
scope.12.startLine=120
scope.12.endLine=125
scope.12.semanticHash=b750a2b2c4c40b01
scope.13.id=function:tick_timeout.step_modal_timeout:127
scope.13.kind=function
scope.13.startLine=127
scope.13.endLine=144
scope.13.semanticHash=73519947da2d7e66
scope.14.id=function:_resolve_ui_sync_ports:146
scope.14.kind=function
scope.14.startLine=146
scope.14.endLine=148
scope.14.semanticHash=d27db4c53fb645d4
scope.15.id=function:anonymous@152:152
scope.15.kind=function
scope.15.startLine=152
scope.15.endLine=154
scope.15.semanticHash=6de186ef7e399dbb
scope.16.id=function:anonymous@155:155
scope.16.kind=function
scope.16.startLine=155
scope.16.endLine=157
scope.16.semanticHash=1691827c0fb604b4
scope.17.id=function:anonymous@158:158
scope.17.kind=function
scope.17.startLine=158
scope.17.endLine=160
scope.17.semanticHash=84c62125408e56a8
scope.18.id=function:anonymous@163:163
scope.18.kind=function
scope.18.startLine=163
scope.18.endLine=165
scope.18.semanticHash=10f653d85e8c16b7
scope.19.id=function:anonymous@166:166
scope.19.kind=function
scope.19.startLine=166
scope.19.endLine=172
scope.19.semanticHash=443d87f14cd3a996
scope.20.id=function:tick_timeout.default_policy:192
scope.20.kind=function
scope.20.startLine=192
scope.20.endLine=194
scope.20.semanticHash=e763f9ffa5e64cb0
scope.21.id=function:anonymous@207:207
scope.21.kind=function
scope.21.startLine=207
scope.21.endLine=212
scope.21.semanticHash=d163790e60343dde
scope.22.id=function:anonymous@214:214
scope.22.kind=function
scope.22.startLine=214
scope.22.endLine=220
scope.22.semanticHash=c105431189db8c58
scope.23.id=function:anonymous@222:222
scope.23.kind=function
scope.23.startLine=222
scope.23.endLine=230
scope.23.semanticHash=fa33c5333a6c2cd6
scope.24.id=function:tick_timeout.step_default_choice:232
scope.24.kind=function
scope.24.startLine=232
scope.24.endLine=238
scope.24.semanticHash=ddc491fdf38330f0
scope.25.id=function:anonymous@245:245
scope.25.kind=function
scope.25.startLine=245
scope.25.endLine=248
scope.25.semanticHash=9bcfbd3394e3a2c8
scope.26.id=function:anonymous@250:250
scope.26.kind=function
scope.26.startLine=250
scope.26.endLine=254
scope.26.semanticHash=1889378a57b1ceba
scope.27.id=function:anonymous@256:256
scope.27.kind=function
scope.27.startLine=256
scope.27.endLine=261
scope.27.semanticHash=18ee01ce737e220f
scope.28.id=function:tick_timeout.step_default_modal:263
scope.28.kind=function
scope.28.startLine=263
scope.28.endLine=267
scope.28.semanticHash=9a8923a69eb0a8c0
]]
