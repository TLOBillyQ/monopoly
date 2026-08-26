-- Mutation-pinning specs for src/player/actions/deity.lua.
-- State shape kept inline; each test asserts a value/side effect that DIFFERS
-- between the original and one specific surviving mutant.
--
-- _ensure_deity (L8-12):
--   L10  status.deity = status.deity or { type = "", remaining = 0 }
-- player_has_any_deity (L22-32):
--   L31  return d.type ~= nil and d.type ~= "" and (d.remaining or 0) > 0

local lu = require("luaunit")
local deity_ops = require("src.player.actions.deity")
local common = require("src.player.actions.state_common")
local support = require("test.support.shared_support")

local _with_patches = support.with_patches

TestDeityMutation = {}

function TestDeityMutation:test_seeds_a_fresh_deity_with_an_empty_string_type_not_nil()
  -- tick on a player with no status/deity forces _ensure_deity to create the
  -- default record, then returns immediately (remaining 0 <= 0) WITHOUT
  -- overwriting type. The persisted default type is thus observable.
  local player = {}
  deity_ops.tick_player_deity({}, player)
  local d = player.status and player.status.deity
  lu.assertEvalToTrue(d ~= nil, "tick must have materialised status.deity")
  -- Original: type == "".  Mutant '' -> nil: type == nil.
  lu.assertEvalToTrue(d.type == "",
    "default deity.type must be the empty string; got " .. tostring(d.type))
end

function TestDeityMutation:test_seeds_a_fresh_deity_with_remaining_0_so_tick_is_a_noop_with_no_mark()
  -- Observable via side effect: with default remaining 0, tick returns before
  -- any common.mark_players call. With the mutant default remaining 1, tick
  -- decrements 1 -> 0, triggers clear_player_deity, which DOES mark players.
  local marks = 0
  _with_patches({
    { target = common, key = "mark_players", value = function() marks = marks + 1 end },
  }, function()
    local player = {}
    deity_ops.tick_player_deity({ dirty = {} }, player)
  end)
  -- Original: remaining default 0 -> `if 0 <= 0 then return end` -> 0 marks.
  -- Mutant '0'->'1': remaining default 1 -> 1<=0 false -> remaining=1-1=0 ->
  --   0<=0 -> clear_player_deity -> common.mark_players -> >=1 marks.
  lu.assertEvalToTrue(marks == 0,
    "fresh deity with remaining 0 must not mark players on tick; got " .. marks .. " marks")
end

function TestDeityMutation:test_reports_no_deity_when_type_is_empty_string_even_if_remaining_is_positive()
  local player = { status = { deity = { type = "", remaining = 5 } } }
  local result = deity_ops.player_has_any_deity(nil, player)
  -- Original: type~=nil(true) and type~=""(FALSE) -> false.
  -- Mutant '' -> nil: type~=nil and type~=nil(true) and (5 or 0)>0 -> true.
  lu.assertEvalToTrue(result == false,
    "empty-string deity type must count as no deity; got " .. tostring(result))
end

function TestDeityMutation:test_reports_no_deity_when_remaining_is_nil()
  local player = { status = { deity = { type = "angel", remaining = nil } } }
  local result = deity_ops.player_has_any_deity(nil, player)
  -- Original: type ok, (nil or 0) > 0 -> 0 > 0 -> false.
  -- Mutant '0' -> '1': (nil or 1) > 0 -> 1 > 0 -> true.
  lu.assertEvalToTrue(result == false,
    "nil remaining must fall back to 0 (no deity); got " .. tostring(result))
end

function TestDeityMutation:test_reports_a_deity_when_remaining_is_a_positive_number()
  -- Ensures the fallback test above is not vacuously false: a real remaining
  -- makes the function return true.
  local player = { status = { deity = { type = "angel", remaining = 3 } } }
  lu.assertEvalToTrue(deity_ops.player_has_any_deity(nil, player) == true,
    "positive remaining with a named deity must report true")
end


return TestDeityMutation
