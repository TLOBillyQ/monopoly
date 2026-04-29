local turn_dispatch = require("src.turn.actions.action_dispatcher")
local turn_anim = require("src.turn.output.anim")
local gameplay_loop_runtime = require("src.turn.loop.runtime")
local turn_timer_policy = require("src.turn.policies.timer")
local turn_camera_policy = require("src.turn.policies.camera")
local runtime_state = require("src.state.runtime_state")
local landing_visual_hold = require("src.state.landing_visual_hold")

local tick_steps = {}

local function _sync_input_lock(ui_sync_ports, state, input_blocked_changed, ui_refreshed)
  if not (ui_sync_ports.get_ui_state and ui_sync_ports.is_input_blocked) then
    return
  end
  local ui = ui_sync_ports.get_ui_state(state)
  if ui and (input_blocked_changed or (ui_sync_ports.is_input_blocked(state) and ui_refreshed)) then
    ui_sync_ports.apply_input_lock(state)
  end
end

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
  turn_timer_policy.update_inter_turn_wait_timer(game, state, dt, turn_dispatch.step_turn)
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
  local landing_visual_release_pulse = runtime_state.take_landing_visual_release_pulse(state)
  if landing_visual_release_pulse then
    dirty.any = true
    dirty.turn = true
  end
  local ui_refreshed = ui_sync_ports.refresh_from_dirty(game, state, dirty)
  if dirty.turn then
    turn_camera_policy.reset_follow(state)
  end
  turn_camera_policy.sync_follow(game, state, ports, ui_refreshed)
  if landing_visual_release_pulse or not landing_visual_hold.is_active_state(state) then
    anim_ports.sync_status_3d(game, state, dirty)
  end

  _sync_input_lock(ui_sync_ports, state, input_blocked_changed, ui_refreshed)
  local ui_model = runtime_state.get_ui_model(state)
  if ui_model and not landing_visual_hold.is_active_state(state) then
    debug_ports.log_status(ui_model)
  end

  if not landing_visual_hold.is_active_state(state) then
    debug_ports.sync_event_log(state)
  end
end

return tick_steps
