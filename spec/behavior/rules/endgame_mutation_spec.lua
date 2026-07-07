-- Mutation-pinning specs for src/rules/endgame.lua victory/time/turn helpers.
-- Each test asserts a value that DIFFERS between the original code and a
-- surviving mutant. Timing config is patched (save/restore) so the private
-- _positive_limit / _game_time_reached / _turn_limit_reached branches become
-- reachable through the public check_victory entry point.

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
    player_balance = function(_, player, currency)
      if currency == "金币" then return cash_map[player] or 0 end
      return 0
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

describe("endgame _positive_limit L78 (or / <=) via game time gate", function()
  it("game_time_limit=nil short-circuits at 'value == nil' (kills 'or'->'and' and L94 false->true)", function()
    -- Original _positive_limit(nil): 'nil == nil' short-circuits -> return nil ->
    --   _game_time_reached L94 returns false -> two survivors -> check_victory false.
    -- Mut 'or'->'and': 'nil == nil and nil <= 0' evaluates nil<=0 -> runtime error.
    -- Mut L94 'false'->'true': _game_time_reached true -> asset winners -> true.
    local p1 = _make_player(1, "Alice")
    local p2 = _make_player(2, "Bob")
    local game = _make_game({ p1, p2 }, { [p1] = 1000, [p2] = 500 })
    _with_timing("game_time_limit_seconds", nil, function()
      local result = endgame.check_victory(game)
      assert(result == false,
        "nil game_time_limit must yield no game-time victory with 2 survivors; got " .. tostring(result))
    end)
    assert(game.finished == false, "game must not be marked finished")
  end)

  it("game_time_limit=0 makes '<= 0' reject zero as a limit (kills '<=' -> '<')", function()
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
      assert(result == false,
        "zero game_time_limit must not count as an active limit; got " .. tostring(result))
    end)
    assert(game.finished == false, "game must not be marked finished")
  end)
end)

describe("endgame _elapsed_game_time L86/L87 (~= vs ==)", function()
  it("reads elapsed_game_seconds fallback when game_time_seconds absent (kills L86 '~='->'==')", function()
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
    assert(result == true,
      "elapsed_game_seconds at limit must end the game; got " .. tostring(result))
    assert(game.finished == true, "game must be finished")
    assert(game.winner == p1, "richest survivor wins on time")
  end)

  it("reads elapsed_seconds fallback when earlier fields absent (kills L87 '~='->'==')", function()
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
    assert(result == true,
      "elapsed_seconds at limit must end the game; got " .. tostring(result))
    assert(game.finished == true, "game must be finished")
  end)
end)

describe("endgame _turn_limit_reached L103 (false->true)", function()
  it("turn_limit=nil yields no turn-based victory (kills L103 'false'->'true')", function()
    -- turn_limit nil -> _positive_limit(nil) returns nil -> L103 returns false ->
    --   with 2 survivors and no game-time limit reached -> check_victory false.
    -- Mut L103 'false'->'true': _turn_limit_reached true -> asset winners -> true.
    local p1 = _make_player(1, "Alice")
    local p2 = _make_player(2, "Bob")
    local game = _make_game({ p1, p2 }, { [p1] = 1000, [p2] = 500 })
    game.turn.turn_count = 5
    _with_timing("turn_limit", nil, function()
      local result = endgame.check_victory(game)
      assert(result == false,
        "nil turn_limit must not force a turn victory; got " .. tostring(result))
    end)
    assert(game.finished == false, "game must not be marked finished")
  end)
end)

describe("endgame check_victory L139 no-survivors path", function()
  it("zero survivors (no time/turn limit) still ends the game (kills L139 arg->nil)", function()
    -- Not time/turn reached, #alive == 0 -> #alive <= 1 true, #alive == 1 false ->
    --   L139 _apply_winners(self, {}, "游戏结束，无人生还") -> returns true, finished=true.
    -- Mut L139 replaced with nil: returns nil, game.finished stays false.
    local game = _make_game({}, {})
    game.turn.turn_count = 0
    local result = endgame.check_victory(game)
    assert(result == true,
      "no survivors must resolve the game via _apply_winners; got " .. tostring(result))
    assert(game.finished == true, "no-survivor endgame must mark game finished")
    assert(#game.winners == 0, "no survivors means empty winner list")
  end)
end)
