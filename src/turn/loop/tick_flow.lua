local gameplay_loop_runtime = require("src.turn.loop.runtime")
local turn_role_control_policy = require("src.turn.policies.role_control")
local auto_context = require("src.turn.policies.auto_context")
local tick_steps = require("src.turn.loop.tick_steps")
local landing_visual_hold = require("src.state.visual_hold")
local runtime_state = require("src.state.runtime")
local wait_callbacks = require("src.turn.waits.callback_registry")
local blocking = require("src.turn.waits.blocking")

local tick_flow = {}
local wait_keys = wait_callbacks.wait_keys

local function _try_release_landing_visual(state, game)
  if not runtime_state.get_landing_visual_release_pending(state) then
    return false
  end
  local released = landing_visual_hold.release(state, game) == true
  if released then
    runtime_state.mark_landing_visual_release_pulse(state)
  end
  return released
end

local function _maybe_advance_turn(game)
  if not (game.turn and game.advance_turn) then return end
  local block = blocking.current_block(game)
  if not (block and block.kind == "landing_visual") then return end
  if not wait_callbacks.is_wait_ready(game, wait_keys.landing_visual) then return end
  game:advance_turn()
end

function tick_flow.tick(game, state, dt, ports, deps)
  assert(type(deps) == "table", "missing deps")
  assert(type(deps.step_auto_runner) == "function", "missing deps.step_auto_runner")
  assert(type(deps.dispatch_action_with_close_choice) == "function",
    "missing deps.dispatch_action_with_close_choice")

  local released_landing_visual = _try_release_landing_visual(state, game)
  local input_blocked_changed = gameplay_loop_runtime.sync_input_blocked(state, game.turn.phase, ports)
  turn_role_control_policy.sync(game, state, ports)

  deps.step_auto_runner(game, state, dt, auto_context.build_tick(game, state, ports.ui_sync))
  tick_steps.step_tick_timeouts(game, state, dt, ports, deps.dispatch_action_with_close_choice)
  input_blocked_changed = tick_steps.sync_tick_phase(game, state, ports, input_blocked_changed)
  tick_steps.refresh_tick_from_dirty(game, state, ports, input_blocked_changed)
  if released_landing_visual then
    return
  end
  _maybe_advance_turn(game)
end

return tick_flow

--[[ mutate4lua-manifest
version=2
projectHash=f054600a29a07908
scope.0.id=chunk:src/turn/loop/tick_flow.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=51
scope.0.semanticHash=66d7938301af0e9e
scope.0.lastMutatedAt=2026-06-01T06:39:32Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=7
scope.0.lastMutationKilled=7
scope.1.id=function:_try_release_landing_visual:12
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=21
scope.1.semanticHash=fcaa6298cf19cebe
scope.1.lastMutatedAt=2026-06-01T06:39:32Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=7
scope.1.lastMutationKilled=7
scope.2.id=function:_maybe_advance_turn:23
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=28
scope.2.semanticHash=8fbb6ab854ed229a
scope.2.lastMutatedAt=2026-06-01T06:39:32Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=survived
scope.2.lastMutationSites=7
scope.2.lastMutationKilled=6
scope.3.id=function:tick_flow.tick:30
scope.3.kind=function
scope.3.startLine=30
scope.3.endLine=48
scope.3.semanticHash=786517d5bafba001
scope.3.lastMutatedAt=2026-06-01T06:39:32Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=11
scope.3.lastMutationKilled=11
]]
