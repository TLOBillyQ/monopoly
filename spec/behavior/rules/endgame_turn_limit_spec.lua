local endgame = require("src.rules.endgame")
local timing = require("src.config.gameplay.timing")

local function _make_player(id, name, cash)
  return {
    id = id,
    name = name,
    properties = {},
    eliminated = false,
    status = { deity = nil },
  },
  cash
end

local function _make_game(players, cash_map)
  return {
    finished = false,
    turn = { turn_count = timing.turn_limit },
    occupants = {},
    board = { get_tile_by_id = function() return nil end },
    alive_players = function() return players end,
    player_balance = function(_, player, currency)
      if currency == "金币" then
        return cash_map[player] or 0
      end
      return 0
    end,
  }
end

local function _make_time_game(players, cash_map)
  local game = _make_game(players, cash_map)
  game.turn.turn_count = 0
  game.game_time_seconds = timing.game_time_limit_seconds
  return game
end

describe("endgame turn_limit victory", function()
  it("_test_single_winner_by_total_assets_at_game_time_limit", function()
    local p1, c1 = _make_player(1, "Alice", 1000)
    local p2, c2 = _make_player(2, "Bob", 500)
    local game = _make_time_game({ p1, p2 }, { [p1] = c1, [p2] = c2 })
    local result = endgame.check_victory(game)
    assert(result == true, "check_victory should return true at game time limit")
    assert(game.winner == p1, "player with most assets should win when time expires")
  end)

  it("_test_not_yet_at_game_time_limit_returns_false", function()
    local p1, c1 = _make_player(1, "Alice", 1000)
    local p2, c2 = _make_player(2, "Bob", 500)
    local game = _make_time_game({ p1, p2 }, { [p1] = c1, [p2] = c2 })
    game.game_time_seconds = timing.game_time_limit_seconds - 1
    local result = endgame.check_victory(game)
    assert(result == false, "should return false before game time limit with multiple survivors")
  end)

  it("_test_single_winner_by_total_assets", function()
    local p1, c1 = _make_player(1, "Alice", 1000)
    local p2, c2 = _make_player(2, "Bob", 500)
    local game = _make_game({ p1, p2 }, { [p1] = c1, [p2] = c2 })
    local result = endgame.check_victory(game)
    assert(result == true, "check_victory should return true at turn limit")
    assert(game.winner == p1, "player with most assets should win")
    assert(#game.winners == 1, "only one winner")
  end)

  it("_test_tied_winners_at_turn_limit", function()
    local p1, c1 = _make_player(1, "Alice", 800)
    local p2, c2 = _make_player(2, "Bob", 800)
    local game = _make_game({ p1, p2 }, { [p1] = c1, [p2] = c2 })
    local result = endgame.check_victory(game)
    assert(result == true, "check_victory should return true at turn limit")
    assert(game.winner == nil, "tie should set winner to nil")
    assert(#game.winners == 2, "both players should be winners in a tie")
  end)

  it("_test_not_yet_at_turn_limit_returns_false", function()
    local p1, c1 = _make_player(1, "Alice", 1000)
    local p2, c2 = _make_player(2, "Bob", 500)
    local game = _make_game({ p1, p2 }, { [p1] = c1, [p2] = c2 })
    game.turn.turn_count = timing.turn_limit - 1
    local result = endgame.check_victory(game)
    assert(result == false, "should return false when not at turn limit with multiple survivors")
  end)

  it("_test_no_survivors_at_turn_limit", function()
    local game = _make_game({}, {})
    local result = endgame.check_victory(game)
    assert(result == true, "should return true with empty winners")
    assert(#game.winners == 0, "no survivors means no winners")
  end)
end)
