-- endgame_victory: consolidated victory/turn-limit specs (merged from endgame_mutation + endgame_turn_limit per inventory #16)
-- Mutation-pinning specs for src/rules/endgame.lua victory/time/turn helpers.
-- Each test asserts a value that DIFFERS between the original code and a
-- surviving mutant. Timing config is patched (save/restore) so the private
-- _positive_limit / _game_time_reached / _turn_limit_reached branches become
-- reachable through the public check_victory entry point.
require("test.bootstrap").install_package_paths()
local luassert = assert


describe("TestEndgameVictory", function()
do
local endgame = require("src.rules.endgame")
local timing = require("src.config.gameplay.timing")

local function _make_player(id, name)
  return { id = id, name = name, properties = {}, eliminated = false, status = { deity = nil } }
end

local function _make_game(players, cash_map)
  return {
    finished = false,
    turn = { turn_count = 0 },
    occupants = {},
    board = { get_tile_by_id = function() return nil end },
    alive_players = function() return players end,
    player_cash = function(_, player)
      return cash_map[player] or 0
    end,
  }
end

-- Patch a timing field for the duration of fn, always restoring afterwards.
local function _with_timing(field, value, fn)
  local saved = timing[field]
  timing[field] = value
  local ok, err = pcall(fn)
  timing[field] = saved
  if not ok then error(err) end
end

it("test_game_time_limit_nil_short_circuits_at_value_nil", function()
  -- Original _positive_limit(nil): 'nil == nil' short-circuits -> return nil ->
  --   _game_time_reached L94 returns false -> two survivors -> check_victory false.
  -- Mut 'or'->'and': 'nil == nil and nil <= 0' evaluates nil<=0 -> runtime error.
  -- Mut L94 'false'->'true': _game_time_reached true -> asset winners -> true.
  local p1 = _make_player(1, "Alice")
  local p2 = _make_player(2, "Bob")
  local game = _make_game({ p1, p2 }, { [p1] = 1000, [p2] = 500 })
  _with_timing("game_time_limit_seconds", nil, function()
    local result = endgame.check_victory(game)
    luassert.truthy(result == false,
      "nil game_time_limit must yield no game-time victory with 2 survivors; got " .. tostring(result))
  end)
  luassert.truthy(game.finished == false, "game must not be marked finished")
end)

it("test_game_time_limit_zero_rejects_zero_as_a_limit", function()
  -- Original _positive_limit(0): '0 <= 0' true -> return nil -> no time limit ->
  --   check_victory false (2 survivors, turn not reached).
  -- Mut '<=' -> '<': '0 < 0' false -> return 0 -> limit 0, elapsed 100 >= 0 ->
  --   game time reached -> asset winners -> true.
  local p1 = _make_player(1, "Alice")
  local p2 = _make_player(2, "Bob")
  local game = _make_game({ p1, p2 }, { [p1] = 1000, [p2] = 500 })
  game.game_time_seconds = 100
  _with_timing("game_time_limit_seconds", 0, function()
    local result = endgame.check_victory(game)
    luassert.truthy(result == false,
      "zero game_time_limit must not count as an active limit; got " .. tostring(result))
  end)
  luassert.truthy(game.finished == false, "game must not be marked finished")
end)

it("test_elapsed_game_seconds_fallback_when_game_time_seconds_absent", function()
  -- game_time_seconds nil -> L85 skips; elapsed_game_seconds=900 -> L86 returns it.
  -- Original: elapsed 900 >= limit 900 -> game time reached -> check_victory true.
  -- Mut L86 '~='->'==': skips 900, elapsed_seconds nil, current_time nil ->
  --   elapsed nil -> not reached -> two survivors -> false.
  local p1 = _make_player(1, "Alice")
  local p2 = _make_player(2, "Bob")
  local game = _make_game({ p1, p2 }, { [p1] = 1000, [p2] = 500 })
  game.game_time_seconds = nil
  game.elapsed_game_seconds = timing.game_time_limit_seconds
  game.elapsed_seconds = nil
  game.current_time = nil
  local result = endgame.check_victory(game)
  luassert.truthy(result == true,
    "elapsed_game_seconds at limit must end the game; got " .. tostring(result))
  luassert.truthy(game.finished == true, "game must be finished")
  luassert.truthy(game.winner == p1, "richest survivor wins on time")
end)

it("test_elapsed_seconds_fallback_when_earlier_fields_absent", function()
  -- game_time_seconds nil, elapsed_game_seconds nil -> L85/L86 skip;
  -- elapsed_seconds=900 -> L87 returns it. Original: reached -> true.
  -- Mut L87 '~='->'==': skips 900 -> current_time nil -> not reached -> false.
  local p1 = _make_player(1, "Alice")
  local p2 = _make_player(2, "Bob")
  local game = _make_game({ p1, p2 }, { [p1] = 1000, [p2] = 500 })
  game.game_time_seconds = nil
  game.elapsed_game_seconds = nil
  game.elapsed_seconds = timing.game_time_limit_seconds
  game.current_time = nil
  local result = endgame.check_victory(game)
  luassert.truthy(result == true,
    "elapsed_seconds at limit must end the game; got " .. tostring(result))
  luassert.truthy(game.finished == true, "game must be finished")
end)

it("test_turn_limit_nil_yields_no_turn_based_victory", function()
  -- turn_limit nil -> _positive_limit(nil) returns nil -> L103 returns false ->
  --   with 2 survivors and no game-time limit reached -> check_victory false.
  -- Mut L103 'false'->'true': _turn_limit_reached true -> asset winners -> true.
  local p1 = _make_player(1, "Alice")
  local p2 = _make_player(2, "Bob")
  local game = _make_game({ p1, p2 }, { [p1] = 1000, [p2] = 500 })
  game.turn.turn_count = 5
  _with_timing("turn_limit", nil, function()
    local result = endgame.check_victory(game)
    luassert.truthy(result == false,
      "nil turn_limit must not force a turn victory; got " .. tostring(result))
  end)
  luassert.truthy(game.finished == false, "game must not be marked finished")
end)

it("test_zero_survivors_still_ends_the_game", function()
  -- Not time/turn reached, #alive == 0 -> #alive <= 1 true, #alive == 1 false ->
  --   L139 _apply_winners(self, {}, "游戏结束，无人生还") -> returns true, finished=true.
  -- Mut L139 replaced with nil: returns nil, game.finished stays false.
  local game = _make_game({}, {})
  game.turn.turn_count = 0
  local result = endgame.check_victory(game)
  luassert.truthy(result == true,
    "no survivors must resolve the game via _apply_winners; got " .. tostring(result))
  luassert.truthy(game.finished == true, "no-survivor endgame must mark game finished")
  luassert.truthy(#game.winners == 0, "no survivors means empty winner list")
end)

it("test_tied_asset_winners_join_names_with_comma_separator", function()
  -- #293:_winner_names 的 "、" separator 变异(→ nil)未测。
  local p1 = _make_player(1, "阿甲")
  local p2 = _make_player(2, "阿乙")
  local game = _make_game({ p1, p2 }, { [p1] = 1000, [p2] = 1000 })
  game.game_time_seconds = 2
  local emitted = {}
  local events = require("src.foundation.events")
  local saved_emit = events.emit
  events.emit = function(event, payload)
    if event == "gm.finished" then emitted[#emitted + 1] = payload end
  end
  _with_timing("game_time_limit_seconds", 1, function()
    local result = endgame.check_victory(game)
    luassert.truthy(result == true, "tied assets at time limit should finish the game")
  end)
  events.emit = saved_emit
  luassert.truthy(#emitted >= 1, "victory should emit the finished event")
  local names = emitted[1] and emitted[1].winner_names or ""
  luassert.truthy(names:find("、", 1, true) ~= nil and names:find("阿甲", 1, true) ~= nil
    and names:find("阿乙", 1, true) ~= nil,
    "tied winners should join names with 、; got " .. tostring(names))
end)

end
-- ===== merged from test_endgame_turn_limit.lua =====
do
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
    player_cash = function(_, player)
      return cash_map[player] or 0
    end,
  }
end

local function _make_time_game(players, cash_map)
  local game = _make_game(players, cash_map)
  game.turn.turn_count = 0
  game.game_time_seconds = timing.game_time_limit_seconds
  return game
end

it("test_single_winner_by_total_assets_at_game_time_limit", function()
  local p1, c1 = _make_player(1, "Alice", 1000)
  local p2, c2 = _make_player(2, "Bob", 500)
  local game = _make_time_game({ p1, p2 }, { [p1] = c1, [p2] = c2 })
  local result = endgame.check_victory(game)
  luassert.truthy(result == true, "check_victory should return true at game time limit")
  luassert.truthy(game.winner == p1, "player with most assets should win when time expires")
end)

it("test_not_yet_at_game_time_limit_returns_false", function()
  local p1, c1 = _make_player(1, "Alice", 1000)
  local p2, c2 = _make_player(2, "Bob", 500)
  local game = _make_time_game({ p1, p2 }, { [p1] = c1, [p2] = c2 })
  game.game_time_seconds = timing.game_time_limit_seconds - 1
  local result = endgame.check_victory(game)
  luassert.truthy(result == false, "should return false before game time limit with multiple survivors")
end)

it("test_single_winner_by_total_assets", function()
  local p1, c1 = _make_player(1, "Alice", 1000)
  local p2, c2 = _make_player(2, "Bob", 500)
  local game = _make_game({ p1, p2 }, { [p1] = c1, [p2] = c2 })
  local result = endgame.check_victory(game)
  luassert.truthy(result == true, "check_victory should return true at turn limit")
  luassert.truthy(game.winner == p1, "player with most assets should win")
  luassert.truthy(#game.winners == 1, "only one winner")
end)

it("test_tied_winners_at_turn_limit", function()
  local p1, c1 = _make_player(1, "Alice", 800)
  local p2, c2 = _make_player(2, "Bob", 800)
  local game = _make_game({ p1, p2 }, { [p1] = c1, [p2] = c2 })
  local result = endgame.check_victory(game)
  luassert.truthy(result == true, "check_victory should return true at turn limit")
  luassert.truthy(game.winner == nil, "tie should set winner to nil")
  luassert.truthy(#game.winners == 2, "both players should be winners in a tie")
end)

it("test_not_yet_at_turn_limit_returns_false", function()
  local p1, c1 = _make_player(1, "Alice", 1000)
  local p2, c2 = _make_player(2, "Bob", 500)
  local game = _make_game({ p1, p2 }, { [p1] = c1, [p2] = c2 })
  game.turn.turn_count = timing.turn_limit - 1
  local result = endgame.check_victory(game)
  luassert.truthy(result == false, "should return false when not at turn limit with multiple survivors")
end)

it("test_no_survivors_at_turn_limit", function()
  local game = _make_game({}, {})
  local result = endgame.check_victory(game)
  luassert.truthy(result == true, "should return true with empty winners")
  luassert.truthy(#game.winners == 0, "no survivors means no winners")
end)

end


end)
