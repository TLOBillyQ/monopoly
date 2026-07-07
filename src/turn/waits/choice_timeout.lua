local constants = require("src.config.content.constants")
local timing = require("src.config.gameplay.timing")
local number_utils = require("src.foundation.number")
local output_state_adapter = require("src.turn.output.state_adapter")
local deadlines = require("src.turn.deadlines")
local resolve_port = require("src.turn.loop.resolve_port")
local choice_dispatch = require("src.turn.waits.choice_dispatch")
local choice_tracking = require("src.turn.waits.choice_tracking")
local choice_ui_sync = require("src.turn.waits.choice_ui_sync")

local tick_choice_timeout = {}

local _tick_min_visible_payload = { mode = "tick_min_visible", elapsed_seconds = 0, min_visible_seconds = 0 }
local _tick_timeout_payload = { mode = "tick_timeout", elapsed_seconds = 0, timeout_seconds = 0, min_visible_seconds = 0 }

local function _resolve_output_ports(state)
  return resolve_port.resolve(state, "output", output_state_adapter)
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

local function _maybe_dispatch_min_visible(game, state, active_choice, output_ports, opts, pending_choice_elapsed, min_visible)
  if min_visible > 0 and pending_choice_elapsed >= min_visible then
    _tick_min_visible_payload.elapsed_seconds = pending_choice_elapsed
    _tick_min_visible_payload.min_visible_seconds = min_visible
    return choice_dispatch.dispatch_choice_tick_action(
      game, state, active_choice, output_ports, opts, _tick_min_visible_payload
    )
  end
  return false
end

local function _maybe_resolve_timeout(game, state, active_choice, output_ports, opts, pending_choice_elapsed, timeout, min_visible)
  if pending_choice_elapsed < timeout then
    return
  end
  _tick_timeout_payload.elapsed_seconds = pending_choice_elapsed
  _tick_timeout_payload.timeout_seconds = timeout
  _tick_timeout_payload.min_visible_seconds = min_visible
  local action = opts.build_action(game, state, active_choice, _tick_timeout_payload)
  if action ~= nil and action.type ~= "choice_force_skip" then
    choice_dispatch.ensure_action_actor_role_id(game, active_choice, action)
    output_ports.set_pending_choice_elapsed(state, 0)
    opts.dispatch_action_with_close_choice(game, state, action)
    return
  end
  output_ports.set_pending_choice_elapsed(state, 0)
  deadlines.resolve_choice(game, state, active_choice, "tick_timeout")
end

function tick_choice_timeout.step(game, state, dt, opts)
  _assert_step_opts(game, opts)
  local output_ports, timeout = _resolve_timeout_seconds(game, state, opts)
  if timeout <= 0 then
    choice_tracking.reset_choice_tracking(state, output_ports)
    return
  end
  local pending, active_choice = choice_ui_sync.sync_pending_choice_ui(game, state, opts, output_ports)
  local ui_choice_active = opts.is_choice_active(state) == true
  local active, should_warn_missing_ui = choice_ui_sync.resolve_missing_ui_warning(
    state, game, opts, pending, active_choice, ui_choice_active
  )
  choice_ui_sync.maybe_warn_missing_ui(state, active_choice, should_warn_missing_ui)
  if not active or not active_choice then
    choice_tracking.reset_choice_tracking(state, output_ports)
    return
  end
  choice_tracking.sync_elapsed_choice_id(state, output_ports, active_choice)
  choice_tracking.sync_deadline_for_choice(state, active_choice, timeout)
  local pending_choice_elapsed = output_ports.get_pending_choice_elapsed(state) + dt
  output_ports.set_pending_choice_elapsed(state, pending_choice_elapsed)
  local min_visible = _resolve_min_visible_seconds(game, state, active_choice, opts)
  if _maybe_dispatch_min_visible(game, state, active_choice, output_ports, opts, pending_choice_elapsed, min_visible) then
    return
  end
  _maybe_resolve_timeout(game, state, active_choice, output_ports, opts, pending_choice_elapsed, timeout, min_visible)
end

tick_choice_timeout._resolve_choice_owner_id = choice_dispatch.resolve_choice_owner_id

return tick_choice_timeout

--[[ mutate4lua-manifest
version=2
projectHash=9a85392b71e519fb
scope.0.id=chunk:src/turn/waits/choice_timeout.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=112
scope.0.semanticHash=330b41153aab7e40
scope.0.lastMutatedAt=2026-07-07T02:48:34Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=survived
scope.0.lastMutationSites=16
scope.0.lastMutationKilled=11
scope.1.id=function:_resolve_output_ports:16
scope.1.kind=function
scope.1.startLine=16
scope.1.endLine=18
scope.1.semanticHash=aebf133fe2f9be6a
scope.1.lastMutatedAt=2026-07-07T02:48:34Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=1
scope.1.lastMutationKilled=1
scope.2.id=function:_assert_step_opts:20
scope.2.kind=function
scope.2.startLine=20
scope.2.endLine=27
scope.2.semanticHash=6679d4f16fd52371
scope.2.lastMutatedAt=2026-07-07T02:48:34Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=6
scope.2.lastMutationKilled=6
scope.3.id=function:_resolve_timeout_seconds:29
scope.3.kind=function
scope.3.startLine=29
scope.3.endLine=39
scope.3.semanticHash=8561f71068611664
scope.3.lastMutatedAt=2026-07-07T02:48:34Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=8
scope.3.lastMutationKilled=8
scope.4.id=function:_resolve_min_visible_seconds:41
scope.4.kind=function
scope.4.startLine=41
scope.4.endLine=50
scope.4.semanticHash=df41309b474210c1
scope.4.lastMutatedAt=2026-07-07T02:48:34Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=10
scope.4.lastMutationKilled=10
scope.5.id=function:_maybe_dispatch_min_visible:52
scope.5.kind=function
scope.5.startLine=52
scope.5.endLine=61
scope.5.semanticHash=d9cac8a4a231b655
scope.5.lastMutatedAt=2026-07-07T02:48:34Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=6
scope.5.lastMutationKilled=6
scope.6.id=function:_maybe_resolve_timeout:63
scope.6.kind=function
scope.6.startLine=63
scope.6.endLine=79
scope.6.semanticHash=6f9a14cbc117c2c2
scope.6.lastMutatedAt=2026-07-07T02:48:34Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=11
scope.6.lastMutationKilled=11
scope.7.id=function:tick_choice_timeout.step:81
scope.7.kind=function
scope.7.startLine=81
scope.7.endLine=107
scope.7.semanticHash=370add683ef1d3df
scope.7.lastMutatedAt=2026-07-07T02:48:34Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=23
scope.7.lastMutationKilled=23
]]
