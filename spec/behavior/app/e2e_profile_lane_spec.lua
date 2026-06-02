-- Headless contract for the pure core of the e2e profile lane (handoff
-- e2e-profile-lane). Everything here is environment-free: profile
-- enumeration, observed-vs-expect matching, and run summarisation. The live
-- editor round-trip lives in spec/e2e and is NOT exercised here.
local lane = require("src.app.testing.e2e_profile_lane")

-- Minimal resolver stub: only the two methods lane.partition consumes.
local function _resolver(names, expects)
  return {
    available_profiles = function() return names end,
    expect_for = function(name) return expects[name] end,
  }
end

describe("e2e_profile_lane.partition", function()
  it("splits profiles into runnable (has expect) and skipped (no expect)", function()
    local resolver = _resolver(
      { "default", "solo_missile", "solo_remote_dice" },
      { solo_missile = { tiles = {} } }
    )
    local part = lane.partition(resolver)
    assert.same({ "solo_missile" }, part.runnable)
    assert.same({ "default", "solo_remote_dice" }, part.skipped)
  end)

  it("preserves the resolver's ordering in both buckets", function()
    local resolver = _resolver(
      { "a", "b", "c", "d" },
      { b = { tiles = {} }, d = { tiles = {} } }
    )
    local part = lane.partition(resolver)
    assert.same({ "b", "d" }, part.runnable)
    assert.same({ "a", "c" }, part.skipped)
  end)

  it("yields an empty runnable bucket when no profile carries expect", function()
    local part = lane.partition(_resolver({ "a", "b" }, {}))
    assert.same({}, part.runnable)
    assert.same({ "a", "b" }, part.skipped)
  end)
end)

