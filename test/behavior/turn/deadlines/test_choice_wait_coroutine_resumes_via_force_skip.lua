local lu = require("luaunit")
local support = require("test.support.shared_support")
local TurnScheduler = require("src.turn.scheduler")

local function _new_game()
  local game = support.new_game()
  game.turn.current_player_index = 1
  return game
end

local function _phases()
  return {
    start = function()
      return "wait_choice", { next_state = "after_choice", next_args = {} }
    end,
    after_choice = function()
      return nil
    end,
  }
end

TestChoiceWaitCoroutineResumesViaForceSkip = {}

function TestChoiceWaitCoroutineResumesViaForceSkip:test_force_skip_dispatch_leaves_choice_wait_and_clears_choice()
  local game = _new_game()
  game.turn.pending_choice = {
    id = "c2",
    kind = "weird",
    options = {},
    allow_cancel = false,
  }
  local scheduler = TurnScheduler:new(game, _phases())

  lu.assertEquals(scheduler:run_turn(), "wait_choice")
  game.turn._choice_force_skip_pending = true
  scheduler:step(0)

  lu.assertNil(game.turn.pending_choice)
  lu.assertNil(game.turn._choice_force_skip_pending)
  lu.assertNotEquals(game.turn.phase, "wait_choice")
end

function TestChoiceWaitCoroutineResumesViaForceSkip:test_stale_force_skip_is_consumed_without_affecting_later_choice()
  local game = _new_game()
  local scheduler = TurnScheduler:new(game, _phases())

  game.turn._choice_force_skip_pending = true
  lu.assertNil(scheduler:run_turn())
  lu.assertNil(game.turn._choice_force_skip_pending)

  scheduler:reset()
  game.turn.pending_choice = { id = "fresh", kind = "weird", options = {}, allow_cancel = false }
  lu.assertEquals(scheduler:run_turn(), "wait_choice")
  lu.assertNotNil(game.turn.pending_choice)
end

return TestChoiceWaitCoroutineResumesViaForceSkip
