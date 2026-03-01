local constants = require("Config.Generated.Constants")
local gameplay_rules = require("Config.GameplayRules")
local runtime_state = require("src.core.RuntimeState")

local runtime = {}

function runtime.is_phase_input_blocked(phase)
  return phase == "wait_move_anim" or phase == "wait_action_anim" or phase == "detained_wait"
end

function runtime.sync_input_blocked(state, phase, ports)
  local ui_sync_ports = ports and ports.ui_sync or nil
  if not ui_sync_ports or not ui_sync_ports.get_ui_state or not ui_sync_ports.set_input_blocked then
    return false
  end
  local ui = ui_sync_ports.get_ui_state(state)
  if not ui then
    return false
  end
  local input_blocked = runtime.is_phase_input_blocked(phase)
  if not ui_sync_ports.set_input_blocked(state, input_blocked) then
    return false
  end
  if not input_blocked then
    state.ui_dirty = true
  end
  return true
end

function runtime.sync_phase_flags(state, phase)
  local board_runtime = runtime_state.ensure_board_runtime(state)
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  if board_runtime.board_last_phase == "wait_move_anim" and phase ~= "wait_move_anim" then
    board_runtime.board_sync_pending = true
  end
  if turn_runtime.next_turn_locked
      and turn_runtime.next_turn_lock_phase
      and phase
      and phase ~= turn_runtime.next_turn_lock_phase then
    turn_runtime.next_turn_locked = false
    turn_runtime.next_turn_lock_phase = phase
  end
  board_runtime.board_last_phase = phase
end

function runtime.build_ui_runtime_port(state)
  assert(type(state) == "table", "missing state")
  if type(state._ui_runtime_port) == "table" then
    return state._ui_runtime_port
  end

  local port = {
    wait_move_anim = state.wait_move_anim == true,
    wait_action_anim = state.wait_action_anim == true,
    state = state,
  }
  port.push_popup = function(_, payload)
    if type(state.push_popup) == "function" then
      return state:push_popup(payload)
    end
    return false
  end
  port.on_tile_owner_changed = function(_, tile_id, owner_id)
    if type(state.on_tile_owner_changed) == "function" then
      state:on_tile_owner_changed(tile_id, owner_id)
      return true
    end
    return false
  end
  port.get_board_scene = function()
    return state.board_scene
  end

  state._ui_runtime_port = port
  return port
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
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  local state_ports = ports and ports.state or nil
  if not state or not state_ports or not state_ports.apply_role_control_lock then
    return
  end
  local enabled = _resolve_role_control_lock_enabled(game)
  if enabled then
    state_ports.apply_role_control_lock(state, true)
    turn_runtime.role_control_lock_active = true
    return
  end
  if turn_runtime.role_control_lock_active then
    state_ports.apply_role_control_lock(state, false)
    turn_runtime.role_control_lock_active = false
  end
end

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

function runtime.sync_turn_camera_follow(game, state, ports, ui_refreshed)
  if ui_refreshed ~= true then
    return
  end
  local ui_sync_ports = ports and ports.ui_sync or nil
  if not (ui_sync_ports and type(ui_sync_ports.follow_camera) == "function") then
    return
  end
  local turn = game and game.turn or nil
  local current_index = turn and turn.current_player_index or nil
  local current = current_index and game and game.players and game.players[current_index] or nil
  local current_id = current and current.id or nil
  if current_id == nil then
    return
  end
  ui_sync_ports.follow_camera(state, current_id)
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
