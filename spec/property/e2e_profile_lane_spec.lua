---@diagnostic disable: missing-fields

-- Property coverage for the pure e2e profile-lane core (handoff e2e-profile-lane).
-- The lane's judgment is environment-free on purpose, so its invariants can be
-- proven headlessly here: partition conserves and orders the profile set,
-- summarize conserves the tally, and match is sound (exact observation passes),
-- complete (every divergence is reported), and total (a missing observation is a
-- mismatch, never a crash).

local property = require("spec.support.property")
local lane = require("src.app.testing.e2e_profile_lane")

local FIELD_NAMES = { "owner", "level", "price", "cash", "position" }
local EVENT_KINDS = { "rent_paid", "jail", "pass_go", "buy", "upgrade", "bankrupt" }

-- Build a fake resolver whose profiles carry an `expect` only when the seeded
-- coin says so. Returns the resolver plus the names it decided are runnable, so
-- the partition properties can check against ground truth without re-deriving it
-- from the same predicate under test.
local function _gen_resolver(rng)
  local names, runnable_set = {}, {}
  local count = rng:int(0, 6)
  for index = 1, count do
    local name = "p" .. tostring(index)
    names[index] = name
    if rng:bool() then
      runnable_set[name] = true
    end
  end
  local resolver = {
    available_profiles = function() return names end,
    expect_for = function(name)
      if runnable_set[name] then
        return { tiles = {}, players = {}, events = {} }
      end
      return nil
    end,
  }
  return resolver, names, runnable_set
end

