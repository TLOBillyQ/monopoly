local constants = require("Config.Generated.Constants")
local gameplay_rules = require("Config.GameplayRules")

local runtime = {}

function runtime.is_phase_input_blocked(phase)
  return phase == "wait_move_anim" or phase == "wait_action_anim" or phase == "detained_wait"
end

function runtime.sync_input_blocked(state, phase, ports)
  if not ports or not ports.get_ui_state or not ports.set_input_blocked then
    return false
  end
  local ui = ports.get_ui_state(state)
  if not ui then
    return false
  end
  local input_blocked = runtime.is_phase_input_blocked(phase)
  if not ports.set_input_blocked(state, input_blocked) then
    return false
  end
  if not input_blocked then
    state.ui_dirty = true
  end
  return true
end

function runtime.sync_phase_flags(state, phase)
  if state.board_last_phase == "wait_move_anim" and phase ~= "wait_move_anim" then
    state.board_sync_pending = true
  end
  if state.next_turn_locked and state.next_turn_lock_phase and phase and phase ~= state.next_turn_lock_phase then
    state.next_turn_locked = false
    state.next_turn_lock_phase = phase
  end
  state.board_last_phase = phase
end

local function _resolve_role_control_lock_enabled(game)
  if gameplay_rules.role_control_lock_enabled ~= true then
    return false
  end
  if not game or game.finished then
    return false
  end
  return true
end

function runtime.sync_role_control_lock(game, state, ports)
  if not state or not ports or not ports.apply_role_control_lock then
    return
  end
  local enabled = _resolve_role_control_lock_enabled(game)
  if enabled then
    local suppress = state.role_control_lock_suppress or 0
    if suppress > 0 then
      ports.apply_role_control_lock(state, false)
    else
      ports.apply_role_control_lock(state, true)
    end
    state.role_control_lock_active = true
    return
  end
  if state.role_control_lock_active then
    ports.apply_role_control_lock(state, false)
    state.role_control_lock_active = false
  end
end

local function _is_action_button_wait_active(game, state, ports)
  if not (game and state and ports) then
    return false
  end
  if ports.get_ui_state and not ports.get_ui_state(state) then
    return false
  end
  if game.finished then
    return false
  end
  if ports.is_input_blocked and ports.is_input_blocked(state) then
    return false
  end
  if (ports.is_choice_active and ports.is_choice_active(state))
      or (ports.is_market_active and ports.is_market_active(state))
      or (ports.is_popup_active and ports.is_popup_active(state)) then
    return false
  end
  if game.turn and game.turn.pending_choice then
    return false
  end
  return true
end

function runtime.update_action_button_timer(ctx)
  local state = ctx and ctx.state
  if not state then
    return
  end
  local game = ctx.game
  local ports = ctx.ports
  if not _is_action_button_wait_active(game, state, ports) then
    state.action_button_active = false
    state.action_button_elapsed = 0
    return
  end

  local timeout = constants.action_timeout_seconds or 0
  if timeout <= 0 then
    state.action_button_active = false
    state.action_button_elapsed = 0
    return
  end
  state.action_button_active = true

  local elapsed = (state.action_button_elapsed or 0) + (ctx.dt or 0)
  if elapsed < timeout then
    state.action_button_elapsed = elapsed
    return
  end

  state.action_button_elapsed = 0
  local current_index = game and game.turn and game.turn.current_player_index or nil
  local current_player = current_index and game.players and game.players[current_index] or nil
  if not current_player then
    return
  end
  if ctx.dispatch_next then
    ctx.dispatch_next(current_player.id)
  end
end

function runtime.update_detained_wait_timer(game, state, dt, step_turn)
  if not (game and state) then
    return
  end
  local turn = game.turn
  if not (turn and turn.detained_wait_active) then
    return
  end
  local elapsed = (turn.detained_wait_elapsed or 0) + (dt or 0)
  local timeout = turn.detained_wait_seconds or 0
  if timeout <= 0 then
    turn.detained_wait_active = false
    turn.detained_wait_elapsed = 0
    step_turn(game)
    return
  end
  if elapsed < timeout then
    turn.detained_wait_elapsed = elapsed
    return
  end
  turn.detained_wait_active = false
  turn.detained_wait_elapsed = 0
  step_turn(game)
end

return runtime
