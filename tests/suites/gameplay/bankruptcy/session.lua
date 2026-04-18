local session = require("src.turn.timing.session")

local function _test_mark_phase_default_sets_phase_and_dirty()
  local game = {
    turn = {},
    dirty = {}
  }
  session._mark_phase_default(game, "roll")
  assert(game.turn.phase == "roll", "should set turn phase")
  assert(game.dirty.turn == true, "should mark turn dirty")
  assert(game.dirty.any == true, "should mark any dirty")
end

local function _test_mark_phase_default_no_game_returns_early()
  local result = session._mark_phase_default(nil, "roll")
  assert(result == nil, "should return nil when no game")
end

local function _test_mark_phase_default_no_turn_returns_early()
  local game = {}
  local result = session._mark_phase_default(game, "roll")
  assert(result == nil, "should return nil when no turn")
  assert(game.turn == nil, "should not create turn table")
end

local function _test_mark_phase_default_no_dirty_ok()
  local game = {
    turn = {}
  }
  local result = session._mark_phase_default(game, "move")
  assert(game.turn.phase == "move", "should set phase even without dirty")
  assert(result == nil, "should return nil (no explicit return on success)")
end

return {
  name = "bankruptcy_session",
  tests = {
    { name = "_test_mark_phase_default_sets_phase_and_dirty", run = _test_mark_phase_default_sets_phase_and_dirty },
    { name = "_test_mark_phase_default_no_game_returns_early", run = _test_mark_phase_default_no_game_returns_early },
    { name = "_test_mark_phase_default_no_turn_returns_early", run = _test_mark_phase_default_no_turn_returns_early },
    { name = "_test_mark_phase_default_no_dirty_ok", run = _test_mark_phase_default_no_dirty_ok },
  },
}
