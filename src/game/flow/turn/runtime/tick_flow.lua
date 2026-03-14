local gameplay_loop_runtime = require("src.game.flow.turn.runtime.loop_runtime")
local turn_role_control_policy = require("src.game.flow.turn.policies.role_control_policy")
local auto_context = require("src.game.flow.turn.auto.context")
local tick_steps = require("src.game.flow.turn.runtime.tick_steps")
local landing_visual_hold = require("src.state.state_access.landing_visual_hold")

local tick_flow = {}

function tick_flow.tick(game, state, dt, ports, deps)
  assert(type(deps) == "table", "missing deps")
  assert(type(deps.step_afk_auto_host) == "function", "missing deps.step_afk_auto_host")
  assert(type(deps.step_auto_runner) == "function", "missing deps.step_auto_runner")
  assert(type(deps.dispatch_action_with_close_choice) == "function",
    "missing deps.dispatch_action_with_close_choice")

  if game.turn
      and game.turn.phase == "wait_landing_visual"
      and game.turn.landing_visual_wait_ready == true
      and game.advance_turn then
    game:advance_turn()
  end

  landing_visual_hold.sync_state_from_game(state, game)
  if landing_visual_hold.is_release_pending_game(game) then
    landing_visual_hold.release(state, game)
  end

  local phase = game.turn.phase
  local input_blocked_changed = gameplay_loop_runtime.sync_input_blocked(state, phase, ports)
  turn_role_control_policy.sync(game, state, ports)

  local afk_triggered = deps.step_afk_auto_host(game, state, dt) == true
  if not afk_triggered then
    deps.step_auto_runner(game, state, dt, auto_context.build_tick(game, state, ports.ui_sync))
  end
  tick_steps.step_tick_timeouts(game, state, dt, ports, deps.dispatch_action_with_close_choice)
  input_blocked_changed = tick_steps.sync_tick_phase(game, state, ports, input_blocked_changed)
  tick_steps.refresh_tick_from_dirty(game, state, ports, input_blocked_changed)
end

return tick_flow
