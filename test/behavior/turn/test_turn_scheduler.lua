local lu = require("luaunit")
local support = require("test.support.shared_support")
local TurnScheduler = require("src.turn.scheduler")

local function _new_game()
  local game = support.new_game()
  game.turn.current_player_index = 1
  return game
end

local function _handlers(events)
  return {
    action = function(session)
      events[#events + 1] = "action"
      local action = session:take_pending_action()
      if action then return { next_state = "wait_choice" } end
      return { wait = true }
    end,
    choice = function(session)
      events[#events + 1] = "choice"
      if session:take_pending_action() then return { next_state = "wait_move_anim" } end
      return { wait = true }
    end,
    move_anim = function(session)
      events[#events + 1] = "move_anim"
      if session:take_pending_action() then return { next_state = "wait_action_anim" } end
      return { wait = true }
    end,
    action_anim = function(session)
      events[#events + 1] = "action_anim"
      if session:take_pending_action() then return { next_state = "wait_landing_visual" } end
      return { wait = true }
    end,
    landing_visual = function(session)
      events[#events + 1] = "landing_visual"
      if session:take_pending_action() then return { next_state = "detained_wait" } end
      return { wait = true }
    end,
    detained = function(session)
      events[#events + 1] = "detained"
      if session:take_pending_action() then return { next_state = "inter_turn_wait" } end
      return { wait = true }
    end,
    inter_turn = function(session)
      events[#events + 1] = "inter_turn"
      if session:take_pending_action() then return { next_state = "wait_seconds" } end
      return { wait = true }
    end,
    seconds = function(session)
      events[#events + 1] = "seconds"
      if session:take_pending_action() then return { next_state = "done" } end
      return { wait = true }
    end,
  }
end

local function _phases(events)
  return {
    start = function()
      events[#events + 1] = "start"
      return "wait_action"
    end,
    done = function()
      events[#events + 1] = "done"
      return nil
    end,
  }
end

TestTurnScheduler = {}

function TestTurnScheduler:test_run_turn_dispatches_pending_actions_through_all_wait_states()
  local events = {}
  local scheduler = TurnScheduler:new(_new_game(), _phases(events), _handlers(events))

  lu.assertEquals(scheduler:run_turn(), "wait_action")
  lu.assertEquals(scheduler:dispatch({ type = "action" }), "wait_choice")
  lu.assertEquals(scheduler:dispatch({ type = "choice" }), "wait_move_anim")
  lu.assertEquals(scheduler:dispatch({ type = "move_anim_done" }), "wait_action_anim")
  lu.assertEquals(scheduler:dispatch({ type = "action_anim_done" }), "wait_landing_visual")
  lu.assertEquals(scheduler:dispatch({ type = "landing_visual_done" }), "detained_wait")
  lu.assertEquals(scheduler:dispatch({ type = "detained_done" }), "inter_turn_wait")
  lu.assertEquals(scheduler:dispatch({ type = "inter_turn_done" }), "wait_seconds")
  lu.assertNil(scheduler:dispatch({ type = "seconds_done" }))
  lu.assertEquals(events, {
    "start", "action", "action", "choice", "choice", "move_anim", "move_anim",
    "action_anim", "action_anim", "landing_visual", "landing_visual", "detained", "detained",
    "inter_turn", "inter_turn", "seconds", "seconds", "done",
  })
end

function TestTurnScheduler:test_step_accumulates_choice_elapsed_seconds_and_mirrors_game_turn()
  local events = {}
  local game = _new_game()
  local scheduler = TurnScheduler:new(game, _phases(events), _handlers(events))

  scheduler:run_turn()
  scheduler:dispatch({ type = "action" })
  scheduler:step(2.5)
  lu.assertEquals(game.turn.choice_elapsed_seconds, 2.5)
  scheduler:step(1.5)
  lu.assertEquals(game.turn.choice_elapsed_seconds, 4.0)
end

function TestTurnScheduler:test_reset_clears_wait_pending_action_and_choice_elapsed_seconds()
  local events = {}
  local game = _new_game()
  local scheduler = TurnScheduler:new(game, _phases(events), _handlers(events))

  scheduler:run_turn()
  scheduler:dispatch({ type = "action" })
  scheduler:step(3.0)
  scheduler:reset()
  lu.assertEquals(game.turn.choice_elapsed_seconds, 0)
  lu.assertEquals(scheduler:run_turn(), "wait_action")
end

function TestTurnScheduler:test_phase_progress_is_observable_through_game_turn_and_dirty()
  local events = {}
  local game = _new_game()
  local scheduler = TurnScheduler:new(game, _phases(events), _handlers(events))

  scheduler:run_turn()
  lu.assertEquals(game.turn.phase, "wait_action")
  lu.assertTrue(game.dirty.turn)

  scheduler:dispatch({ type = "action" })
  lu.assertEquals(game.turn.phase, "wait_choice")
end

function TestTurnScheduler:test_phase_handler_accepts_callable_table()
  local visited = false
  local callable = setmetatable({}, {
    __call = function()
      visited = true
      return nil
    end,
  })
  local scheduler = TurnScheduler:new(_new_game(), { start = callable })

  lu.assertNil(scheduler:run_turn())
  lu.assertTrue(visited)
end

return TestTurnScheduler
