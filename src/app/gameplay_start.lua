local gameplay_loop = require("src.turn.loop")
local turn_dispatch = require("src.turn.actions.action_dispatcher")
local presentation_ports = require("src.ui.ports")
local runtime_deps = require("src.ui.coord.deps")
local camera_sync = require("src.ui.ports.ui_sync")._camera
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
  state.presentation_runtime = runtime_deps.build({ camera_sync = camera_sync })
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

--[[ mutate4lua-manifest
version=2
projectHash=45824b3af1764582
scope.0.id=chunk:src/app/gameplay_start.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=75
scope.0.semanticHash=189017eb8f2aade9
scope.1.id=function:anonymous@14:14
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=17
scope.1.semanticHash=a42c25e7eb0028d2
scope.2.id=function:_start_tick_loop:10
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=18
scope.2.semanticHash=c894b8629863dc3c
scope.3.id=function:_build_gameplay_loop_ports:20
scope.3.kind=function
scope.3.startLine=20
scope.3.endLine=22
scope.3.semanticHash=756b2bf75843a40d
scope.4.id=function:anonymous@26:26
scope.4.kind=function
scope.4.startLine=26
scope.4.endLine=28
scope.4.semanticHash=2b8db4f111b80d33
scope.5.id=function:anonymous@29:29
scope.5.kind=function
scope.5.startLine=29
scope.5.endLine=31
scope.5.semanticHash=ab6752f430f38aac
scope.6.id=function:_build_turn_action_port:24
scope.6.kind=function
scope.6.startLine=24
scope.6.endLine=33
scope.6.semanticHash=3bbf4229630177d5
scope.7.id=function:_should_prime_first_turn:35
scope.7.kind=function
scope.7.startLine=35
scope.7.endLine=41
scope.7.semanticHash=a0d3f3c3212a5fb6
scope.8.id=function:_prime_first_turn:43
scope.8.kind=function
scope.8.startLine=43
scope.8.endLine=49
scope.8.semanticHash=10f31c361988fe44
scope.9.id=function:M.start:51
scope.9.kind=function
scope.9.startLine=51
scope.9.endLine=72
scope.9.semanticHash=16ef6208b31cf53a
]]
