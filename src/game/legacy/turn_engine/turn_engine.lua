local scheduler = require("src.game.scheduler.scheduler")
local session_factory = require("src.game.scheduler.session")
local action_router = require("src.game.scheduler.action_router")
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
  self.turn_mgr = _build_turn_mgr(self)
  self.session = session_factory.new({
    game = game,
    phases = phases,
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
  local game = engine.game
  if type(game) == "table" and type(game.turn) == "table" and type(snapshot) == "table" then
    if snapshot.wait_state then
      game.turn.phase = snapshot.wait_state
    elseif snapshot.current_state then
      game.turn.phase = snapshot.current_state
    end
  end
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
