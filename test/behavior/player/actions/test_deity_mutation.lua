require("test.bootstrap").install_package_paths()
-- busted injects the extensible assertion object into each file environment.
-- luacheck: ignore 143
local luassert = assert
-- Mutation-pinning specs for src/player/actions/deity.lua.
-- State shape kept inline; each test asserts a value/side effect that DIFFERS
-- between the original and one specific surviving mutant.
--
-- _ensure_deity (L8-12):
--   L10  status.deity = status.deity or { type = "", remaining = 0 }
-- player_has_any_deity (L22-32):
--   L31  return d.type ~= nil and d.type ~= "" and (d.remaining or 0) > 0

local deity_ops = require("src.player.actions.deity")

describe("TestDeityMutation", function()

  it("test_seeds_a_fresh_deity_with_an_empty_string_type_not_nil", function()
    -- tick on a player with no status/deity forces _ensure_deity to create the
    -- default record, then returns immediately (remaining 0 <= 0) WITHOUT
    -- overwriting type. The persisted default type is thus observable.
    local player = {}
    deity_ops.tick_player_deity({}, player)
    local d = player.status and player.status.deity
    luassert.truthy(d ~= nil, "tick must have materialised status.deity")
    -- Original: type == "".  Mutant '' -> nil: type == nil.
    luassert.truthy(d.type == "", "default deity.type must be the empty string; got " .. tostring(d.type))
  end)

  it("test_seeds_a_fresh_deity_with_remaining_0_so_tick_is_a_noop_with_no_mark", function()
    -- Observable via the game's dirty flags: with default remaining 0, tick
    -- returns before marking players dirty. With the mutant default remaining 1,
    -- tick decrements 1 -> 0, triggers clear_player_deity, which DOES mark players.
    local game = { dirty = {} }
    deity_ops.tick_player_deity(game, {})
    -- Original: remaining default 0 -> `if 0 <= 0 then return end` -> clean.
    -- Mutant '0'->'1': remaining default 1 -> 1<=0 false -> remaining=1-1=0 ->
    --   0<=0 -> clear_player_deity -> common.mark_players -> dirty.players.
    luassert.is_nil(game.dirty.players, "fresh deity with remaining 0 must not mark players dirty on tick")
  end)

  it("test_reports_no_deity_when_type_is_empty_string_even_if_remaining_is_positive", function()
    local player = { status = { deity = { type = "", remaining = 5 } } }
    local result = deity_ops.player_has_any_deity(nil, player)
    -- Original: type~=nil(true) and type~=""(FALSE) -> false.
    -- Mutant '' -> nil: type~=nil and type~=nil(true) and (5 or 0)>0 -> true.
    luassert.truthy(result == false, "empty-string deity type must count as no deity; got " .. tostring(result))
  end)

  it("test_reports_no_deity_when_remaining_is_nil", function()
    local player = { status = { deity = { type = "angel", remaining = nil } } }
    local result = deity_ops.player_has_any_deity(nil, player)
    -- Original: type ok, (nil or 0) > 0 -> 0 > 0 -> false.
    -- Mutant '0' -> '1': (nil or 1) > 0 -> 1 > 0 -> true.
    luassert.truthy(result == false, "nil remaining must fall back to 0 (no deity); got " .. tostring(result))
  end)

  it("test_reports_a_deity_when_remaining_is_a_positive_number", function()
    -- Ensures the fallback test above is not vacuously false: a real remaining
    -- makes the function return true.
    local player = { status = { deity = { type = "angel", remaining = 3 } } }
    luassert.truthy(deity_ops.player_has_any_deity(nil, player) == true, "positive remaining with a named deity must report true")
  end)


end)
