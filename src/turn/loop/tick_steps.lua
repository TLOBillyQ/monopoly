local turn_dispatch = require("src.turn.actions.action_dispatcher")
local turn_anim = require("src.turn.output.anim")
local gameplay_loop_runtime = require("src.turn.loop.runtime")
local turn_timer_policy = require("src.turn.policies.timer")
local turn_camera_policy = require("src.turn.policies.camera")
local runtime_state = require("src.state.runtime")
local landing_visual_hold = require("src.state.visual_hold")
local DeadlineService = require("src.turn.deadlines")
local target_select_timer = require("src.turn.waits.target_select_timer")

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

local _move_anim_call_opts = { on_move_anim = nil }
local _action_anim_call_opts = { on_action_anim = nil }
local _cached_anim_ports_ref = nil

local function _ensure_anim_callbacks(anim_ports)
  if _cached_anim_ports_ref == anim_ports then
    return
  end
  _cached_anim_ports_ref = anim_ports
  _move_anim_call_opts.on_move_anim = function(s, anim_ctx)
    return anim_ports.play_move_anim(s, anim_ctx)
  end
  _action_anim_call_opts.on_action_anim = function(s, anim_ctx)
    return anim_ports.play_action_anim(s, anim_ctx)
  end
end

local function _step_phase_animation(game, state, phase, ports)
  local anim_ports = ports.anim
  if phase == "wait_move_anim" then
    if not game.turn.move_anim then
      return
    end
    _ensure_anim_callbacks(anim_ports)
    turn_anim.step_move_anim(game, state, _move_anim_call_opts)
    return
  end
  if phase == "wait_action_anim" then
    if not game.turn.action_anim then
      return
    end
    _ensure_anim_callbacks(anim_ports)
    turn_anim.step_action_anim(game, state, _action_anim_call_opts)
  end
end

function tick_steps.step_tick_timeouts(game, state, dt, ports, dispatch_action_with_close_choice)
  local ui_sync_ports = ports.ui_sync
  DeadlineService.tick(state, dt)
  target_select_timer.step(game, state, dt)
  ui_sync_ports.step_choice_timeout(game, state, dt)
  ui_sync_ports.step_modal_timeout(game, state, dt)
  local timer_ctx = state._action_timer_ctx
  if timer_ctx == nil then
    timer_ctx = {}
    state._action_timer_ctx = timer_ctx
  end
  timer_ctx.game = game
  timer_ctx.state = state
  timer_ctx.dt = dt
  timer_ctx.ports = ports
  if timer_ctx._dispatch_ref ~= dispatch_action_with_close_choice then
    timer_ctx._dispatch_ref = dispatch_action_with_close_choice
    timer_ctx.dispatch_next = function(actor_role_id, input_source)
      timer_ctx._dispatch_ref(timer_ctx.game, timer_ctx.state, {
        type = "ui_button",
        id = "next",
        actor_role_id = actor_role_id,
        input_source = input_source,
      }, timer_ctx.ports)
    end
  end
  turn_timer_policy.update_action_button_timer(timer_ctx)
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

  -- 行动日志是 append-only 历史，与 UI 冻结策略解耦：HOLD 期间也照常推。
  -- log_status 仍受 HOLD 守护（状态快照需要冻结），但 event_log 不能跟着冻。
  debug_ports.sync_event_log(state)
end

return tick_steps
