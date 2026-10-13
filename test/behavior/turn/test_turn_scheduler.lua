local check = require("luassert")
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

describe("TestTurnScheduler", function()

it("test_phase_handler_accepts_callable_table", function()
  local visited = false
  local callable = setmetatable({}, {
    __call = function()
      visited = true
      return nil
    end,
  })
  local scheduler = TurnScheduler:new(_new_game(), { start = callable })

  check.is_nil(scheduler:run_turn())
  check.is_true(visited)
end)

it("test_phase_progress_is_observable_through_game_turn_and_dirty", function()
  local events = {}
  local game = _new_game()
  local scheduler = TurnScheduler:new(game, _phases(events), _handlers(events))

  scheduler:run_turn()
  check.same(game.turn.phase, "wait_action")
  check.is_true(game.dirty.turn)

  scheduler:dispatch({ type = "action" })
  check.same(game.turn.phase, "wait_choice")
end)

it("test_reset_clears_wait_pending_action_and_choice_elapsed_seconds", function()
  local events = {}
  local game = _new_game()
  local scheduler = TurnScheduler:new(game, _phases(events), _handlers(events))

  scheduler:run_turn()
  scheduler:dispatch({ type = "action" })
  scheduler:step(3.0)
  scheduler:reset()
  check.same(game.turn.choice_elapsed_seconds, 0)
  check.same(scheduler:run_turn(), "wait_action")
end)

it("test_run_turn_dispatches_pending_actions_through_all_wait_states", function()
  local events = {}
  local scheduler = TurnScheduler:new(_new_game(), _phases(events), _handlers(events))

  check.same(scheduler:run_turn(), "wait_action")
  check.same(scheduler:dispatch({ type = "action" }), "wait_choice")
  check.same(scheduler:dispatch({ type = "choice" }), "wait_move_anim")
  check.same(scheduler:dispatch({ type = "move_anim_done" }), "wait_action_anim")
  check.same(scheduler:dispatch({ type = "action_anim_done" }), "wait_landing_visual")
  check.same(scheduler:dispatch({ type = "landing_visual_done" }), "detained_wait")
  check.same(scheduler:dispatch({ type = "detained_done" }), "inter_turn_wait")
  check.same(scheduler:dispatch({ type = "inter_turn_done" }), "wait_seconds")
  check.is_nil(scheduler:dispatch({ type = "seconds_done" }))
  check.same(events, {
    "start", "action", "action", "choice", "choice", "move_anim", "move_anim",
    "action_anim", "action_anim", "landing_visual", "landing_visual", "detained", "detained",
    "inter_turn", "inter_turn", "seconds", "seconds", "done",
  })
end)

it("test_step_accumulates_choice_elapsed_seconds_and_mirrors_game_turn", function()
  local events = {}
  local game = _new_game()
  local scheduler = TurnScheduler:new(game, _phases(events), _handlers(events))

  scheduler:run_turn()
  scheduler:dispatch({ type = "action" })
  scheduler:step(2.5)
  check.same(game.turn.choice_elapsed_seconds, 2.5)
  scheduler:step(1.5)
  check.same(game.turn.choice_elapsed_seconds, 4.0)
end)

end)
