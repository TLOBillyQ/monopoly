local check = require("luassert")
local support = require("test.support.shared_support")
local fixtures = require("test.support.gameplay_fixtures")
local gameplay_loop = require("src.turn.loop.init")
local timing = require("src.config.gameplay.timing")

describe("TestGameClock", function()

local function _with_time_limit(limit, fn)
  local saved = timing.game_time_limit_seconds
  timing.game_time_limit_seconds = limit
  local ok, err = pcall(fn)
  timing.game_time_limit_seconds = saved
  if not ok then error(err) end
end

local function _new_subject()
  local game = support.new_game({ players = { "P1", "P2" }, ai = {} })
  local state = fixtures.build_loop_state()
  state.auto_runner.next_action = function() return nil end
  return game, state
end

it("test_finished_game_tick_freezes_the_game_clock", function()
  local game, state = _new_subject()
  game.game_time_seconds = 10
  game.finished = true
  _with_time_limit(900, function()
    gameplay_loop.tick(game, state, 1.0)
  end)
  check.same(game.game_time_seconds, 10)
end)

it("test_nil_dt_keeps_the_clock_unchanged", function()
  local game, state = _new_subject()
  game.game_time_seconds = 3
  _with_time_limit(900, function()
    gameplay_loop.tick(game, state, nil)
  end)
  check.same(game.game_time_seconds, 3)
end)

it("test_no_time_limit_never_checks_victory", function()
  local game, state = _new_subject()
  local check_victory_calls = 0
  game.game_time_seconds = 1e9
  game.check_victory = function()
    check_victory_calls = check_victory_calls + 1
  end
  _with_time_limit(nil, function()
    gameplay_loop.tick(game, state, 1.0)
  end)
  check.same(check_victory_calls, 0)
end)

it("test_tick_accumulates_dt_on_the_game_clock", function()
  local game, state = _new_subject()
  _with_time_limit(900, function()
    gameplay_loop.tick(game, state, 0.5)
    gameplay_loop.tick(game, state, 0.25)
  end)
  check.same(game.game_time_seconds, 0.75)
end)

it("test_tick_checks_victory_on_the_frame_the_limit_is_reached", function()
  local game, state = _new_subject()
  local check_victory_calls = 0
  game.game_time_seconds = 899.5
  game.check_victory = function()
    check_victory_calls = check_victory_calls + 1
  end
  _with_time_limit(900, function()
    gameplay_loop.tick(game, state, 0.5)
  end)
  check.same(check_victory_calls, 1)
end)

end)
