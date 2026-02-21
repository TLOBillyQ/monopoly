local gameplay_loop = require("src.game.flow.turn.GameplayLoop")
local turn_action_port_adapter = require("src.app.ports.TurnActionPortAdapter")
local gameplay_loop_ports_adapter = require("src.presentation.api.GameplayLoopPortsAdapter")

local M = {}

local function _start_tick_loop(state, current_game_ref, interval)
  require "vendor.third_party.Utils"
  local tick_interval = interval or 1
  local tick_seconds = math.tofixed(tick_interval) / 30.0
  SetFrameOut(tick_interval, function()
    gameplay_loop.tick(current_game_ref[1], state, tick_seconds)
  end, -1)
end

function M.start(state, current_game_ref)
  assert(state ~= nil, "missing state")
  assert(type(current_game_ref) == "table", "missing current_game_ref")
  if current_game_ref[1] then
    return current_game_ref[1]
  end

  state.turn_action_port = turn_action_port_adapter.build(state)
  state.gameplay_loop_ports = gameplay_loop_ports_adapter.build(state)
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
