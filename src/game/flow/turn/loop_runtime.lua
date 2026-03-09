local runtime_state = require("src.core.state_access.runtime_state")
local landing_visual_hold = require("src.core.state_access.landing_visual_hold")

local runtime = {}

function runtime.is_phase_input_blocked(phase)
  return phase == "wait_move_anim"
    or phase == "wait_action_anim"
    or phase == "wait_landing_visual"
    or phase == "detained_wait"
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

function runtime.build_board_scene_port(state)
  assert(type(state) == "table", "missing state")
  if type(state._board_scene_port) == "table" then
    return state._board_scene_port
  end

  local port = {}
  port.get_board_scene = function()
    return state.board_scene
  end

  state._board_scene_port = port
  return port
end

function runtime.build_popup_port(state)
  assert(type(state) == "table", "missing state")
  if type(state._popup_port) == "table" then
    return state._popup_port
  end

  local port = {}
  port.push_popup = function(_, payload, opts)
    if landing_visual_hold.is_active_state(state) and not landing_visual_hold.is_flushing_state(state) then
      landing_visual_hold.defer_popup(state, payload, opts, function(inner_payload, inner_opts)
        if type(state.push_popup) == "function" then
          return state:push_popup(inner_payload, inner_opts)
        end
        return false
      end)
      return true
    end
    if type(state.push_popup) == "function" then
      return state:push_popup(payload, opts)
    end
    return false
  end

  state._popup_port = port
  return port
end

function runtime.build_tile_feedback_port(state)
  assert(type(state) == "table", "missing state")
  if type(state._tile_feedback_port) == "table" then
    return state._tile_feedback_port
  end

  local port = {}
  port.on_tile_upgraded = function(_, tile_id, level)
    local game = state.game
    if game == nil or game.board_visual_feedback_port == nil then
      return false
    end
    return game.board_visual_feedback_port.sync_many(game, {
      tile_ids = { tile_id },
    })
  end

  state._tile_feedback_port = port
  return port
end

function runtime.build_board_visual_feedback_port(state)
  assert(type(state) == "table", "missing state")
  if type(state._board_visual_feedback_port) == "table" then
    return state._board_visual_feedback_port
  end

  local port = {}
  port.sync_many = function(arg1, arg2, arg3)
    local game = nil
    local payload = nil
    if arg3 ~= nil or (type(arg1) == "table" and arg1 == port) then
      game = arg2
      payload = arg3
    else
      game = arg1
      payload = arg2
    end
    local current_game = game or state.game
    if current_game ~= nil then
      state.game = current_game
    end
    if landing_visual_hold.is_active_state(state) and not landing_visual_hold.is_flushing_state(state) then
      landing_visual_hold.defer_board_visual_sync(state, payload, function(inner_payload)
        if type(state.on_board_visual_sync) == "function" then
          return state:on_board_visual_sync(inner_payload) == true
        end
        return false
      end)
      return true
    end
    if type(state.on_board_visual_sync) == "function" then
      return state:on_board_visual_sync(payload) == true
    end
    return false
  end

  state._board_visual_feedback_port = port
  return port
end

function runtime.build_anim_gate_port(state)
  assert(type(state) == "table", "missing state")
  if type(state._anim_gate_port) == "table" then
    return state._anim_gate_port
  end

  local port = {
    wait_move_anim = state.wait_move_anim == true,
    wait_action_anim = state.wait_action_anim == true,
  }

  state._anim_gate_port = port
  return port
end

return runtime
