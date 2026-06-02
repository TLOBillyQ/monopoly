-- Pins the `expect` data contract for the e2e profile lane (handoff
-- e2e-profile-lane). `expect` mirrors a profile's existing spec/behavior
-- design-truth invariant so the live editor lane asserts the same thing the
-- headless lane already proves -- it is NOT a new invariant.
--
-- Phase 1 carries exactly one expect: `solo_missile`, mirroring the missile
-- branch of spec/behavior/rules/demolish_closure_spec.lua (a missile hitting
-- an occupied enemy building destroys it and hospitalises the occupant).
local test_profiles_cfg = require("src.app.testing.test_profiles")
local event_kinds = require("src.config.gameplay.event_kinds")

local function _has_event_kind(events, kind)
  for _, event in ipairs(events or {}) do
    if event.kind == kind then
      return true
    end
  end
  return false
end

describe("test_profiles expect contract", function()
  it("phase 1 attaches expect to solo_missile only", function()
    local with_expect = {}
    for _, name in ipairs(test_profiles_cfg.names()) do
      local profile = test_profiles_cfg.get(name)
      if profile and profile.expect ~= nil then
        with_expect[#with_expect + 1] = name
      end
    end
    assert(#with_expect == 1, "phase 1 expects exactly one profile with expect, got " .. #with_expect)
    assert(with_expect[1] == "solo_missile", "the only expect-bearing profile is solo_missile: " .. tostring(with_expect[1]))
  end)

  describe("solo_missile.expect", function()
    local expect = test_profiles_cfg.get("solo_missile").expect

    it("traces back to the demolish closure spec", function()
      assert(type(expect) == "table", "solo_missile carries an expect table")
      assert.equals("spec/behavior/rules/demolish_closure_spec.lua", expect.source_spec)
    end)

    it("asserts the building on tile 11 is destroyed (level 0)", function()
      assert(type(expect.tiles) == "table", "expect.tiles present")
      assert(type(expect.tiles[11]) == "table", "expect references tile 11")
      assert.equals(0, expect.tiles[11].level)
    end)

    it("asserts the tile-11 occupant (p2) is sent to hospital", function()
      assert(type(expect.players) == "table", "expect.players present")
      assert(type(expect.players[2]) == "table", "expect references player 2")
      assert.equals(true, expect.players[2].in_hospital)
    end)

    it("asserts a demolish event is published at least once", function()
      assert(type(expect.events) == "table", "expect.events present")
      assert(_has_event_kind(expect.events, event_kinds.demolish),
        "expect.events must include a demolish event")
    end)

    it("mirrors the solo_missile bootstrap it is asserting against", function()
      -- expect is only meaningful if it lines up with the scenario the live
      -- lane boots: p1 holds the missile, p2 occupies tile 11, tile 11 is a
      -- level-2 enemy building. Keep the assertion anchored to the setup so a
      -- drifting bootstrap can never leave expect silently wrong.
      local boot = test_profiles_cfg.get("solo_missile").bootstrap
      local item_ids = require("src.config.gameplay.item_ids")
      assert.equals(11, boot.players[2].position_tile_id)  -- p2 stands on the targeted tile
      assert.equals(2, boot.tiles[11].owner_player_index)
      assert.equals(2, boot.tiles[11].level)
      assert((boot.players[1].item_counts or {})[item_ids.missile] ~= nil,
        "p1 must hold the missile the lane fires")
    end)
  end)
end)
