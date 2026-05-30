local runtime_state = require("src.state.runtime")
local landing_visual_hold = require("src.state.visual_hold")
local logger = require("src.foundation.log")

local runtime = {}

function runtime.is_phase_input_blocked(phase)
  return phase == "wait_move_anim"
    or phase == "wait_action_anim"
    or phase == "wait_landing_visual"
    or phase == "detained_wait"
    or phase == "inter_turn_wait"
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
    local game = state.game
    return landing_visual_hold.run_or_defer(state, game, "popup", function()
      if type(state.push_popup) == "function" then
        return state:push_popup(payload, opts)
      end
      return false
    end)
  end

  state._popup_port = port
  return port
end

function runtime.build_tip_output_port(state)
  assert(type(state) == "table", "missing state")
  if type(state._tip_output_port) == "table" then
    return state._tip_output_port
  end

  local port = {}
  port.enqueue = function(_, intent)
    if type(state.show_tip) ~= "function" then
      logger.warn("[tip_output_port]", "state.show_tip not installed, falling back to tip_queue direct")
      local tip_queue = require("src.foundation.tips")
      return tip_queue.enqueue(intent)
    end
    return state:show_tip(intent) == true
  end

  state._tip_output_port = port
  return port
end

function runtime.build_tile_feedback_port(state)
  assert(type(state) == "table", "missing state")
  if type(state._tile_feedback_port) == "table" then
    return state._tile_feedback_port
  end

  local port = {}
  port.on_tile_upgraded = function(_, tile_id, _level)
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
    local game
    local payload
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
    return landing_visual_hold.run_or_defer(state, current_game, "board_visual_sync", function()
      if type(state.on_board_visual_sync) == "function" then
        return state:on_board_visual_sync(payload) == true
      end
      return false
    end)
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

--[[ mutate4lua-manifest
version=2
projectHash=ce5baac4d502a5d9
scope.0.id=chunk:src/turn/loop/runtime.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=173
scope.0.semanticHash=74f071766b992cb1
scope.1.id=function:runtime.is_phase_input_blocked:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=13
scope.1.semanticHash=8072f78610202f0c
scope.2.id=function:runtime.sync_input_blocked:15
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=29
scope.2.semanticHash=eef6b3a31833e672
scope.3.id=function:runtime.sync_phase_flags:31
scope.3.kind=function
scope.3.startLine=31
scope.3.endLine=45
scope.3.semanticHash=35c63bcf516f5d60
scope.4.id=function:anonymous@54:54
scope.4.kind=function
scope.4.startLine=54
scope.4.endLine=56
scope.4.semanticHash=017e316e86016bb9
scope.5.id=function:runtime.build_board_scene_port:47
scope.5.kind=function
scope.5.startLine=47
scope.5.endLine=60
scope.5.semanticHash=cb0d1072ce97540f
scope.6.id=function:anonymous@71:71
scope.6.kind=function
scope.6.startLine=71
scope.6.endLine=76
scope.6.semanticHash=feaf6241c0a177d3
scope.7.id=function:anonymous@69:69
scope.7.kind=function
scope.7.startLine=69
scope.7.endLine=77
scope.7.semanticHash=772dac78a215d92d
scope.8.id=function:runtime.build_popup_port:62
scope.8.kind=function
scope.8.startLine=62
scope.8.endLine=81
scope.8.semanticHash=5986b6df649b03a6
scope.9.id=function:anonymous@90:90
scope.9.kind=function
scope.9.startLine=90
scope.9.endLine=97
scope.9.semanticHash=b0b741df108ca304
scope.10.id=function:runtime.build_tip_output_port:83
scope.10.kind=function
scope.10.startLine=83
scope.10.endLine=101
scope.10.semanticHash=5d517d16a315a57e
scope.11.id=function:anonymous@110:110
scope.11.kind=function
scope.11.startLine=110
scope.11.endLine=118
scope.11.semanticHash=9cff8a66de8bddab
scope.12.id=function:runtime.build_tile_feedback_port:103
scope.12.kind=function
scope.12.startLine=103
scope.12.endLine=122
scope.12.semanticHash=024a7c1a65ea1ace
scope.13.id=function:anonymous@145:145
scope.13.kind=function
scope.13.startLine=145
scope.13.endLine=150
scope.13.semanticHash=a444316ad43e2bf9
scope.14.id=function:anonymous@131:131
scope.14.kind=function
scope.14.startLine=131
scope.14.endLine=151
scope.14.semanticHash=2ec66c205a274d05
scope.15.id=function:runtime.build_board_visual_feedback_port:124
scope.15.kind=function
scope.15.startLine=124
scope.15.endLine=155
scope.15.semanticHash=a007a77687497cbe
scope.16.id=function:runtime.build_anim_gate_port:157
scope.16.kind=function
scope.16.startLine=157
scope.16.endLine=170
scope.16.semanticHash=9b8ce0a042ae7db5
]]
