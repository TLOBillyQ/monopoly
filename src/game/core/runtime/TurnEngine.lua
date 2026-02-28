local runtime_constants = require("Config.RuntimeConstants")
local turn_flow = require("src.game.flow.turn.TurnFlow")
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
  self.experimental = opts.experimental_coroutine_turn
  if self.experimental == nil then
    self.experimental = runtime_constants.experimental_coroutine_turn == true
  end
  self.mode = self.experimental and "coroutine" or "legacy"
  if self.mode == "legacy" then
    self.legacy_flow = opts.legacy_flow or turn_flow:new(game, phases)
    self.turn_mgr = self.legacy_flow
    self.session = nil
    return
  end
  self.legacy_flow = opts.legacy_flow
  self.turn_mgr = _build_turn_mgr(self)
  self.session = session_factory.new({
    game = game,
    phases = phases,
    mode = "coroutine",
    turn_mgr = self.turn_mgr,
  })
end

function turn_engine:get_legacy_flow()
  return self.legacy_flow
end

function turn_engine:is_coroutine_mode()
  return self.mode == "coroutine"
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
  if engine.mode ~= "coroutine" then
    return nil
  end
  local snapshot = engine.session and engine.session:snapshot() or nil
  compat_bridge.sync_to_legacy_turn(engine.game, snapshot)
  return snapshot
end

function turn_engine:dispatch(action)
  if self.mode == "legacy" then
    return self.legacy_flow:dispatch(action)
  end
  scheduler.dispatch(self.session, action_router.from_action(action))
  local res = scheduler.step(self.session, 0)
  _sync_snapshot(self)
  return res and res.wait_state or nil
end

function turn_engine:run_turn()
  if self.mode == "legacy" then
    return self.legacy_flow:run_turn()
  end
  local res = scheduler.step(self.session, 0)
  _sync_snapshot(self)
  return res and res.wait_state or nil
end

return turn_engine
