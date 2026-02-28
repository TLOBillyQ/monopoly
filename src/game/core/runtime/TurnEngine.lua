local scheduler = require("src.game.runtime_coroutine.Scheduler")
local session_factory = require("src.game.runtime_coroutine.Session")
local action_router = require("src.game.runtime_coroutine.ActionRouter")
local compat_bridge = require("src.game.runtime_coroutine.CompatBridge")
require "vendor.third_party.ClassUtils"

local turn_engine = Class("TurnEngine")

local function _emit_turn_prompt(turn, player_id)
  if not (turn and player_id) then
    return
  end
  turn.turn_start_prompt_seq = (turn.turn_start_prompt_seq or 0) + 1
  turn.turn_start_prompt_player_id = player_id
end

local function _mark_dirty(game)
  if game and game.dirty then
    game.dirty.turn = true
    game.dirty.any = true
  end
end

local function _build_turn_mgr(engine)
  local mgr = {
    game = engine.game,
    phases = engine.phases,
  }

  function mgr:next_player()
    return engine:next_player()
  end

  return mgr
end

function turn_engine:init(game, phases, opts)
  assert(game ~= nil, "missing game")
  assert(phases ~= nil, "missing phases")
  opts = opts or {}
  self.game = game
  self.phases = phases
  self.mode = "coroutine"
  self.turn_mgr = _build_turn_mgr(self)
  self.session = session_factory.new({
    game = game,
    phases = phases,
    mode = "coroutine",
    turn_mgr = self.turn_mgr,
  })
end

function turn_engine:is_coroutine_mode()
  return true
end

function turn_engine:next_player()
  local game = self.game
  local count = #game.players
  local current = game.turn.current_player_index
  local next_index = current % count + 1
  game.turn.current_player_index = next_index
  local next_player = game.players[next_index]
  _emit_turn_prompt(game.turn, next_player and next_player.id)
  _mark_dirty(game)
end

local function _sync_snapshot(engine)
  local snapshot = engine.session and engine.session:snapshot() or nil
  compat_bridge.sync_to_legacy_turn(engine.game, snapshot)
  return snapshot
end

function turn_engine:dispatch(action)
  scheduler.dispatch(self.session, action_router.from_action(action))
  local res = scheduler.step(self.session, 0)
  _sync_snapshot(self)
  return res and res.wait_state or nil
end

function turn_engine:run_turn()
  local res = scheduler.step(self.session, 0)
  _sync_snapshot(self)
  return res and res.wait_state or nil
end

return turn_engine
