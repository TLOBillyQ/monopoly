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

local function _resolve_pending_choice(choice, game, state)
  return choice
    or (game and game.turn and game.turn.pending_choice)
    or (state and runtime_state.get_pending_choice(state))
    or nil
end

local function _positive_numeric(value)
  return number_utils.is_numeric(value) and value > 0 and value or nil
end

local function _resolve_scoped_timeout(kind)
  local scope_timeouts = timing.scope_timeouts
  if type(scope_timeouts) ~= "table" then return nil end
  return _positive_numeric(kind and scope_timeouts[kind])
    or _positive_numeric(scope_timeouts.choice)
end

function tick_timeout.resolve_choice_timeout_seconds(game, state, choice)
  local pending = _resolve_pending_choice(choice, game, state)
  local kind = pending and pending.kind or nil
  return _resolve_scoped_timeout(kind) or constants.action_timeout_seconds or 0
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
projectHash=f54048139ce83a7a
scope.0.id=chunk:src/turn/waits/timeout.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=274
scope.0.semanticHash=82e76c715a8be2fd
scope.0.lastMutatedAt=2026-06-01T07:24:27Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=survived
scope.0.lastMutationSites=18
scope.0.lastMutationKilled=15
scope.1.id=function:_resolve_pending_choice:14
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=19
scope.1.semanticHash=b8afe0f79a57ef06
scope.1.lastMutatedAt=2026-06-01T07:24:27Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=7
scope.1.lastMutationKilled=7
scope.2.id=function:_positive_numeric:21
scope.2.kind=function
scope.2.startLine=21
scope.2.endLine=23
scope.2.semanticHash=e7037d2b0bf90c31
scope.2.lastMutatedAt=2026-06-01T07:24:27Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=6
scope.2.lastMutationKilled=6
scope.3.id=function:_resolve_scoped_timeout:25
scope.3.kind=function
scope.3.startLine=25
scope.3.endLine=30
scope.3.semanticHash=ea5e079cf9346461
scope.3.lastMutatedAt=2026-06-01T07:24:27Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=6
scope.3.lastMutationKilled=6
scope.4.id=function:tick_timeout.resolve_choice_timeout_seconds:32
scope.4.kind=function
scope.4.startLine=32
scope.4.endLine=36
scope.4.semanticHash=c685632e83bb1cc6
scope.4.lastMutatedAt=2026-06-01T07:24:27Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=7
scope.4.lastMutationKilled=7
scope.5.id=function:_resolve_modal_ports:38
scope.5.kind=function
scope.5.startLine=38
scope.5.endLine=44
scope.5.semanticHash=3fc7011611601c56
scope.5.lastMutatedAt=2026-06-01T07:24:27Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=15
scope.5.lastMutationKilled=15
scope.6.id=function:anonymous@55:55
scope.6.kind=function
scope.6.startLine=55
scope.6.endLine=57
scope.6.semanticHash=66532c346ee9305e
scope.6.lastMutatedAt=2026-06-01T07:24:27Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=1
scope.6.lastMutationKilled=1
scope.7.id=function:_dispatch_action_with_close_choice:48
scope.7.kind=function
scope.7.startLine=48
scope.7.endLine=60
scope.7.semanticHash=2d381e67ede6b6b0
scope.7.lastMutatedAt=2026-06-01T07:24:27Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=5
scope.7.lastMutationKilled=5
scope.8.id=function:tick_timeout.resolve_modal_timeout_seconds:62
scope.8.kind=function
scope.8.startLine=62
scope.8.endLine=64
scope.8.semanticHash=2b30abd41d2df9ba
scope.8.lastMutatedAt=2026-06-01T07:24:27Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=1
scope.8.lastMutationKilled=1
scope.9.id=function:tick_timeout.step_choice_timeout:68
scope.9.kind=function
scope.9.startLine=68
scope.9.endLine=78
scope.9.semanticHash=6aaae9b88960f48a
scope.9.lastMutatedAt=2026-06-01T07:24:27Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=1
scope.9.lastMutationKilled=1
scope.10.id=function:_resolve_modal_timeout:80
scope.10.kind=function
scope.10.startLine=80
scope.10.endLine=89
scope.10.semanticHash=d76c98460a1af223
scope.10.lastMutatedAt=2026-06-01T07:24:27Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=7
scope.10.lastMutationKilled=7
scope.11.id=function:_resolve_modal_output_ports:91
scope.11.kind=function
scope.11.startLine=91
scope.11.endLine=93
scope.11.semanticHash=5c25aa75d788384c
scope.11.lastMutatedAt=2026-06-01T07:24:27Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=1
scope.11.lastMutationKilled=1
scope.12.id=function:_assert_modal_opts:95
scope.12.kind=function
scope.12.startLine=95
scope.12.endLine=100
scope.12.semanticHash=7115e6f8fe8af5f3
scope.12.lastMutatedAt=2026-06-01T07:24:27Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=4
scope.12.lastMutationKilled=4
scope.13.id=function:_resolve_modal_ref:106
scope.13.kind=function
scope.13.startLine=106
scope.13.endLine=114
scope.13.semanticHash=53eced8208470336
scope.13.lastMutatedAt=2026-06-01T07:24:27Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=5
scope.13.lastMutationKilled=5
scope.14.id=function:_update_modal_elapsed:116
scope.14.kind=function
scope.14.startLine=116
scope.14.endLine=122
scope.14.semanticHash=0bc180b92c8be787
scope.14.lastMutatedAt=2026-06-01T07:24:27Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=passed
scope.14.lastMutationSites=5
scope.14.lastMutationKilled=5
scope.15.id=function:_handle_modal_timeout:124
scope.15.kind=function
scope.15.startLine=124
scope.15.endLine=129
scope.15.semanticHash=b750a2b2c4c40b01
scope.15.lastMutatedAt=2026-06-01T07:24:27Z
scope.15.lastMutationLane=behavior
scope.15.lastMutationStatus=passed
scope.15.lastMutationSites=3
scope.15.lastMutationKilled=3
scope.16.id=function:tick_timeout.step_modal_timeout:131
scope.16.kind=function
scope.16.startLine=131
scope.16.endLine=148
scope.16.semanticHash=73519947da2d7e66
scope.16.lastMutatedAt=2026-06-01T07:24:27Z
scope.16.lastMutationLane=behavior
scope.16.lastMutationStatus=passed
scope.16.lastMutationSites=13
scope.16.lastMutationKilled=13
scope.17.id=function:_resolve_ui_sync_ports:150
scope.17.kind=function
scope.17.startLine=150
scope.17.endLine=152
scope.17.semanticHash=d27db4c53fb645d4
scope.17.lastMutatedAt=2026-06-01T07:24:27Z
scope.17.lastMutationLane=behavior
scope.17.lastMutationStatus=passed
scope.17.lastMutationSites=1
scope.17.lastMutationKilled=1
scope.18.id=function:anonymous@156:156
scope.18.kind=function
scope.18.startLine=156
scope.18.endLine=158
scope.18.semanticHash=6de186ef7e399dbb
scope.18.lastMutatedAt=2026-06-01T07:24:27Z
scope.18.lastMutationLane=behavior
scope.18.lastMutationStatus=passed
scope.18.lastMutationSites=1
scope.18.lastMutationKilled=1
scope.19.id=function:anonymous@159:159
scope.19.kind=function
scope.19.startLine=159
scope.19.endLine=161
scope.19.semanticHash=1691827c0fb604b4
scope.19.lastMutatedAt=2026-06-01T07:24:27Z
scope.19.lastMutationLane=behavior
scope.19.lastMutationStatus=passed
scope.19.lastMutationSites=2
scope.19.lastMutationKilled=2
scope.20.id=function:anonymous@162:162
scope.20.kind=function
scope.20.startLine=162
scope.20.endLine=164
scope.20.semanticHash=84c62125408e56a8
scope.20.lastMutatedAt=2026-06-01T07:24:27Z
scope.20.lastMutationLane=behavior
scope.20.lastMutationStatus=passed
scope.20.lastMutationSites=1
scope.20.lastMutationKilled=1
scope.21.id=function:anonymous@167:167
scope.21.kind=function
scope.21.startLine=167
scope.21.endLine=169
scope.21.semanticHash=10f653d85e8c16b7
scope.21.lastMutatedAt=2026-06-01T07:24:27Z
scope.21.lastMutationLane=behavior
scope.21.lastMutationStatus=passed
scope.21.lastMutationSites=1
scope.21.lastMutationKilled=1
scope.22.id=function:anonymous@170:170
scope.22.kind=function
scope.22.startLine=170
scope.22.endLine=176
scope.22.semanticHash=443d87f14cd3a996
scope.22.lastMutatedAt=2026-06-01T07:24:27Z
scope.22.lastMutationLane=behavior
scope.22.lastMutationStatus=passed
scope.22.lastMutationSites=3
scope.22.lastMutationKilled=3
scope.23.id=function:tick_timeout.default_policy:196
scope.23.kind=function
scope.23.startLine=196
scope.23.endLine=198
scope.23.semanticHash=e763f9ffa5e64cb0
scope.23.lastMutatedAt=2026-06-01T07:24:27Z
scope.23.lastMutationLane=behavior
scope.23.lastMutationStatus=passed
scope.23.lastMutationSites=1
scope.23.lastMutationKilled=1
scope.24.id=function:anonymous@211:211
scope.24.kind=function
scope.24.startLine=211
scope.24.endLine=216
scope.24.semanticHash=d163790e60343dde
scope.24.lastMutatedAt=2026-06-01T07:24:27Z
scope.24.lastMutationLane=behavior
scope.24.lastMutationStatus=passed
scope.24.lastMutationSites=5
scope.24.lastMutationKilled=5
scope.25.id=function:anonymous@218:218
scope.25.kind=function
scope.25.startLine=218
scope.25.endLine=224
scope.25.semanticHash=c105431189db8c58
scope.25.lastMutatedAt=2026-06-01T07:24:27Z
scope.25.lastMutationLane=behavior
scope.25.lastMutationStatus=survived
scope.25.lastMutationSites=6
scope.25.lastMutationKilled=5
scope.26.id=function:anonymous@226:226
scope.26.kind=function
scope.26.startLine=226
scope.26.endLine=234
scope.26.semanticHash=fa33c5333a6c2cd6
scope.26.lastMutatedAt=2026-06-01T07:24:27Z
scope.26.lastMutationLane=behavior
scope.26.lastMutationStatus=survived
scope.26.lastMutationSites=8
scope.26.lastMutationKilled=5
scope.27.id=function:tick_timeout.step_default_choice:236
scope.27.kind=function
scope.27.startLine=236
scope.27.endLine=242
scope.27.semanticHash=ddc491fdf38330f0
scope.27.lastMutatedAt=2026-06-01T07:24:27Z
scope.27.lastMutationLane=behavior
scope.27.lastMutationStatus=passed
scope.27.lastMutationSites=2
scope.27.lastMutationKilled=2
scope.28.id=function:anonymous@249:249
scope.28.kind=function
scope.28.startLine=249
scope.28.endLine=252
scope.28.semanticHash=9bcfbd3394e3a2c8
scope.28.lastMutatedAt=2026-06-01T07:24:27Z
scope.28.lastMutationLane=behavior
scope.28.lastMutationStatus=passed
scope.28.lastMutationSites=3
scope.28.lastMutationKilled=3
scope.29.id=function:anonymous@254:254
scope.29.kind=function
scope.29.startLine=254
scope.29.endLine=258
scope.29.semanticHash=1889378a57b1ceba
scope.29.lastMutatedAt=2026-06-01T07:24:27Z
scope.29.lastMutationLane=behavior
scope.29.lastMutationStatus=passed
scope.29.lastMutationSites=3
scope.29.lastMutationKilled=3
scope.30.id=function:anonymous@260:260
scope.30.kind=function
scope.30.startLine=260
scope.30.endLine=265
scope.30.semanticHash=18ee01ce737e220f
scope.30.lastMutatedAt=2026-06-01T07:24:27Z
scope.30.lastMutationLane=behavior
scope.30.lastMutationStatus=passed
scope.30.lastMutationSites=1
scope.30.lastMutationKilled=1
scope.31.id=function:tick_timeout.step_default_modal:267
scope.31.kind=function
scope.31.startLine=267
scope.31.endLine=271
scope.31.semanticHash=9a8923a69eb0a8c0
scope.31.lastMutatedAt=2026-06-01T07:24:27Z
scope.31.lastMutationLane=behavior
scope.31.lastMutationStatus=passed
scope.31.lastMutationSites=1
scope.31.lastMutationKilled=1
]]
