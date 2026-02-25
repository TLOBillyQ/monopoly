local gameplay_loop = require("src.game.flow.turn.GameplayLoop")
local turn_dispatch = require("src.game.flow.turn.TurnDispatch")
local modal_ports = require("src.presentation.api.ports.ModalPorts")
local anim_ports = require("src.presentation.api.ports.AnimPorts")
local ui_sync_ports = require("src.presentation.api.ports.UISyncPorts")
local debug_ports = require("src.presentation.api.ports.DebugPorts")
local state_ports = require("src.presentation.api.ports.StatePorts")

local M = {}

local function _start_tick_loop(state, current_game_ref, interval)
  require "vendor.third_party.Utils"
  local tick_interval = interval or 1
  local tick_seconds = math.tofixed(tick_interval) / 30.0
  SetFrameOut(tick_interval, function()
    gameplay_loop.tick(current_game_ref[1], state, tick_seconds)
  end, -1)
end

local function _build_gameplay_loop_ports()
  return {
    modal = modal_ports.build(),
    anim = anim_ports.build(),
    ui_sync = ui_sync_ports.build(),
    debug = debug_ports.build(),
    state = state_ports.build(),
  }
end

local function _build_turn_action_port()
  return {
    dispatch_action = function(game, state, action, opts)
      return turn_dispatch.dispatch_action(game, state, action, opts)
    end,
    should_block_action = function(state, action_or_type)
      return turn_dispatch.should_block_action(state, action_or_type)
    end,
  }
end

function M.start(state, current_game_ref)
  assert(state ~= nil, "missing state")
  assert(type(current_game_ref) == "table", "missing current_game_ref")
  if current_game_ref[1] then
    return current_game_ref[1]
  end

  state.turn_action_port = _build_turn_action_port()
  state.gameplay_loop_ports = _build_gameplay_loop_ports()
  local current_game = gameplay_loop.new_game(state)
  current_game_ref[1] = current_game
  gameplay_loop.set_game(state, current_game)

  if not state.tick_started then
    state.tick_started = true
    _start_tick_loop(state, current_game_ref)
  end

  return current_game
end

return M
