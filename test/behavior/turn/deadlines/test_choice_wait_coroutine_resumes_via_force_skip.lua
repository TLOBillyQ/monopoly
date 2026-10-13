-- luacheck: std +busted
require("test.bootstrap").install_package_paths()
local luassert = assert
local function _assert_same(actual, expected, message)
  luassert.is.same(expected, actual, message)
end
local function _assert_not_equal(actual, expected, message)
  luassert.is_not(expected, actual, message)
end
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

describe("TestChoiceWaitCoroutineResumesViaForceSkip", function()

it("test_force_skip_dispatch_leaves_choice_wait_and_clears_choice", function()
  local game = _new_game()
  game.turn.pending_choice = {
    id = "c2",
    kind = "weird",
    options = {},
    allow_cancel = false,
  }
  local scheduler = TurnScheduler:new(game, _phases())

  _assert_same(scheduler:run_turn(), "wait_choice")
  game.turn._choice_force_skip_pending = true
  scheduler:step(0)

  luassert.is_nil(game.turn.pending_choice)
  luassert.is_nil(game.turn._choice_force_skip_pending)
  _assert_not_equal(game.turn.phase, "wait_choice")
end)

it("test_stale_force_skip_is_consumed_without_affecting_later_choice", function()
  local game = _new_game()
  local scheduler = TurnScheduler:new(game, _phases())

  game.turn._choice_force_skip_pending = true
  luassert.is_nil(scheduler:run_turn())
  luassert.is_nil(game.turn._choice_force_skip_pending)

  scheduler:reset()
  game.turn.pending_choice = { id = "fresh", kind = "weird", options = {}, allow_cancel = false }
  _assert_same(scheduler:run_turn(), "wait_choice")
  luassert.is_not_nil(game.turn.pending_choice)
end)

end)
