local runtime_state = require("src.core.RuntimeState")

local runtime = {}

function runtime.is_phase_input_blocked(phase)
  return phase == "wait_move_anim" or phase == "wait_action_anim" or phase == "detained_wait"
end

function runtime.sync_input_blocked(state, phase, ports)
  local ui_sync_ports = ports and ports.ui_sync or nil
  local output_ports = ports and ports.output or nil
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
  if not input_blocked and output_ports and output_ports.invalidate_ui then
    output_ports.invalidate_ui(state)
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
  port.push_popup = function(_, payload, opts)
    if type(state.push_popup) == "function" then
      return state:push_popup(payload, opts)
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
  port.on_tile_upgraded = function(_, tile_id, level)
    if type(state.on_tile_upgraded) == "function" then
      state:on_tile_upgraded(tile_id, level)
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

return runtime
