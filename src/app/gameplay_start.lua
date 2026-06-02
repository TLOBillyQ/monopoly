local gameplay_loop = require("src.turn.loop")
local turn_dispatch = require("src.turn.actions.action_dispatcher")
local presentation_ports = require("src.ui.ports")
local runtime_deps = require("src.ui.coord.deps")
local camera_sync = require("src.ui.ports.ui_sync")._camera
local tick_clock = require("src.turn.loop.tick_clock")
local live_handle = require("src.app.testing.live_handle")

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
  state.presentation_runtime = runtime_deps.build({ camera_sync = camera_sync })
  local current_game = gameplay_loop.new_game(state)
  current_game_ref[1] = current_game
  -- Expose the running game + state to the e2e profile lane's editor seam.
  -- Inert in every headless/production path (nothing reads it unless an e2e
  -- snippet does); the lane needs state to pump gameplay_loop.tick.
  live_handle.set(current_game, state)
  _prime_first_turn(current_game)
  gameplay_loop.set_game(state, current_game)

  if not state.tick_started then
    state.tick_started = true
    _start_tick_loop(state, current_game_ref)
  end

  return current_game
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=016f7d79b2082a69
scope.0.id=chunk:src/app/gameplay_start.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=80
scope.0.semanticHash=9a8c66336898eb89
scope.1.id=function:anonymous@15:15
scope.1.kind=function
scope.1.startLine=15
scope.1.endLine=18
scope.1.semanticHash=a42c25e7eb0028d2
scope.2.id=function:_start_tick_loop:11
scope.2.kind=function
scope.2.startLine=11
scope.2.endLine=19
scope.2.semanticHash=c894b8629863dc3c
scope.3.id=function:_build_gameplay_loop_ports:21
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=23
scope.3.semanticHash=756b2bf75843a40d
scope.4.id=function:anonymous@27:27
scope.4.kind=function
scope.4.startLine=27
scope.4.endLine=29
scope.4.semanticHash=2b8db4f111b80d33
scope.5.id=function:anonymous@30:30
scope.5.kind=function
scope.5.startLine=30
scope.5.endLine=32
scope.5.semanticHash=ab6752f430f38aac
scope.6.id=function:_build_turn_action_port:25
scope.6.kind=function
scope.6.startLine=25
scope.6.endLine=34
scope.6.semanticHash=3bbf4229630177d5
scope.7.id=function:_should_prime_first_turn:36
scope.7.kind=function
scope.7.startLine=36
scope.7.endLine=42
scope.7.semanticHash=a0d3f3c3212a5fb6
scope.8.id=function:_prime_first_turn:44
scope.8.kind=function
scope.8.startLine=44
scope.8.endLine=50
scope.8.semanticHash=10f31c361988fe44
scope.9.id=function:M.start:52
scope.9.kind=function
scope.9.startLine=52
scope.9.endLine=77
scope.9.semanticHash=69076c28d212da39
]]
