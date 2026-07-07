-- Mutation-pinning specs for src/player/actions/deity.lua.
-- State shape kept inline; each test asserts a value/side effect that DIFFERS
-- between the original and one specific surviving mutant.
--
-- _ensure_deity (L8-12):
--   L10  status.deity = status.deity or { type = "", remaining = 0 }
-- player_has_any_deity (L22-32):
--   L31  return d.type ~= nil and d.type ~= "" and (d.remaining or 0) > 0

local deity_ops = require("src.player.actions.deity")
local common = require("src.player.actions.state_common")
local support = require("spec.support.shared_support")

local _with_patches = support.with_patches

describe("deity _ensure_deity default type L10 ('' must not become nil)", function()
  it("seeds a fresh deity with an empty-string type, not nil (L10 '\"\"')", function()
    -- tick on a player with no status/deity forces _ensure_deity to create the
    -- default record, then returns immediately (remaining 0 <= 0) WITHOUT
    -- overwriting type. The persisted default type is thus observable.
    local player = {}
    deity_ops.tick_player_deity({}, player)
    local d = player.status and player.status.deity
    assert(d ~= nil, "tick must have materialised status.deity")
    -- Original: type == "".  Mutant '' -> nil: type == nil.
    assert(d.type == "",
      "default deity.type must be the empty string; got " .. tostring(d.type))
  end)
end)

describe("deity _ensure_deity default remaining L10 (0 must not become 1)", function()
  it("seeds a fresh deity with remaining 0 so tick is a no-op with no mark (L10 '0')", function()
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
    assert(marks == 0,
      "fresh deity with remaining 0 must not mark players on tick; got " .. marks .. " marks")
  end)
end)

describe("deity player_has_any_deity L31 empty-type guard ('' must not become nil)", function()
  it("reports no deity when type is empty string even if remaining > 0 (L31 '\"\"')", function()
    local player = { status = { deity = { type = "", remaining = 5 } } }
    local result = deity_ops.player_has_any_deity(nil, player)
    -- Original: type~=nil(true) and type~=""(FALSE) -> false.
    -- Mutant '' -> nil: type~=nil and type~=nil(true) and (5 or 0)>0 -> true.
    assert(result == false,
      "empty-string deity type must count as no deity; got " .. tostring(result))
  end)
end)

describe("deity player_has_any_deity L31 remaining fallback (0 must not become 1)", function()
  it("reports no deity when remaining is nil (L31 fallback '0')", function()
    local player = { status = { deity = { type = "angel", remaining = nil } } }
    local result = deity_ops.player_has_any_deity(nil, player)
    -- Original: type ok, (nil or 0) > 0 -> 0 > 0 -> false.
    -- Mutant '0' -> '1': (nil or 1) > 0 -> 1 > 0 -> true.
    assert(result == false,
      "nil remaining must fall back to 0 (no deity); got " .. tostring(result))
  end)

  it("reports a deity when remaining is a positive number (positive control)", function()
    -- Ensures the fallback test above is not vacuously false: a real remaining
    -- makes the function return true.
    local player = { status = { deity = { type = "angel", remaining = 3 } } }
    assert(deity_ops.player_has_any_deity(nil, player) == true,
      "positive remaining with a named deity must report true")
  end)
end)
