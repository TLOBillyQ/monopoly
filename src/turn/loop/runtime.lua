local runtime_state = require("src.state.runtime")
local landing_visual_hold = require("src.state.visual_hold")
local logger = require("src.foundation.log")

local runtime = {}

local _INPUT_BLOCKED_PHASES = {
  wait_move_anim = true,
  wait_action_anim = true,
  wait_landing_visual = true,
  detained_wait = true,
  inter_turn_wait = true,
}

function runtime.is_phase_input_blocked(phase)
  return _INPUT_BLOCKED_PHASES[phase] == true
end

local function _ui_sync_ports(ports)
  return ports and ports.ui_sync or nil
end

local function _has_sync_methods(ui_sync_ports)
  return ui_sync_ports ~= nil and ui_sync_ports.get_ui_state ~= nil and ui_sync_ports.set_input_blocked ~= nil
end

function runtime.sync_input_blocked(state, phase, ports)
  local ui_sync_ports = _ui_sync_ports(ports)
  if not _has_sync_methods(ui_sync_ports) then
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

local function _move_anim_just_finished(board_runtime, phase)
  return board_runtime.board_last_phase == "wait_move_anim" and phase ~= "wait_move_anim"
end

local function _should_unlock_next_turn(turn_runtime, phase)
  return turn_runtime.next_turn_locked
    and turn_runtime.next_turn_lock_phase
    and phase
    and phase ~= turn_runtime.next_turn_lock_phase
end

function runtime.sync_phase_flags(state, phase)
  local board_runtime = runtime_state.ensure_board_runtime(state)
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  if _move_anim_just_finished(board_runtime, phase) then
    board_runtime.board_sync_pending = true
  end
  if _should_unlock_next_turn(turn_runtime, phase) then
    turn_runtime.next_turn_locked = false
    turn_runtime.next_turn_lock_phase = phase
  end
  board_runtime.board_last_phase = phase
end

local function _build_memoized_port(state, cache_key, port_builder)
  assert(type(state) == "table", "missing state")
  local cached = state[cache_key]
  if type(cached) == "table" then return cached end
  local port = port_builder()
  state[cache_key] = port
  return port
end

function runtime.build_board_scene_port(state)
  return _build_memoized_port(state, "_board_scene_port", function()
    return { get_board_scene = function() return state.board_scene end }
  end)
end

function runtime.build_popup_port(state)
  return _build_memoized_port(state, "_popup_port", function()
    return {
      push_popup = function(_, payload, opts)
        return landing_visual_hold.run_or_defer(state, state.game, "popup", function()
          if type(state.push_popup) == "function" then return state:push_popup(payload, opts) end
          return false
        end)
      end,
    }
  end)
end

function runtime.build_tip_output_port(state)
  return _build_memoized_port(state, "_tip_output_port", function()
    return {
      enqueue = function(_, intent)
        if type(state.show_tip) == "function" then return state:show_tip(intent) == true end
        logger.warn("[tip_output_port]", "state.show_tip not installed, falling back to tip_queue direct")
        return require("src.foundation.tips").enqueue(intent)
      end,
    }
  end)
end

function runtime.build_tile_feedback_port(state)
  return _build_memoized_port(state, "_tile_feedback_port", function()
    return {
      on_tile_upgraded = function(_, tile_id)
        local game = state.game
        if game == nil or game.board_visual_feedback_port == nil then return false end
        return game.board_visual_feedback_port.sync_many(game, { tile_ids = { tile_id } })
      end,
    }
  end)
end

local function _sync_many_args(arg1, arg2, arg3, port)
  if arg3 ~= nil or (type(arg1) == "table" and arg1 == port) then
    return arg2, arg3
  end
  return arg1, arg2
end

local function _board_visual_sync_deferred(state, payload)
  return function()
    if type(state.on_board_visual_sync) == "function" then
      return state:on_board_visual_sync(payload) == true
    end
    return false
  end
end

function runtime.build_board_visual_feedback_port(state)
  return _build_memoized_port(state, "_board_visual_feedback_port", function()
    local port = {}
    port.sync_many = function(arg1, arg2, arg3)
      local game, payload = _sync_many_args(arg1, arg2, arg3, port)
      local current_game = game or state.game
      if current_game ~= nil then state.game = current_game end
      return landing_visual_hold.run_or_defer(
        state, current_game, "board_visual_sync", _board_visual_sync_deferred(state, payload))
    end
    return port
  end)
end

function runtime.build_anim_gate_port(state)
  return _build_memoized_port(state, "_anim_gate_port", function()
    return { wait_move_anim = state.wait_move_anim == true, wait_action_anim = state.wait_action_anim == true }
  end)
end

return runtime

