local gameplay_loop = require("src.turn.loop")
local turn_dispatch = require("src.turn.actions.action_dispatcher")
local presentation_ports = require("src.ui.ports")
local runtime_deps = require("src.ui.ctl.deps")
local tick_clock = require("src.turn.loop.tick_clock")

local M = {}

local function _start_tick_loop(state, current_game_ref, interval)
  require "vendor.third_party.Utils"
  local tick_interval = interval or 1
  local fallback_tick_seconds = tick_clock.resolve_fallback_tick_seconds(tick_interval)
  SetFrameOut(tick_interval, function()
    local tick_seconds = tick_clock.resolve_tick_seconds(state, fallback_tick_seconds)
    gameplay_loop.tick(current_game_ref[1], state, tick_seconds)
  end, -1)
end

local function _build_gameplay_loop_ports()
  return presentation_ports.build()
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

local function _should_prime_first_turn(game)
  local turn = game and game.turn or nil
  return turn ~= nil
    and turn.turn_count == 0
    and turn.phase == "start"
    and turn.pending_choice == nil
end

local function _prime_first_turn(game)
  if not _should_prime_first_turn(game) then
    return false
  end
  game:advance_turn()
  return true
end

function M.start(state, current_game_ref)
  assert(state ~= nil, "missing state")
  assert(type(current_game_ref) == "table", "missing current_game_ref")
  if current_game_ref[1] then
    return current_game_ref[1]
  end

  state.turn_action_port = _build_turn_action_port()
  state.gameplay_loop_ports = _build_gameplay_loop_ports()
  state.presentation_runtime = runtime_deps.build()
  local current_game = gameplay_loop.new_game(state)
  current_game_ref[1] = current_game
  _prime_first_turn(current_game)
  gameplay_loop.set_game(state, current_game)

  if not state.tick_started then
    state.tick_started = true
    _start_tick_loop(state, current_game_ref)
  end

  return current_game
end

return M
