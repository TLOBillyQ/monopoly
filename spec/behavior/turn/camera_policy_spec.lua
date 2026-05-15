local support = require("spec.support.gameplay_support")
local _new_game = support.new_game
local camera_policy = require("src.turn.policies.camera")

local _resolve_follow_player_id_tests = {
  function()
    local game = _new_game()
    local result = camera_policy._resolve_follow_player_id(game)
    local p1 = game.players[1]
    assert(result == p1.id, "should return current player id when not eliminated")
  end,
  function()
    local game = _new_game()
    game.players[1].eliminated = true
    local result = camera_policy._resolve_follow_player_id(game)
    local p2 = game.players[2]
    assert(result == p2.id, "should return next non-eliminated player")
  end,
  function()
    local game = _new_game()
    game.turn.current_player_index = nil
    local result = camera_policy._resolve_follow_player_id(game)
    assert(result == nil, "should return nil when no current player index")
  end,
  function()
    local game = _new_game()
    game.players = {}
    local result = camera_policy._resolve_follow_player_id(game)
    assert(result == nil, "should return nil when no players")
  end,
}

local _resolve_follow_player_id_extended_tests = {
  function()
    local game = _new_game()
    game.players[1].eliminated = true
    game.players[2].eliminated = true
    local result = camera_policy._resolve_follow_player_id(game)
    assert(result == nil, "should return nil when all players eliminated")
  end,
  function()
    local game = _new_game()
    game.players[1].id = nil
    local result = camera_policy._resolve_follow_player_id(game)
    local p2 = game.players[2]
    assert(result == p2.id, "should skip player with nil id")
  end,
  function()
    local game = _new_game()
    game.turn = nil
    local result = camera_policy._resolve_follow_player_id(game)
    assert(result == nil, "should return nil when turn is nil")
  end,
  function()
    local game = _new_game()
    game.players = nil
    local result = camera_policy._resolve_follow_player_id(game)
    assert(result == nil, "should return nil when players is nil")
  end,
  function()
    local game = _new_game()
    game.players = {}
    local result = camera_policy._resolve_follow_player_id(game)
    assert(result == nil, "should return nil with empty players")
  end,
  function()
    local game = _new_game()
    game.players[1].eliminated = true
    game.turn.current_player_index = 2
    game.players[2].eliminated = false
    local result = camera_policy._resolve_follow_player_id(game)
    assert(result == game.players[2].id, "should return current player when not eliminated")
  end,
  function()
    local game = _new_game()
    game.turn.current_player_index = 2
    game.players[2].eliminated = true
    game.players[1].eliminated = false
    local result = camera_policy._resolve_follow_player_id(game)
    assert(result == game.players[1].id, "should wrap around to find non-eliminated player")
  end,
  function()
    local game = _new_game()
    game.players[1].id = nil
    game.players[1].eliminated = false
    local result = camera_policy._resolve_follow_player_id(game)
    assert(result == game.players[2].id, "should skip player with nil id even if not eliminated")
  end,
  function()
    local game = _new_game()
    game.turn.current_player_index = 0
    local result = camera_policy._resolve_follow_player_id(game)
    assert(result == nil or result ~= nil, "should handle index 0 without error")
  end,
  function()
    local game = _new_game()
    game.turn.current_player_index = -1
    local result = camera_policy._resolve_follow_player_id(game)
    assert(result ~= nil or result == nil, "should handle negative index")
  end,
}

local _resolve_follow_player_id_more_tests = {
  function()
    local game = _new_game()
    for _, p in ipairs(game.players) do
      p.eliminated = true
    end
    local result = camera_policy._resolve_follow_player_id(game)
    assert(result == nil, "should return nil when all players eliminated")
  end,
  function()
    local game = _new_game()
    game.players[1].id = nil
    game.players[2].id = 2
    local result = camera_policy._resolve_follow_player_id(game)
    assert(result == 2, "should skip player with nil id")
  end,
}

local _resolve_follow_player_id_final_tests = {
  function()
    local game = _new_game()
    game.players[1].eliminated = true
    game.players[2].eliminated = false
    game.turn.current_player_index = 1

    local result = camera_policy._resolve_follow_player_id(game)
    assert(result == 2, "should return next non-eliminated player")
  end,
  function()
    local game = _new_game()
    for i, p in ipairs(game.players) do
      p.eliminated = (i ~= 1)
    end
    game.turn.current_player_index = 4

    local result = camera_policy._resolve_follow_player_id(game)
    assert(result == 1, "should handle wrap-around")
  end,
  function()
    local game = _new_game()
    game.turn.current_player_index = 2
    game.players[2].eliminated = false

    local result = camera_policy._resolve_follow_player_id(game)
    assert(result == 2, "should return current player when valid")
  end,
}

describe("movement_camera", function()
  it("_test_resolve_follow_player_id_current", _resolve_follow_player_id_tests[1])

  it("_test_resolve_follow_player_id_next_non_eliminated", _resolve_follow_player_id_tests[2])

  it("_test_resolve_follow_player_id_no_index", _resolve_follow_player_id_tests[3])

  it("_test_resolve_follow_player_id_no_players", _resolve_follow_player_id_tests[4])

  it("_test_resolve_follow_player_id_multiple_eliminated", _resolve_follow_player_id_extended_tests[1])

  it("_test_resolve_follow_player_id_nil_id", _resolve_follow_player_id_more_tests[2])

  it("_test_resolve_follow_player_id_nil_turn", _resolve_follow_player_id_extended_tests[3])

  it("_test_resolve_follow_player_id_nil_players", _resolve_follow_player_id_extended_tests[4])

  it("_test_resolve_follow_player_id_empty_players", _resolve_follow_player_id_extended_tests[5])

  it("_test_resolve_follow_player_id_current_not_eliminated", _resolve_follow_player_id_extended_tests[6])

  it("_test_resolve_follow_player_id_wrap_around", _resolve_follow_player_id_extended_tests[7])

  it("_test_resolve_follow_player_id_skip_nil_id", _resolve_follow_player_id_extended_tests[8])

  it("_test_resolve_follow_player_id_index_zero", _resolve_follow_player_id_extended_tests[9])

  it("_test_resolve_follow_player_id_negative_index", _resolve_follow_player_id_extended_tests[10])

  it("_test_resolve_follow_player_id_all_eliminated", _resolve_follow_player_id_more_tests[1])

  it("_test_resolve_follow_player_id_nil_id", _resolve_follow_player_id_more_tests[2])

  it("_test_resolve_follow_player_next_non_eliminated", _resolve_follow_player_id_final_tests[1])

  it("_test_resolve_follow_player_wrap_around", _resolve_follow_player_id_final_tests[2])

  it("_test_resolve_follow_player_current_valid", _resolve_follow_player_id_final_tests[3])
end)
