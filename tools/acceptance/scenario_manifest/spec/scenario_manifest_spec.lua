local scenario_manifest = require("acceptance4lua.scenario_manifest")
local spec_hash = require("acceptance4lua.spec_hash")

local function _sample_scenario(name, key, value)
  return {
    name = name or "alpha",
    steps = {
      { keyword = "Given", text = "input <key>", parameters = { "key" } },
    },
    examples = {
      { [key or "k"] = tostring(value or "1") },
    },
  }
end

local function _sample_manifest(entries)
  return {
    version = scenario_manifest.VERSION,
    tested_at = "2026-05-23T00:00:00Z",
    feature_name = "F",
    feature_path = "features/F.feature",
    background_hash = "bg-current",
    implementation_hash = "impl-current",
    scenarios = entries or {},
  }
end

describe("acceptance4lua.scenario_manifest.utc_now", function()
  it("returns an ISO-8601 UTC string with the Z suffix", function()
    local now = scenario_manifest.utc_now()
    assert.is_truthy(now:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$"))
  end)
end)

describe("acceptance4lua.scenario_manifest.read", function()
  it("returns nil when the feature has no manifest block", function()
    assert.is_nil(scenario_manifest.read("Feature: x\nScenario: s\n"))
  end)

  it("returns nil when manifest JSON is malformed", function()
    local source =
      "# acceptance-mutation-manifest-begin\n# {not json\n# acceptance-mutation-manifest-end\n"
    assert.is_nil(scenario_manifest.read(source))
  end)

  it("round-trips through serialize", function()
    local data = _sample_manifest({
      {
        index = 0,
        name = "alpha",
        scenario_hash = "h",
        mutation_count = 2,
        result = { Total = 2, Killed = 2, Survived = 0, Errors = 0 },
        tested_at = "2026-05-23T00:00:00Z",
      },
    })
    local serialized = scenario_manifest.serialize(data)
    local parsed = scenario_manifest.read(serialized)
    assert.is_not_nil(parsed)
    assert.are.equal(scenario_manifest.VERSION, parsed.version)
    assert.are.equal(1, #parsed.scenarios)
    assert.are.equal("alpha", parsed.scenarios[1].name)
  end)
end)

describe("acceptance4lua.scenario_manifest.apply", function()
  it("inserts a manifest block at the top of an unstamped feature", function()
    local source = "Feature: x\n"
    local result = scenario_manifest.apply(source, _sample_manifest())
    assert.is_truthy(result:find("^# acceptance%-mutation%-manifest%-begin\n"))
    assert.is_truthy(result:find("Feature: x", 1, true))
  end)

  it("places the manifest block after an existing mutation-stamp line", function()
    local source = "# mutation-stamp: sha256=abc\nFeature: x\n"
    local result = scenario_manifest.apply(source, _sample_manifest())
    assert.is_truthy(result:find("^# mutation%-stamp: sha256=abc\n# acceptance%-mutation%-manifest%-begin"))
  end)

  it("replaces an existing manifest block instead of duplicating it", function()
    local first = scenario_manifest.apply("Feature: x\n", _sample_manifest())
    local second = scenario_manifest.apply(first, _sample_manifest({
      {
        index = 0,
        name = "second",
        scenario_hash = "h",
        mutation_count = 0,
        result = { Total = 0, Killed = 0, Survived = 0, Errors = 0 },
        tested_at = "2026-05-23T00:00:00Z",
      },
    }))
    local _, count = second:gsub("acceptance%-mutation%-manifest%-begin", "")
    assert.are.equal(1, count)
    assert.is_truthy(second:find("\"name\": \"second\"", 1, true))
  end)
end)

describe("acceptance4lua.scenario_manifest.find_entry_for_index", function()
  it("locates entries by 0-based index", function()
    local manifest = _sample_manifest({
      { index = 0, name = "zero" },
      { index = 1, name = "one" },
    })
    assert.are.equal("zero", scenario_manifest.find_entry_for_index(manifest, 0).name)
    assert.are.equal("one", scenario_manifest.find_entry_for_index(manifest, 1).name)
  end)

  it("returns nil for missing indices and for a nil manifest", function()
    local manifest = _sample_manifest({ { index = 0, name = "only" } })
    assert.is_nil(scenario_manifest.find_entry_for_index(manifest, 5))
    assert.is_nil(scenario_manifest.find_entry_for_index(nil, 0))
  end)
end)

describe("acceptance4lua.scenario_manifest.decide_scenario_skip", function()
  local function _state_with(overrides)
    local state = {
      feature_name = "F",
      feature_path = "features/F.feature",
      background_hash = "bg-current",
      implementation_hash = "impl-current",
    }
    for key, value in pairs(overrides or {}) do
      state[key] = value
    end
    return state
  end

  local function _clean_entry(scenario, scenario_index)
    return {
      index = scenario_index,
      name = scenario.name,
      scenario_hash = spec_hash.compute_scenario_hash(scenario),
      mutation_count = 1,
      result = { Total = 1, Killed = 1, Survived = 0, Errors = 0 },
      tested_at = "2026-05-23T00:00:00Z",
    }
  end

  it("returns false when no manifest is provided", function()
    assert.is_false(scenario_manifest.decide_scenario_skip(
      nil, _sample_scenario("alpha"), 0, _state_with(), "hard"
    ))
  end)

  it("returns false at level=full regardless of manifest validity", function()
    local scenario = _sample_scenario("alpha")
    local manifest = _sample_manifest({ _clean_entry(scenario, 0) })
    assert.is_false(scenario_manifest.decide_scenario_skip(
      manifest, scenario, 0, _state_with(), "full"
    ))
  end)

  it("returns true when every condition holds at level=hard", function()
    local scenario = _sample_scenario("alpha")
    local manifest = _sample_manifest({ _clean_entry(scenario, 0) })
    assert.is_true(scenario_manifest.decide_scenario_skip(
      manifest, scenario, 0, _state_with(), "hard"
    ))
  end)

  it("returns false at level=hard when implementation_hash differs", function()
    local scenario = _sample_scenario("alpha")
    local manifest = _sample_manifest({ _clean_entry(scenario, 0) })
    manifest.implementation_hash = "impl-old"
    assert.is_false(scenario_manifest.decide_scenario_skip(
      manifest, scenario, 0, _state_with(), "hard"
    ))
  end)

  it("returns true at level=soft when implementation_hash differs", function()
    local scenario = _sample_scenario("alpha")
    local manifest = _sample_manifest({ _clean_entry(scenario, 0) })
    manifest.implementation_hash = "impl-old"
    assert.is_true(scenario_manifest.decide_scenario_skip(
      manifest, scenario, 0, _state_with(), "soft"
    ))
  end)

  it("returns false when background_hash differs", function()
    local scenario = _sample_scenario("alpha")
    local manifest = _sample_manifest({ _clean_entry(scenario, 0) })
    manifest.background_hash = "bg-old"
    assert.is_false(scenario_manifest.decide_scenario_skip(
      manifest, scenario, 0, _state_with(), "hard"
    ))
  end)

  it("returns false when scenario_hash mismatches", function()
    local scenario = _sample_scenario("alpha")
    local manifest = _sample_manifest({ _clean_entry(scenario, 0) })
    manifest.scenarios[1].scenario_hash = "wrong"
    assert.is_false(scenario_manifest.decide_scenario_skip(
      manifest, scenario, 0, _state_with(), "hard"
    ))
  end)

  it("returns false when scenario name was changed since the manifest was written", function()
    local scenario = _sample_scenario("renamed")
    local manifest = _sample_manifest({ _clean_entry(_sample_scenario("original"), 0) })
    assert.is_false(scenario_manifest.decide_scenario_skip(
      manifest, scenario, 0, _state_with(), "hard"
    ))
  end)

  it("returns false when prior Survived count was non-zero", function()
    local scenario = _sample_scenario("alpha")
    local entry = _clean_entry(scenario, 0)
    entry.result.Survived = 1
    local manifest = _sample_manifest({ entry })
    assert.is_false(scenario_manifest.decide_scenario_skip(
      manifest, scenario, 0, _state_with(), "hard"
    ))
  end)

  it("returns false when prior Errors count was non-zero", function()
    local scenario = _sample_scenario("alpha")
    local entry = _clean_entry(scenario, 0)
    entry.result.Errors = 2
    local manifest = _sample_manifest({ entry })
    assert.is_false(scenario_manifest.decide_scenario_skip(
      manifest, scenario, 0, _state_with(), "hard"
    ))
  end)

  it("returns false when manifest version differs", function()
    local scenario = _sample_scenario("alpha")
    local manifest = _sample_manifest({ _clean_entry(scenario, 0) })
    manifest.version = scenario_manifest.VERSION + 99
    assert.is_false(scenario_manifest.decide_scenario_skip(
      manifest, scenario, 0, _state_with(), "hard"
    ))
  end)

  it("returns false when scenario is missing from the manifest entirely", function()
    local manifest = _sample_manifest({})
    assert.is_false(scenario_manifest.decide_scenario_skip(
      manifest, _sample_scenario("alpha"), 0, _state_with(), "hard"
    ))
  end)
end)

describe("acceptance4lua.scenario_manifest.build_entry", function()
  it("counts killed/survived/error statuses correctly", function()
    local scenario = _sample_scenario("alpha")
    local results = {
      { status = "killed" },
      { status = "killed" },
      { status = "survived" },
      { status = "error" },
    }
    local entry = scenario_manifest.build_entry(scenario, 0, 5, results, "2026-05-23T00:00:00Z")
    assert.are.equal(0, entry.index)
    assert.are.equal("alpha", entry.name)
    assert.are.equal(5, entry.mutation_count)
    assert.are.equal(spec_hash.compute_scenario_hash(scenario), entry.scenario_hash)
    assert.are.equal(4, entry.result.Total)
    assert.are.equal(2, entry.result.Killed)
    assert.are.equal(1, entry.result.Survived)
    assert.are.equal(1, entry.result.Errors)
    assert.are.equal("2026-05-23T00:00:00Z", entry.tested_at)
  end)

  it("auto-fills tested_at with utc_now when omitted", function()
    local entry = scenario_manifest.build_entry(_sample_scenario(), 0, 0, {})
    assert.is_truthy(entry.tested_at:match("Z$"))
  end)
end)
