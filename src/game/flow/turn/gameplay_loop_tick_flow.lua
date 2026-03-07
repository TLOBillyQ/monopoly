local gameplay_loop_runtime = require("src.game.flow.turn.gameplay_loop_runtime")
local turn_role_control_policy = require("src.game.flow.turn.turn_role_control_policy")
local auto_context = require("src.game.flow.turn.auto_context")
local tick_steps = require("src.game.flow.turn.gameplay_loop_tick_steps")

local tick_flow = {}

function tick_flow.tick(game, state, dt, ports, deps)
  assert(type(deps) == "table", "missing deps")
  assert(type(deps.step_afk_auto_host) == "function", "missing deps.step_afk_auto_host")
  assert(type(deps.step_auto_runner) == "function", "missing deps.step_auto_runner")
  assert(type(deps.dispatch_action_with_close_choice) == "function",
    "missing deps.dispatch_action_with_close_choice")

  local phase = game.turn.phase
  local input_blocked_changed = gameplay_loop_runtime.sync_input_blocked(state, phase, ports)
  turn_role_control_policy.sync(game, state, ports)

  local afk_triggered = deps.step_afk_auto_host(game, state, dt) == true
  if not afk_triggered then
    deps.step_auto_runner(game, state, dt, auto_context.build_tick(game))
  end
  tick_steps.step_tick_timeouts(game, state, dt, ports, deps.dispatch_action_with_close_choice)
  input_blocked_changed = tick_steps.sync_tick_phase(game, state, ports, input_blocked_changed)
  tick_steps.refresh_tick_from_dirty(game, state, ports, input_blocked_changed)
end

return tick_flow
