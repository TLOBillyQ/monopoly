require("test.bootstrap").install_package_paths()
local check = require("luassert")
local scenario_manifest = require("acceptance4lua.scenario_manifest")
local spec_hash = require("acceptance4lua.spec_hash")

-- 场景清单的公开读写、跳过判定及结果计数契约,共 23 个独立用例。

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

describe("acceptance scenario manifest", function()

-- 原 describe("acceptance4lua.scenario_manifest.utc_now")

it("utc now returns ISO 8601 with Z suffix", function()
  local now = scenario_manifest.utc_now()
  check.truthy(now:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$"))
end)

-- 原 describe("acceptance4lua.scenario_manifest.read")

it("read returns nil without a manifest block", function()
  check.is_nil(scenario_manifest.read("Feature: x\nScenario: s\n"))
end)

it("read returns nil for malformed JSON", function()
  local source =
    "# acceptance-mutation-manifest-begin\n# {not json\n# acceptance-mutation-manifest-end\n"
  check.is_nil(scenario_manifest.read(source))
end)

it("read round trips through serialize", function()
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
  check.is_not_nil(parsed)
  check.equal(parsed.version, scenario_manifest.VERSION)
  check.equal(#parsed.scenarios, 1)
  check.equal(parsed.scenarios[1].name, "alpha")
end)

-- 原 describe("acceptance4lua.scenario_manifest.apply")

it("apply inserts block at top of unstamped feature", function()
  local source = "Feature: x\n"
  local result = scenario_manifest.apply(source, _sample_manifest())
  check.truthy(result:find("^# acceptance%-mutation%-manifest%-begin\n"))
  check.truthy(result:find("Feature: x", 1, true))
end)

it("apply places block after mutation stamp", function()
  local source = "# mutation-stamp: sha256=abc\nFeature: x\n"
  local result = scenario_manifest.apply(source, _sample_manifest())
  check.truthy(result:find("^# mutation%-stamp: sha256=abc\n# acceptance%-mutation%-manifest%-begin"))
end)

it("apply replaces block without duplication", function()
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
  check.equal(count, 1)
  check.truthy(second:find("\"name\": \"second\"", 1, true))
end)

-- 原 describe("acceptance4lua.scenario_manifest.find_entry_for_index")

it("find entry uses zero based index", function()
  local manifest = _sample_manifest({
    { index = 0, name = "zero" },
    { index = 1, name = "one" },
  })
  check.equal(scenario_manifest.find_entry_for_index(manifest, 0).name, "zero")
  check.equal(scenario_manifest.find_entry_for_index(manifest, 1).name, "one")
end)

it("find entry returns nil for missing index or manifest", function()
  local manifest = _sample_manifest({ { index = 0, name = "only" } })
  check.is_nil(scenario_manifest.find_entry_for_index(manifest, 5))
  check.is_nil(scenario_manifest.find_entry_for_index(nil, 0))
end)

-- 原 describe("acceptance4lua.scenario_manifest.decide_scenario_skip")

it("skip returns false without manifest", function()
  check.is_false(scenario_manifest.decide_scenario_skip(
    nil, _sample_scenario("alpha"), 0, _state_with(), "hard"
  ))
end)

it("full level always returns false", function()
  local scenario = _sample_scenario("alpha")
  local manifest = _sample_manifest({ _clean_entry(scenario, 0) })
  check.is_false(scenario_manifest.decide_scenario_skip(
    manifest, scenario, 0, _state_with(), "full"
  ))
end)

it("hard level skips when every condition holds", function()
  local scenario = _sample_scenario("alpha")
  local manifest = _sample_manifest({ _clean_entry(scenario, 0) })
  check.is_true(scenario_manifest.decide_scenario_skip(
    manifest, scenario, 0, _state_with(), "hard"
  ))
end)

it("hard level rejects changed implementation hash", function()
  local scenario = _sample_scenario("alpha")
  local manifest = _sample_manifest({ _clean_entry(scenario, 0) })
  manifest.implementation_hash = "impl-old"
  check.is_false(scenario_manifest.decide_scenario_skip(
    manifest, scenario, 0, _state_with(), "hard"
  ))
end)

it("soft level accepts changed implementation hash", function()
  local scenario = _sample_scenario("alpha")
  local manifest = _sample_manifest({ _clean_entry(scenario, 0) })
  manifest.implementation_hash = "impl-old"
  check.is_true(scenario_manifest.decide_scenario_skip(
    manifest, scenario, 0, _state_with(), "soft"
  ))
end)

it("skip rejects changed background hash", function()
  local scenario = _sample_scenario("alpha")
  local manifest = _sample_manifest({ _clean_entry(scenario, 0) })
  manifest.background_hash = "bg-old"
  check.is_false(scenario_manifest.decide_scenario_skip(
    manifest, scenario, 0, _state_with(), "hard"
  ))
end)

it("skip rejects mismatched scenario hash", function()
  local scenario = _sample_scenario("alpha")
  local manifest = _sample_manifest({ _clean_entry(scenario, 0) })
  manifest.scenarios[1].scenario_hash = "wrong"
  check.is_false(scenario_manifest.decide_scenario_skip(
    manifest, scenario, 0, _state_with(), "hard"
  ))
end)

it("skip rejects changed scenario name", function()
  local scenario = _sample_scenario("renamed")
  local manifest = _sample_manifest({ _clean_entry(_sample_scenario("original"), 0) })
  check.is_false(scenario_manifest.decide_scenario_skip(
    manifest, scenario, 0, _state_with(), "hard"
  ))
end)

it("skip rejects prior survivors", function()
  local scenario = _sample_scenario("alpha")
  local entry = _clean_entry(scenario, 0)
  entry.result.Survived = 1
  local manifest = _sample_manifest({ entry })
  check.is_false(scenario_manifest.decide_scenario_skip(
    manifest, scenario, 0, _state_with(), "hard"
  ))
end)

it("skip rejects prior errors", function()
  local scenario = _sample_scenario("alpha")
  local entry = _clean_entry(scenario, 0)
  entry.result.Errors = 2
  local manifest = _sample_manifest({ entry })
  check.is_false(scenario_manifest.decide_scenario_skip(
    manifest, scenario, 0, _state_with(), "hard"
  ))
end)

it("skip rejects changed manifest version", function()
  local scenario = _sample_scenario("alpha")
  local manifest = _sample_manifest({ _clean_entry(scenario, 0) })
  manifest.version = scenario_manifest.VERSION + 99
  check.is_false(scenario_manifest.decide_scenario_skip(
    manifest, scenario, 0, _state_with(), "hard"
  ))
end)

it("skip rejects missing scenario entry", function()
  local manifest = _sample_manifest({})
  check.is_false(scenario_manifest.decide_scenario_skip(
    manifest, _sample_scenario("alpha"), 0, _state_with(), "hard"
  ))
end)

-- 原 describe("acceptance4lua.scenario_manifest.build_entry")

it("build entry counts killed survived and error statuses", function()
  local scenario = _sample_scenario("alpha")
  local results = {
    { status = "killed" },
    { status = "killed" },
    { status = "survived" },
    { status = "error" },
  }
  local entry = scenario_manifest.build_entry(scenario, 0, 5, results, "2026-05-23T00:00:00Z")
  check.equal(entry.index, 0)
  check.equal(entry.name, "alpha")
  check.equal(entry.mutation_count, 5)
  check.equal(entry.scenario_hash, spec_hash.compute_scenario_hash(scenario))
  check.equal(entry.result.Total, 4)
  check.equal(entry.result.Killed, 2)
  check.equal(entry.result.Survived, 1)
  check.equal(entry.result.Errors, 1)
  check.equal(entry.tested_at, "2026-05-23T00:00:00Z")
end)

it("build entry fills omitted tested at with UTC now", function()
  local entry = scenario_manifest.build_entry(_sample_scenario(), 0, 0, {})
  check.truthy(entry.tested_at:match("Z$"))
end)
end)
