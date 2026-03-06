local turn_dispatch = require("src.game.flow.turn.TurnDispatch")
local turn_anim = require("src.game.flow.turn.TurnAnim")
local gameplay_loop_runtime = require("src.game.flow.turn.GameplayLoopRuntime")
local turn_timer_policy = require("src.game.flow.turn.TurnTimerPolicy")
local turn_camera_policy = require("src.game.flow.turn.TurnCameraPolicy")

local tick_steps = {}

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

function tick_steps.step_tick_timeouts(game, state, dt, ports, dispatch_action_with_close_choice)
  local ui_sync_ports = ports.ui_sync
  ui_sync_ports.step_choice_timeout(game, state, dt)
  ui_sync_ports.step_modal_timeout(game, state, dt)
  ui_sync_ports.step_target_selection(game, state, dt)
  turn_timer_policy.update_action_button_timer({
    game = game,
    state = state,
    dt = dt,
    ports = ports,
    dispatch_next = function(actor_role_id, input_source)
      dispatch_action_with_close_choice(game, state, {
        type = "ui_button",
        id = "next",
        actor_role_id = actor_role_id,
        input_source = input_source,
      }, ports)
    end,
  })
  turn_timer_policy.update_detained_wait_timer(game, state, dt, turn_dispatch.step_turn)
end

function tick_steps.sync_tick_phase(game, state, ports, input_blocked_changed)
  local phase = game.turn.phase
  if gameplay_loop_runtime.sync_input_blocked(state, phase, ports) then
    input_blocked_changed = true
  end
  _step_phase_animation(game, state, phase, ports)
  gameplay_loop_runtime.sync_phase_flags(state, phase)
  return input_blocked_changed
end

function tick_steps.refresh_tick_from_dirty(game, state, ports, input_blocked_changed)
  local ui_sync_ports = ports.ui_sync
  local anim_ports = ports.anim
  local debug_ports = ports.debug
  ui_sync_ports.update_countdown(game, state)

  local dirty = game:consume_dirty()
  local ui_refreshed = ui_sync_ports.refresh_from_dirty(game, state, dirty)
  turn_camera_policy.sync_follow(game, state, ports, ui_refreshed)
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

return tick_steps
