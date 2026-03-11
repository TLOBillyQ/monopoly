local scheduler = require("src.game.scheduler")
local session_factory = require("src.game.scheduler.session")
local action_router = require("src.game.scheduler.action_router")
local turn_script = require("src.game.flow.turn.script")
require "vendor.third_party.ClassUtils"

local scheduler_turn_runtime = Class("SchedulerTurnRuntime")

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

function scheduler_turn_runtime:init(game, phases, opts)
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
    script_factory = turn_script.create,
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
  scheduler.dispatch(self.session, action_router.from_action(action))
  local res = scheduler.step(self.session, 0)
  _sync_snapshot(self)
  return res and res.wait_state or nil
end

function scheduler_turn_runtime:run_turn()
  local res = scheduler.step(self.session, 0)
  _sync_snapshot(self)
  return res and res.wait_state or nil
end

return scheduler_turn_runtime