describe("e2e_profile_lane.match", function()
  local expect = {
    tiles   = { [11] = { level = 0 } },
    players = { [2] = { in_hospital = true } },
    events  = { { kind = "demolish" } },
  }

  it("passes when observed satisfies every expected field", function()
    local observed = {
      tiles   = { [11] = { level = 0 } },
      players = { [2] = { in_hospital = true } },
      events  = { { kind = "move" }, { kind = "demolish" } },
    }
    local res = lane.match("solo_missile", observed, expect)
    assert.is_true(res.ok)
    assert.same({}, res.failures)
  end)

  it("flags a tile field mismatch with profile name, field, and both values", function()
    local observed = {
      tiles   = { [11] = { level = 2 } },
      players = { [2] = { in_hospital = true } },
      events  = { { kind = "demolish" } },
    }
    local res = lane.match("solo_missile", observed, expect)
    assert.is_false(res.ok)
    assert.equals(1, #res.failures)
    local msg = res.failures[1]
    assert(msg:find("solo_missile", 1, true), "message names the profile: " .. msg)
    assert(msg:find("tiles[11].level", 1, true), "message names the field: " .. msg)
    assert(msg:find("0", 1, true) and msg:find("2", 1, true), "message carries expected vs actual: " .. msg)
  end)

  it("flags a player field mismatch", function()
    local observed = {
      tiles   = { [11] = { level = 0 } },
      players = { [2] = { in_hospital = false } },
      events  = { { kind = "demolish" } },
    }
    local res = lane.match("solo_missile", observed, expect)
    assert.is_false(res.ok)
    assert(res.failures[1]:find("players[2].in_hospital", 1, true), "names player field: " .. res.failures[1])
  end)

  it("flags an expected event kind that never appears", function()
    local observed = {
      tiles   = { [11] = { level = 0 } },
      players = { [2] = { in_hospital = true } },
      events  = { { kind = "move" } },
    }
    local res = lane.match("solo_missile", observed, expect)
    assert.is_false(res.ok)
    assert(res.failures[1]:find("demolish", 1, true), "names the missing event kind: " .. res.failures[1])
  end)

  it("treats a missing observed sub-table as a mismatch, not a crash", function()
    local res = lane.match("solo_missile", {}, expect)
    assert.is_false(res.ok)
    -- one per expected field: tile level, player hospital, event kind
    assert.equals(3, #res.failures)
  end)

  it("accumulates every mismatch rather than stopping at the first", function()
    local observed = {
      tiles   = { [11] = { level = 3 } },
      players = { [2] = { in_hospital = false } },
      events  = {},
    }
    local res = lane.match("solo_missile", observed, expect)
    assert.equals(3, #res.failures)
  end)
end)

describe("e2e_profile_lane.observe", function()
  -- observe is the SAME reducer the live editor lane runs; here we drive a
  -- real headless game through the actual missile rule and prove observe
  -- distils exactly the fields solo_missile.expect asserts. This keeps the
  -- live adapter's only job the editor transport, not any judgment.
  local support = require("spec.support.shared_support")
  local default_map = require("src.config.content.default_map")
  local item_ids = require("src.config.gameplay.item_ids")
  local demolish = require("src.rules.items.demolish")
  local test_profiles_cfg = require("src.app.testing.test_profiles")

  local function _fire_solo_missile()
    local g = support.new_game({ map = default_map, players = { "P1", "P2", "P3", "P4" } })
    local p1 = g:current_player()
    local tile11 = g.board:get_tile(11)
    g:set_tile_owner(tile11, 2)
    g:set_tile_level(tile11, 2)
    g:update_player_position(g.players[2], 11)
    local recorded = {}
    g.event_feed_port = { publish = function(_, _, event) recorded[#recorded + 1] = event; return true end }
    demolish.apply(g, p1, 11, { item_id = item_ids.missile, injure = true, title = "导弹卡" })
    return g, recorded
  end

  it("distils tile level, hospital status, and events from a live game state", function()
    local g, recorded = _fire_solo_missile()
    local expect = test_profiles_cfg.get("solo_missile").expect
    local observed = lane.observe(g, recorded, expect)
    assert.equals(0, observed.tiles[11].level)
    assert.is_true(observed.players[2].in_hospital)
    local kinds = {}
    for _, e in ipairs(observed.events) do kinds[e.kind] = true end
    assert.is_true(kinds["demolish"])
  end)

  it("produces an observation that satisfies the profile's own expect via match", function()
    local g, recorded = _fire_solo_missile()
    local expect = test_profiles_cfg.get("solo_missile").expect
    local observed = lane.observe(g, recorded, expect)
    local res = lane.match("solo_missile", observed, expect)
    assert.is_true(res.ok, table.concat(res.failures, "; "))
  end)

  it("reports in_hospital=false when the occupant is not actually hospitalised", function()
    local g = support.new_game({ map = default_map, players = { "P1", "P2" } })
    -- p2 parked on an ordinary tile, never hit: not in hospital.
    g:update_player_position(g.players[2], 11)
    local expect = { players = { [2] = { in_hospital = true } } }
    local observed = lane.observe(g, {}, expect)
    assert.is_false(observed.players[2].in_hospital)
  end)
end)

describe("e2e_profile_lane.observe — hospital boundary closure", function()
  -- Precise control of _player_in_hospital / _observe_players boundaries the
  -- demolish-driven happy path cannot reach: empty occupant slot, on the
  -- hospital tile without a stay, serving a stay elsewhere, absent stay_turns,
  -- and the non-derived player-field branch. Routed by the architect mutation
  -- audit (agent_context/architect/e2e-profile-lane-mutation-audit.md, A).
  local HOSPITAL = 36

  local function _game(players)
    return {
      board = {
        get_tile = function(_, idx) return { level = 0, id = idx } end,
        find_first_by_type = function(_, kind) return kind == "hospital" and HOSPITAL or nil end,
      },
      players = players,
    }
  end

  local function _in_hospital(players)
    local observed = lane.observe(_game(players), {}, { players = { [2] = { in_hospital = true } } })
    return observed.players[2].in_hospital
  end

  it("is false when the occupant slot is empty (nil player)", function()
    assert.is_false(_in_hospital({}))
  end)

  it("is true only when on the hospital tile AND serving a stay", function()
    assert.is_true(_in_hospital({ [2] = { position = HOSPITAL, status = { stay_turns = 2 } } }))
  end)

  it("is false on the hospital tile with no remaining stay (stay_turns == 0)", function()
    -- kills the `stay_turns > 0` boundary (a `>= 0` mutation would say true)
    assert.is_false(_in_hospital({ [2] = { position = HOSPITAL, status = { stay_turns = 0 } } }))
  end)

  it("is false when serving a stay but not on the hospital tile", function()
    -- kills `and` -> `or` and the position `==` clause
    assert.is_false(_in_hospital({ [2] = { position = 11, status = { stay_turns = 3 } } }))
  end)

  it("is false when stay_turns is absent on the hospital tile (nil -> 0)", function()
    -- kills `stay_turns or 0` -> `or 1` (nil or 1 would be > 0)
    assert.is_false(_in_hospital({ [2] = { position = HOSPITAL, status = {} } }))
  end)

  it("reads a non-derived player field straight from the player", function()
    -- exercises the else branch of `field == "in_hospital"` in _observe_players;
    -- observe uses only the field key, so the expect value is irrelevant here.
    local observed = lane.observe(
      _game({ [2] = { position = 11, status = {} } }),
      {},
      { players = { [2] = { position = 99 } } }
    )
    assert.equals(11, observed.players[2].position)
  end)
end)

describe("e2e_profile_lane.summarize", function()
  it("counts passed, failed, and skipped results", function()
    local counts = lane.summarize({
      { name = "a", status = "passed" },
      { name = "b", status = "failed" },
      { name = "c", status = "skipped" },
      { name = "d", status = "passed" },
    })
    assert.equals(2, counts.passed)
    assert.equals(1, counts.failed)
    assert.equals(1, counts.skipped)
  end)

  it("returns zeroed counts for an empty run", function()
    local counts = lane.summarize({})
    assert.equals(0, counts.passed)
    assert.equals(0, counts.failed)
    assert.equals(0, counts.skipped)
  end)
end)
