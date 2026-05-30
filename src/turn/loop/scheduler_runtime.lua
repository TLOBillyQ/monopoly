local timing = require("src.turn.timing")
local dirty_tracker = require("src.state.dirty_tracker")
require "vendor.third_party.ClassUtils"

local scheduler_turn_runtime = Class("SchedulerTurnRuntime")

local function _emit_turn_prompt(turn, player_id)
  if not (turn and player_id) then
    return
  end
  turn.turn_start_prompt_seq = (turn.turn_start_prompt_seq or 0) + 1
  turn.turn_start_prompt_player_id = player_id
end

local _mark_dirty = dirty_tracker.mark_turn

local function _build_turn_mgr(runtime)
  local mgr = {
    game = runtime.game,
    phases = runtime.phases,
  }

  function mgr:next_player()
    return runtime:next_player()
  end

  return mgr
end

function scheduler_turn_runtime:init(game, phases)
  assert(game ~= nil, "missing game")
  assert(phases ~= nil, "missing phases")
  self.game = game
  self.phases = phases
  self.turn_mgr = _build_turn_mgr(self)
  self.session = timing.new({
    game = game,
    phases = phases,
    turn_mgr = self.turn_mgr,
    script_factory = timing.create,
  })
end

function scheduler_turn_runtime:is_coroutine_mode()
  return true
end

function scheduler_turn_runtime:next_player()
  local game = self.game
  local count = #game.players
  local current = game.turn.current_player_index
  local next_index = current % count + 1
  game.turn.current_player_index = next_index
  local next_player = game.players[next_index]
  _emit_turn_prompt(game.turn, next_player and next_player.id)
  _mark_dirty(game)
end

local function _sync_snapshot(runtime)
  local snapshot = runtime.session and runtime.session:snapshot() or nil
  local game = runtime.game
  if type(game) == "table" and type(game.turn) == "table" and type(snapshot) == "table" then
    if snapshot.wait_state then
      game.turn.phase = snapshot.wait_state
    elseif snapshot.current_state then
      game.turn.phase = snapshot.current_state
    end
  end
  return snapshot
end

function scheduler_turn_runtime:dispatch(action)
  timing.dispatch(self.session, timing.from_action(action))
  local res = timing.step(self.session, 0)
  _sync_snapshot(self)
  return res and res.wait_state or nil
end

function scheduler_turn_runtime:run_turn()
  local res = timing.step(self.session, 0)
  _sync_snapshot(self)
  return res and res.wait_state or nil
end

return scheduler_turn_runtime

--[[ mutate4lua-manifest
version=2
projectHash=7e0f2764346b3c93
scope.0.id=chunk:src/turn/loop/scheduler_runtime.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=86
scope.0.semanticHash=4337a004f5c9e898
scope.1.id=function:_emit_turn_prompt:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=13
scope.1.semanticHash=7220482405d2100d
scope.2.id=function:mgr:next_player:23
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=25
scope.2.semanticHash=b5fa591b800e05ea
scope.3.id=function:_build_turn_mgr:17
scope.3.kind=function
scope.3.startLine=17
scope.3.endLine=28
scope.3.semanticHash=627a57466f7552c2
scope.4.id=function:scheduler_turn_runtime:init:30
scope.4.kind=function
scope.4.startLine=30
scope.4.endLine=42
scope.4.semanticHash=83cd959edf1a9387
scope.5.id=function:scheduler_turn_runtime:is_coroutine_mode:44
scope.5.kind=function
scope.5.startLine=44
scope.5.endLine=46
scope.5.semanticHash=53f30ad94fd87be2
scope.6.id=function:scheduler_turn_runtime:next_player:48
scope.6.kind=function
scope.6.startLine=48
scope.6.endLine=57
scope.6.semanticHash=865a04a6db131853
scope.7.id=function:_sync_snapshot:59
scope.7.kind=function
scope.7.startLine=59
scope.7.endLine=70
scope.7.semanticHash=1970889fcb3fe781
scope.8.id=function:scheduler_turn_runtime:dispatch:72
scope.8.kind=function
scope.8.startLine=72
scope.8.endLine=77
scope.8.semanticHash=2ba41b789d2d8353
scope.9.id=function:scheduler_turn_runtime:run_turn:79
scope.9.kind=function
scope.9.startLine=79
scope.9.endLine=83
scope.9.semanticHash=5b81dd4ec698bc95
]]
