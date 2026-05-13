local constants = require("src.config.content.constants")
local timing = require("src.config.gameplay.timing")
local turn_dispatch = require("src.turn.actions.action_dispatcher")
local number_utils = require("src.foundation.lang.number")
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
  local ports = state and state.gameplay_loop_ports or nil
  return ports and ports.output or output_state_adapter
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
  local resolved = state and (state._resolved_gameplay_loop_ports or state.gameplay_loop_ports) or nil
  local ui_sync_ports = type(resolved) == "table" and resolved.ui_sync or nil
  if type(ui_sync_ports) == "table" then
    return ui_sync_ports
  end
  return nil
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