--[[ mutate4lua-manifest
version=4
projectHash=1713959d88e1599c
scope.0.id=chunk:src/turn/loop/runtime.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=156
scope.0.semanticHash=47bb3b9f69388003
scope.1.id=function:runtime.is_phase_input_blocked
scope.1.kind=function
scope.1.startLine=15
scope.1.endLine=17
scope.1.semanticHash=92047a25c743520b
scope.2.id=function:_ui_sync_ports
scope.2.kind=function
scope.2.startLine=19
scope.2.endLine=21
scope.2.semanticHash=616a2ca60599c94f
scope.3.id=function:_has_sync_methods
scope.3.kind=function
scope.3.startLine=23
scope.3.endLine=25
scope.3.semanticHash=44d9ca3a54db4857
scope.4.id=function:runtime.sync_input_blocked
scope.4.kind=function
scope.4.startLine=27
scope.4.endLine=41
scope.4.semanticHash=60f28469b1d40b70
scope.5.id=function:_move_anim_just_finished
scope.5.kind=function
scope.5.startLine=43
scope.5.endLine=45
scope.5.semanticHash=5425394d76ae823b
scope.6.id=function:_should_unlock_next_turn
scope.6.kind=function
scope.6.startLine=47
scope.6.endLine=52
scope.6.semanticHash=2e1221b3a4fd5e33
scope.7.id=function:runtime.sync_phase_flags
scope.7.kind=function
scope.7.startLine=54
scope.7.endLine=65
scope.7.semanticHash=be70876c1d30a8f2
scope.8.id=function:_build_memoized_port
scope.8.kind=function
scope.8.startLine=67
scope.8.endLine=74
scope.8.semanticHash=131ed0d2c85b382c
scope.9.id=function:runtime.build_board_scene_port
scope.9.kind=function
scope.9.startLine=76
scope.9.endLine=80
scope.9.semanticHash=b4134f5cbbf4f5bb
scope.10.id=function:<anonymous>
scope.10.kind=function
scope.10.startLine=77
scope.10.endLine=79
scope.10.semanticHash=784c9bf78ae01893
scope.11.id=function:<anonymous>#2
scope.11.kind=function
scope.11.startLine=78
scope.11.endLine=78
scope.11.semanticHash=24f2b9b574225623
scope.12.id=function:runtime.build_popup_port
scope.12.kind=function
scope.12.startLine=82
scope.12.endLine=93
scope.12.semanticHash=443325fdad2cf123
scope.13.id=function:<anonymous>#3
scope.13.kind=function
scope.13.startLine=83
scope.13.endLine=92
scope.13.semanticHash=e74c25800b5c06cb
scope.14.id=function:<anonymous>#4
scope.14.kind=function
scope.14.startLine=85
scope.14.endLine=90
scope.14.semanticHash=cf795bbdc3cf3b3d
scope.15.id=function:<anonymous>#5
scope.15.kind=function
scope.15.startLine=86
scope.15.endLine=89
scope.15.semanticHash=18dd5a698f4ce929
scope.16.id=function:runtime.build_tip_output_port
scope.16.kind=function
scope.16.startLine=95
scope.16.endLine=105
scope.16.semanticHash=2c80c33f54a93160
scope.17.id=function:<anonymous>#6
scope.17.kind=function
scope.17.startLine=96
scope.17.endLine=104
scope.17.semanticHash=db94bea24d6fa0f8
scope.18.id=function:<anonymous>#7
scope.18.kind=function
scope.18.startLine=98
scope.18.endLine=102
scope.18.semanticHash=99fae81d64a114ba
scope.19.id=function:runtime.build_tile_feedback_port
scope.19.kind=function
scope.19.startLine=107
scope.19.endLine=117
scope.19.semanticHash=b24ddf200c95bd29
scope.20.id=function:<anonymous>#8
scope.20.kind=function
scope.20.startLine=108
scope.20.endLine=116
scope.20.semanticHash=e1145cbacff9e8b1
scope.21.id=function:<anonymous>#9
scope.21.kind=function
scope.21.startLine=110
scope.21.endLine=114
scope.21.semanticHash=c0566339b3114fad
scope.22.id=function:_sync_many_args
scope.22.kind=function
scope.22.startLine=119
scope.22.endLine=124
scope.22.semanticHash=c9c4a4f9c3889948
scope.23.id=function:_board_visual_sync_deferred
scope.23.kind=function
scope.23.startLine=126
scope.23.endLine=133
scope.23.semanticHash=638d728bf3bdd958
scope.24.id=function:<anonymous>#10
scope.24.kind=function
scope.24.startLine=127
scope.24.endLine=132
scope.24.semanticHash=2daa7a560c39bcf4
scope.25.id=function:runtime.build_board_visual_feedback_port
scope.25.kind=function
scope.25.startLine=135
scope.25.endLine=147
scope.25.semanticHash=42228ff22632dff8
scope.26.id=function:<anonymous>#11
scope.26.kind=function
scope.26.startLine=136
scope.26.endLine=146
scope.26.semanticHash=834c55ea2c0855a0
scope.27.id=function:port.sync_many
scope.27.kind=function
scope.27.startLine=138
scope.27.endLine=144
scope.27.semanticHash=68b11fd44163c0f4
scope.28.id=function:runtime.build_anim_gate_port
scope.28.kind=function
scope.28.startLine=149
scope.28.endLine=153
scope.28.semanticHash=43886d35daf27bf6
scope.29.id=function:<anonymous>#12
scope.29.kind=function
scope.29.startLine=150
scope.29.endLine=152
scope.29.semanticHash=12f9e3042e99e68e
]]
