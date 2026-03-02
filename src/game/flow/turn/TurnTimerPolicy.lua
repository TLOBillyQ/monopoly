local constants = require("Config.Generated.Constants")

local turn_timer_policy = {}

local function _is_action_button_wait_active(game, state, ports)
  local ui_sync_ports = ports and ports.ui_sync or nil
  if not (game and state and ports) then
    return false
  end
  if ui_sync_ports and ui_sync_ports.get_ui_state and not ui_sync_ports.get_ui_state(state) then
    return false
  end
  if game.finished then
    return false
  end
  if ui_sync_ports and ui_sync_ports.is_input_blocked and ui_sync_ports.is_input_blocked(state) then
    return false
  end
  if (ui_sync_ports and ui_sync_ports.is_choice_active and ui_sync_ports.is_choice_active(state))
      or (ui_sync_ports and ui_sync_ports.is_market_active and ui_sync_ports.is_market_active(state))
      or (ui_sync_ports and ui_sync_ports.is_popup_active and ui_sync_ports.is_popup_active(state)) then
    return false
  end
  if game.turn and game.turn.pending_choice then
    return false
  end
  return true
end

function turn_timer_policy.update_action_button_timer(ctx)
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

function turn_timer_policy.update_detained_wait_timer(game, state, dt, step_turn)
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

return turn_timer_policy