-- A flat list of every leaf the expect asserts ({kind="field"/"event", ...}) so
-- the completeness property can corrupt exactly one and predict the fallout.
local function _gen_expect(rng)
  local expect = { tiles = {}, players = {}, events = {} }
  local leaves = {}

  local function gen_fields(category)
    local used_idx = {}
    for _ = 1, rng:int(0, 3) do
      local idx
      repeat idx = rng:int(1, 6) until not used_idx[idx]
      used_idx[idx] = true
      local fields, used_field = {}, {}
      for _ = 1, rng:int(1, 2) do
        local field
        repeat field = rng:pick(FIELD_NAMES) until not used_field[field]
        used_field[field] = true
        local want = rng:int(0, 9)
        fields[field] = want
        leaves[#leaves + 1] = { kind = "field", category = category, idx = idx, field = field, want = want }
      end
      expect[category][idx] = fields
    end
  end

  gen_fields("tiles")
  gen_fields("players")

  local used_kind = {}
  for _ = 1, rng:int(0, 3) do
    local kind
    repeat kind = rng:pick(EVENT_KINDS) until not used_kind[kind]
    used_kind[kind] = true
    expect.events[#expect.events + 1] = { kind = kind }
    leaves[#leaves + 1] = { kind = "event", event_kind = kind }
  end

  return expect, leaves
end

-- An observation that exactly satisfies `expect`: every asserted field mirrored,
-- every expected event kind present (plus one unrelated kind, to prove match
-- tolerates extra observed events).
local function _satisfying_observed(expect)
  local observed = { tiles = {}, players = {}, events = {} }
  for _, category in ipairs({ "tiles", "players" }) do
    for idx, fields in pairs(expect[category]) do
      local entry = {}
      for field, want in pairs(fields) do
        entry[field] = want
      end
      observed[category][idx] = entry
    end
  end
  for _, wanted in ipairs(expect.events) do
    observed.events[#observed.events + 1] = { kind = wanted.kind }
  end
  observed.events[#observed.events + 1] = { kind = "__unrelated__" }
  return observed
end

describe("e2e profile lane: partition conserves and orders the profile set", function()
  it("splits every profile into runnable/skipped, preserving order, with no loss", function()
    property.for_all(function(rng)
      local resolver, names = _gen_resolver(rng)
      return { resolver = resolver, names = names }
    end, function(case)
      local parts = lane.partition(case.resolver)
      assert(#parts.runnable + #parts.skipped == #case.names,
        "runnable + skipped must conserve the full profile count")

      -- Each bucket is a subsequence of the resolver's ordering.
      local function assert_subsequence(bucket)
        local cursor = 0
        for _, picked in ipairs(bucket) do
          repeat cursor = cursor + 1 until cursor > #case.names or case.names[cursor] == picked
          assert(cursor <= #case.names, "bucket entry " .. tostring(picked) .. " broke source order")
        end
      end
      assert_subsequence(parts.runnable)
      assert_subsequence(parts.skipped)

      -- Predicate soundness: runnable iff expect_for is non-nil.
      for _, name in ipairs(parts.runnable) do
        assert(case.resolver.expect_for(name) ~= nil, name .. " was bucketed runnable without an expect")
      end
      for _, name in ipairs(parts.skipped) do
        assert(case.resolver.expect_for(name) == nil, name .. " was bucketed skipped despite an expect")
      end
    end)
  end)
end)

describe("e2e profile lane: summarize conserves the tally", function()
  it("counts only the three known statuses, ignoring noise, with non-negative sums", function()
    local statuses = { "passed", "failed", "skipped", "errored", "unknown", "" }
    property.for_all(function(rng)
      local results, known = {}, 0
      for _ = 1, rng:int(0, 12) do
        local status = rng:pick(statuses)
        results[#results + 1] = { status = status }
        if status == "passed" or status == "failed" or status == "skipped" then
          known = known + 1
        end
      end
      return { results = results, known = known }
    end, function(case)
      local counts = lane.summarize(case.results)
      assert(counts.passed >= 0 and counts.failed >= 0 and counts.skipped >= 0, "counts must be non-negative")
      assert(counts.passed + counts.failed + counts.skipped == case.known,
        "summed known statuses must equal the number of recognised results")
    end)
  end)
end)

describe("e2e profile lane: match is sound, complete, and total", function()
  it("reports ok iff there are no failures, for any observation", function()
    property.for_all(_gen_expect, function(expect)
      local observed = _satisfying_observed(expect)
      local result = lane.match("prof", observed, expect)
      assert(result.ok == (#result.failures == 0), "ok must track the failure list exactly")
    end)
  end)

  it("passes an exactly-satisfying observation with zero failures", function()
    property.for_all(_gen_expect, function(expect)
      local result = lane.match("prof", _satisfying_observed(expect), expect)
      assert(result.ok, "satisfying observation must pass: " .. table.concat(result.failures, "; "))
      assert(#result.failures == 0, "satisfying observation must raise no failures")
    end)
  end)

  it("treats a missing observation as a mismatch on every asserted leaf, never a crash", function()
    property.for_all(_gen_expect, function(expect)
      local result = lane.match("prof", nil, expect)
      local expected_leaf_count = 0
      for _, category in ipairs({ "tiles", "players" }) do
        for _, fields in pairs(expect[category]) do
          for _ in pairs(fields) do expected_leaf_count = expected_leaf_count + 1 end
        end
      end
      expected_leaf_count = expected_leaf_count + #expect.events
      assert(#result.failures == expected_leaf_count,
        "missing observation must fail once per asserted leaf (" .. expected_leaf_count .. ")")
      assert(result.ok == (expected_leaf_count == 0), "ok only when the expect itself is empty")
    end)
  end)

  it("reports exactly one failure naming the leaf when a single leaf diverges", function()
    property.for_all(function(rng)
      local expect, leaves = _gen_expect(rng)
      return { expect = expect, leaves = leaves, rng = rng }
    end, function(case)
      if #case.leaves == 0 then
        return -- nothing to corrupt; the empty case is covered elsewhere
      end
      local observed = _satisfying_observed(case.expect)
      local target = case.leaves[case.rng:int(1, #case.leaves)]
      if target.kind == "field" then
        observed[target.category][target.idx][target.field] = target.want + 1
      else
        -- Drop the one expected event kind from the observation.
        local kept = {}
        for _, event in ipairs(observed.events) do
          if event.kind ~= target.event_kind then
            kept[#kept + 1] = event
          end
        end
        observed.events = kept
      end

      local result = lane.match("prof", observed, case.expect)
      assert(not result.ok, "a single divergence must fail the match")
      assert(#result.failures == 1, "a single divergence must raise exactly one failure")
      local message = result.failures[1]
      assert(message:find("prof", 1, true), "failure must name the profile")
      local needle = target.kind == "field" and target.field or target.event_kind
      assert(message:find(needle, 1, true), "failure must name the diverging leaf: " .. needle)
    end)
  end)
end)

-- A minimal stand-in for the live game model that lane.observe reduces. Only the
-- surface the reducer touches is faked: board:get_tile, board:find_first_by_type,
-- and the players array. Methods use the colon-call self convention the reducer
-- relies on.
local function _fake_game(hospital_tile, players, tiles)
  return {
    board = {
      get_tile = function(_, idx) return (tiles or {})[idx] end,
      find_first_by_type = function(_, kind)
        return kind == "hospital" and hospital_tile or nil
      end,
    },
    players = players or {},
  }
end

describe("e2e profile lane: observe derives the hospital boundary as a strict AND", function()
  it("flags in_hospital iff the occupant is on the hospital tile AND still serving a stay", function()
    property.for_all(function(rng)
      local hospital = rng:int(1, 8)
      local position = rng:int(1, 8)
      local has_status = rng:bool()
      local stay = rng:int(0, 3)
      local player = { position = position }
      if has_status then
        player.status = { stay_turns = stay }
      end
      return { hospital = hospital, position = position, has_status = has_status, stay = stay, player = player }
    end, function(case)
      local game = _fake_game(case.hospital, { case.player })
      local observed = lane.observe(game, {}, { players = { [1] = { in_hospital = true } } })
      local effective_stay = case.has_status and case.stay or 0
      local expected = case.position == case.hospital and effective_stay > 0
      assert(observed.players[1].in_hospital == expected,
        "in_hospital must equal (on hospital tile) AND (stay_turns > 0)")
    end)
  end)

  it("returns false for an empty occupant slot rather than crashing", function()
    local game = _fake_game(3, {}) -- no player at index 1
    local observed = lane.observe(game, {}, { players = { [1] = { in_hospital = true } } })
    assert(observed.players[1].in_hospital == false, "a missing player must read as not hospitalised")
  end)
end)

describe("e2e profile lane: observe projects only what the expect names", function()
  it("mirrors recorded events to bare {kind} entries, order and count preserved", function()
    local kinds_pool = { "rent_paid", "jail", "pass_go", "buy" }
    property.for_all(function(rng)
      local recorded = {}
      for _ = 1, rng:int(0, 6) do
        -- Each recorded event carries extra fields the reducer must drop.
        recorded[#recorded + 1] = { kind = rng:pick(kinds_pool), amount = rng:int(1, 99), tile = rng:int(1, 40) }
      end
      return recorded
    end, function(recorded)
      local observed = lane.observe(_fake_game(1, {}), recorded, {})
      assert(#observed.events == #recorded, "event count must be preserved")
      for index, event in ipairs(observed.events) do
        assert(event.kind == recorded[index].kind, "event order and kind must be preserved")
        assert(event.amount == nil and event.tile == nil, "observe must drop non-kind event fields")
        local field_count = 0
        for _ in pairs(event) do field_count = field_count + 1 end
        assert(field_count == 1, "each observed event must carry exactly the kind field")
      end
    end)
  end)

  it("projects player fields straight through except the derived in_hospital", function()
    property.for_all(function(rng)
      return { cash = rng:int(0, 9999), position = rng:int(1, 40) }
    end, function(case)
      local game = _fake_game(1, { { cash = case.cash, position = case.position } })
      local observed = lane.observe(game, {}, { players = { [1] = { cash = true, position = true } } })
      assert(observed.players[1].cash == case.cash, "non-derived player field must pass straight through")
      assert(observed.players[1].position == case.position, "non-derived player field must pass straight through")
    end)
  end)
end)
