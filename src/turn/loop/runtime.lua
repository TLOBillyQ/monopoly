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

-- 从 game 取当前回合相位判输入锁:回合推进是 turn 的事实,消费方(ui_sync 门控、
-- 按钮策略)经本谓词读同一份相位集合,不再各自复制表。缺 game/turn 视作不锁。
function runtime.is_game_input_blocked(game)
  local phase = game and game.turn and game.turn.phase or nil
  return runtime.is_phase_input_blocked(phase)
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
projectHash=ba6d0751d5b3eb06
scope.0.id=chunk:src/turn/loop/runtime.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=163
scope.0.semanticHash=e463d1a4fe6a2165
scope.1.id=function:runtime.is_phase_input_blocked
scope.1.kind=function
scope.1.startLine=15
scope.1.endLine=17
scope.1.semanticHash=92047a25c743520b
scope.2.id=function:runtime.is_game_input_blocked
scope.2.kind=function
scope.2.startLine=21
scope.2.endLine=24
scope.2.semanticHash=e8af86822fc69918
scope.3.id=function:_ui_sync_ports
scope.3.kind=function
scope.3.startLine=26
scope.3.endLine=28
scope.3.semanticHash=616a2ca60599c94f
scope.4.id=function:_has_sync_methods
scope.4.kind=function
scope.4.startLine=30
scope.4.endLine=32
scope.4.semanticHash=44d9ca3a54db4857
scope.5.id=function:runtime.sync_input_blocked
scope.5.kind=function
scope.5.startLine=34
scope.5.endLine=48
scope.5.semanticHash=60f28469b1d40b70
scope.6.id=function:_move_anim_just_finished
scope.6.kind=function
scope.6.startLine=50
scope.6.endLine=52
scope.6.semanticHash=5425394d76ae823b
scope.7.id=function:_should_unlock_next_turn
scope.7.kind=function
scope.7.startLine=54
scope.7.endLine=59
scope.7.semanticHash=2e1221b3a4fd5e33
scope.8.id=function:runtime.sync_phase_flags
scope.8.kind=function
scope.8.startLine=61
scope.8.endLine=72
scope.8.semanticHash=be70876c1d30a8f2
scope.9.id=function:_build_memoized_port
scope.9.kind=function
scope.9.startLine=74
scope.9.endLine=81
scope.9.semanticHash=131ed0d2c85b382c
scope.10.id=function:runtime.build_board_scene_port
scope.10.kind=function
scope.10.startLine=83
scope.10.endLine=87
scope.10.semanticHash=b4134f5cbbf4f5bb
scope.11.id=function:<anonymous>
scope.11.kind=function
scope.11.startLine=84
scope.11.endLine=86
scope.11.semanticHash=784c9bf78ae01893
scope.12.id=function:<anonymous>#2
scope.12.kind=function
scope.12.startLine=85
scope.12.endLine=85
scope.12.semanticHash=24f2b9b574225623
scope.13.id=function:runtime.build_popup_port
scope.13.kind=function
scope.13.startLine=89
scope.13.endLine=100
scope.13.semanticHash=443325fdad2cf123
scope.14.id=function:<anonymous>#3
scope.14.kind=function
scope.14.startLine=90
scope.14.endLine=99
scope.14.semanticHash=e74c25800b5c06cb
scope.15.id=function:<anonymous>#4
scope.15.kind=function
scope.15.startLine=92
scope.15.endLine=97
scope.15.semanticHash=cf795bbdc3cf3b3d
scope.16.id=function:<anonymous>#5
scope.16.kind=function
scope.16.startLine=93
scope.16.endLine=96
scope.16.semanticHash=18dd5a698f4ce929
scope.17.id=function:runtime.build_tip_output_port
scope.17.kind=function
scope.17.startLine=102
scope.17.endLine=112
scope.17.semanticHash=2c80c33f54a93160
scope.18.id=function:<anonymous>#6
scope.18.kind=function
scope.18.startLine=103
scope.18.endLine=111
scope.18.semanticHash=db94bea24d6fa0f8
scope.19.id=function:<anonymous>#7
scope.19.kind=function
scope.19.startLine=105
scope.19.endLine=109
scope.19.semanticHash=99fae81d64a114ba
scope.20.id=function:runtime.build_tile_feedback_port
scope.20.kind=function
scope.20.startLine=114
scope.20.endLine=124
scope.20.semanticHash=b24ddf200c95bd29
scope.21.id=function:<anonymous>#8
scope.21.kind=function
scope.21.startLine=115
scope.21.endLine=123
scope.21.semanticHash=e1145cbacff9e8b1
scope.22.id=function:<anonymous>#9
scope.22.kind=function
scope.22.startLine=117
scope.22.endLine=121
scope.22.semanticHash=c0566339b3114fad
scope.23.id=function:_sync_many_args
scope.23.kind=function
scope.23.startLine=126
scope.23.endLine=131
scope.23.semanticHash=c9c4a4f9c3889948
scope.24.id=function:_board_visual_sync_deferred
scope.24.kind=function
scope.24.startLine=133
scope.24.endLine=140
scope.24.semanticHash=638d728bf3bdd958
scope.25.id=function:<anonymous>#10
scope.25.kind=function
scope.25.startLine=134
scope.25.endLine=139
scope.25.semanticHash=2daa7a560c39bcf4
scope.26.id=function:runtime.build_board_visual_feedback_port
scope.26.kind=function
scope.26.startLine=142
scope.26.endLine=154
scope.26.semanticHash=42228ff22632dff8
scope.27.id=function:<anonymous>#11
scope.27.kind=function
scope.27.startLine=143
scope.27.endLine=153
scope.27.semanticHash=834c55ea2c0855a0
scope.28.id=function:port.sync_many
scope.28.kind=function
scope.28.startLine=145
scope.28.endLine=151
scope.28.semanticHash=68b11fd44163c0f4
scope.29.id=function:runtime.build_anim_gate_port
scope.29.kind=function
scope.29.startLine=156
scope.29.endLine=160
scope.29.semanticHash=43886d35daf27bf6
scope.30.id=function:<anonymous>#12
scope.30.kind=function
scope.30.startLine=157
scope.30.endLine=159
scope.30.semanticHash=12f9e3042e99e68e
]]
