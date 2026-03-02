local turn_dispatch = require("src.game.flow.turn.TurnDispatch")
local turn_anim = require("src.game.flow.turn.TurnAnim")
local gameplay_loop_runtime = require("src.game.flow.turn.GameplayLoopRuntime")
local auto_context = require("src.game.flow.turn.AutoContext")

local tick_flow = {}

local function _step_phase_animation(game, state, phase, ports)
  local anim_ports = ports.anim
  if phase == "wait_move_anim" then
    local anim_data = game.turn.move_anim
    if not anim_data then
      return
    end
    turn_anim.step_move_anim(game, state, {
      on_move_anim = function(_, anim_ctx)
        return anim_ports.play_move_anim(state, anim_ctx)
      end,
    })
    return
  end
  if phase == "wait_action_anim" then
    local anim_data = game.turn.action_anim
    if not anim_data then
      return
    end
    turn_anim.step_action_anim(game, state, {
      on_action_anim = function(ctx, anim_ctx)
        return anim_ports.play_action_anim(ctx, anim_ctx)
      end,
    })
  end
end

local function _step_tick_timeouts(game, state, dt, ports, dispatch_action_with_close_choice)
  local ui_sync_ports = ports.ui_sync
  ui_sync_ports.step_choice_timeout(game, state, dt)
  ui_sync_ports.step_modal_timeout(game, state, dt)
  gameplay_loop_runtime.update_action_button_timer({
    game = game,
    state = state,
    dt = dt,
    ports = ports,
    dispatch_next = function(actor_role_id)
      dispatch_action_with_close_choice(game, state, {
        type = "ui_button",
        id = "next",
        actor_role_id = actor_role_id,
      }, ports)
    end,
  })
  gameplay_loop_runtime.update_detained_wait_timer(game, state, dt, turn_dispatch.step_turn)
end

local function _sync_tick_phase(game, state, ports, input_blocked_changed)
  local phase = game.turn.phase
  if gameplay_loop_runtime.sync_input_blocked(state, phase, ports) then
    input_blocked_changed = true
  end
  _step_phase_animation(game, state, phase, ports)
  gameplay_loop_runtime.sync_phase_flags(state, phase)
  return input_blocked_changed
end

local function _refresh_tick_from_dirty(game, state, ports, input_blocked_changed)
  local ui_sync_ports = ports.ui_sync
  local anim_ports = ports.anim
  local debug_ports = ports.debug
  ui_sync_ports.update_countdown(game, state)

  local dirty = game:consume_dirty()
  local ui_refreshed = ui_sync_ports.refresh_from_dirty(game, state, dirty)
  gameplay_loop_runtime.sync_turn_camera_follow(game, state, ports, ui_refreshed)
  anim_ports.sync_status_3d(game, state, dirty)

  if ui_sync_ports.get_ui_state and ui_sync_ports.is_input_blocked then
    local ui = ui_sync_ports.get_ui_state(state)
    if ui and (input_blocked_changed or (ui_sync_ports.is_input_blocked(state) and ui_refreshed)) then
      ui_sync_ports.apply_input_lock(state)
    end
  end
  if state.ui_model then
    debug_ports.log_status(state.ui_model)
  end

  debug_ports.sync_debug_log(state)
end

function tick_flow.tick(game, state, dt, ports, deps)
  assert(type(deps) == "table", "missing deps")
  assert(type(deps.step_auto_runner) == "function", "missing deps.step_auto_runner")
  assert(type(deps.dispatch_action_with_close_choice) == "function",
    "missing deps.dispatch_action_with_close_choice")

  local phase = game.turn.phase
  local input_blocked_changed = gameplay_loop_runtime.sync_input_blocked(state, phase, ports)
  gameplay_loop_runtime.sync_role_control_lock(game, state, ports)

  deps.step_auto_runner(game, state, dt, auto_context.build_tick(game))
  _step_tick_timeouts(game, state, dt, ports, deps.dispatch_action_with_close_choice)
  input_blocked_changed = _sync_tick_phase(game, state, ports, input_blocked_changed)
  _refresh_tick_from_dirty(game, state, ports, input_blocked_changed)
end

return tick_flow
