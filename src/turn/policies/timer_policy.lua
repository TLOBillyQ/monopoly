local constants = require("src.config.content.constants")
local tip_queue = require("src.core.utils.tip_queue")

local turn_timer_policy = {}

local function _reset_action_button(state)
  state.action_button_active = false
  state.action_button_elapsed = 0
  state.action_button_player_id = nil
end

local function _has_blocking_ui(ui_sync_ports, state)
  return (ui_sync_ports and ui_sync_ports.is_choice_active and ui_sync_ports.is_choice_active(state))
      or (ui_sync_ports and ui_sync_ports.is_market_active and ui_sync_ports.is_market_active(state))
      or (ui_sync_ports and ui_sync_ports.is_popup_active and ui_sync_ports.is_popup_active(state))
end

local function _resolve_elapsed(elapsed, dt)
  return (elapsed or 0) + (dt or 0)
end

local function _complete_wait(turn, active_key, elapsed_key, step_turn, game)
  turn[active_key] = false
  turn[elapsed_key] = 0
  step_turn(game)
end

function turn_timer_policy.is_action_button_wait_active(game, state, ports)
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
  if _has_blocking_ui(ui_sync_ports, state) then
    return false
  end
  if game.turn and game.turn.pending_choice then
    return false
  end
  return true
end


local function _resolve_timeout_seconds()
  return constants.action_timeout_seconds or 0
end

local function _should_activate_button(timeout)
  return timeout > 0
end

local function _resolve_current_player(game)
  local current_index = game and game.turn and game.turn.current_player_index or nil
  return current_index and game.players and game.players[current_index] or nil
end

local function _is_auto_player(game, player)
  if not player then
    return false
  end
  local auto_play_port = game and game.auto_play_port or nil
  if type(auto_play_port) == "table" and type(auto_play_port.is_auto_player) == "function" then
    local ok, is_auto = pcall(auto_play_port.is_auto_player, game, player)
    if ok then
      return is_auto == true
    end
  end
  return player.auto == true or player.is_ai == true or player.ai == true
end

local function _should_track_action_button_for_player(game, player)
  if _is_auto_player(game, player) then
    return true
  end
  local phase = game and game.turn and game.turn.phase or nil
  return phase == "wait_action"
end

local function _dispatch_timeout(ctx, current_player)
  if ctx.dispatch_next then
    ctx.dispatch_next(current_player.id, "timeout")
  end
end

local function _update_elapsed_timer(state, dt, timeout, game, ctx)
  local elapsed = _resolve_elapsed(state.action_button_elapsed, dt)
  if elapsed < timeout then
    state.action_button_elapsed = elapsed
    return true
  end
  return false
end

local function _handle_timeout_elapsed(state, game, ctx)
  state.action_button_elapsed = 0
  local current_player = _resolve_current_player(game)
  if not current_player then
    return
  end
  _dispatch_timeout(ctx, current_player)
end

function turn_timer_policy.update_action_button_timer(ctx)
  local state = ctx and ctx.state
  if not state then
    return
  end

  local game = ctx.game
  local ports = ctx.ports
  if not turn_timer_policy.is_action_button_wait_active(game, state, ports) then
    _reset_action_button(state)
    return
  end

  local timeout = _resolve_timeout_seconds()
  if not _should_activate_button(timeout) then
    _reset_action_button(state)
    return
  end

  local current_player = _resolve_current_player(game)
  if not current_player then
    _reset_action_button(state)
    return
  end

  if state.action_button_player_id ~= current_player.id then
    state.action_button_player_id = current_player.id
    state.action_button_elapsed = 0
  end

  if not _should_track_action_button_for_player(game, current_player) then
    _reset_action_button(state)
    return
  end

  state.action_button_active = true

  if _update_elapsed_timer(state, ctx.dt, timeout, game, ctx) then
    return
  end

  _handle_timeout_elapsed(state, game, ctx)
end

function turn_timer_policy.update_detained_wait_timer(game, state, dt, step_turn)
  if not (game and state) then
    return
  end
  local turn = game.turn
  if not (turn and turn.detained_wait_active) then
    return
  end

  local elapsed = _resolve_elapsed(turn.detained_wait_elapsed, dt)
  local timeout = turn.detained_wait_seconds or 0
  if timeout <= 0 then
    _complete_wait(turn, "detained_wait_active", "detained_wait_elapsed", step_turn, game)
    return
  end
  if elapsed < timeout then
    turn.detained_wait_elapsed = elapsed
    return
  end

  _complete_wait(turn, "detained_wait_active", "detained_wait_elapsed", step_turn, game)
end

function turn_timer_policy.update_inter_turn_wait_timer(game, state, dt, step_turn)
  if not (game and state) then
    return
  end
  local turn = game.turn
  if not (turn and turn.inter_turn_wait_active) then
    return
  end

  local elapsed = _resolve_elapsed(turn.inter_turn_wait_elapsed, dt)
  local timeout = turn.inter_turn_wait_seconds or 0
  if timeout <= 0 then
    _complete_wait(turn, "inter_turn_wait_active", "inter_turn_wait_elapsed", step_turn, game)
    return
  end
  if elapsed < timeout then
    turn.inter_turn_wait_elapsed = elapsed
    return
  end

  turn.inter_turn_wait_elapsed = timeout
  if tip_queue.has_blocking_pending("inter_turn") then
    return
  end

  _complete_wait(turn, "inter_turn_wait_active", "inter_turn_wait_elapsed", step_turn, game)
end

return turn_timer_policy
