local session = require("src.turn.timing.session")

describe("bankruptcy_session", function()
  it("_test_mark_phase_default_sets_phase_and_dirty", function()
    local game = {
      turn = {},
      dirty = {}
    }
    session._mark_phase_default(game, "roll")
    assert(game.turn.phase == "roll", "should set turn phase")
    assert(game.dirty.turn == true, "should mark turn dirty")
    assert(game.dirty.any == true, "should mark any dirty")
  end)

  it("_test_mark_phase_default_no_game_returns_early", function()
    local result = session._mark_phase_default(nil, "roll")
    assert(result == nil, "should return nil when no game")
  end)

  it("_test_mark_phase_default_no_turn_returns_early", function()
    local game = {}
    local result = session._mark_phase_default(game, "roll")
    assert(result == nil, "should return nil when no turn")
    assert(game.turn == nil, "should not create turn table")
  end)

  it("_test_mark_phase_default_no_dirty_ok", function()
    local game = {
      turn = {}
    }
    local result = session._mark_phase_default(game, "move")
    assert(game.turn.phase == "move", "should set phase even without dirty")
    assert(result == nil, "should return nil (no explicit return on success)")
  end)
end)
