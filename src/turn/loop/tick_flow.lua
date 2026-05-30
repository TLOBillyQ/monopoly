local gameplay_loop_runtime = require("src.turn.loop.runtime")
local turn_role_control_policy = require("src.turn.policies.role_control")
local auto_context = require("src.turn.policies.auto_context")
local tick_steps = require("src.turn.loop.tick_steps")
local landing_visual_hold = require("src.state.visual_hold")
local runtime_state = require("src.state.runtime")
local wait_callbacks = require("src.turn.waits.callback_registry")

local tick_flow = {}
local wait_keys = wait_callbacks.wait_keys

function tick_flow.tick(game, state, dt, ports, deps)
  assert(type(deps) == "table", "missing deps")
  assert(type(deps.step_auto_runner) == "function", "missing deps.step_auto_runner")
  assert(type(deps.dispatch_action_with_close_choice) == "function",
    "missing deps.dispatch_action_with_close_choice")

  local released_landing_visual = false
  if runtime_state.get_landing_visual_release_pending(state) then
    released_landing_visual = landing_visual_hold.release(state, game) == true
    if released_landing_visual then
      runtime_state.mark_landing_visual_release_pulse(state)
    end
  end

  local phase = game.turn.phase
  local input_blocked_changed = gameplay_loop_runtime.sync_input_blocked(state, phase, ports)
  turn_role_control_policy.sync(game, state, ports)

  deps.step_auto_runner(game, state, dt, auto_context.build_tick(game, state, ports.ui_sync))
  tick_steps.step_tick_timeouts(game, state, dt, ports, deps.dispatch_action_with_close_choice)
  input_blocked_changed = tick_steps.sync_tick_phase(game, state, ports, input_blocked_changed)
  tick_steps.refresh_tick_from_dirty(game, state, ports, input_blocked_changed)
  if released_landing_visual then
    return
  end
  if game.turn
      and game.turn.phase == "wait_landing_visual"
      and wait_callbacks.is_wait_ready(game, wait_keys.landing_visual)
      and game.advance_turn then
    game:advance_turn()
  end
end

return tick_flow

--[[ mutate4lua-manifest
version=2
projectHash=0a3a9ca1e4514346
scope.0.id=chunk:src/turn/loop/tick_flow.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=46
scope.0.semanticHash=87c2659c04a0d2fb
scope.1.id=function:tick_flow.tick:12
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=43
scope.1.semanticHash=8e80d2b9c55ed086
]]
