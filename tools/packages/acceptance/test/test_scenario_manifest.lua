local lu = require("luaunit")
local scenario_manifest = require("acceptance4lua.scenario_manifest")
local spec_hash = require("acceptance4lua.spec_hash")

-- 由原 busted DSL 拍平为 LuaUnit 风格:6 个无钩子 describe 全部并入
-- 单一类 TestScenarioManifest,decide_scenario_skip describe 体内的
-- _state_with / _clean_entry 辅助函数提升为文件级 local。用例数 23 不变。

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

TestScenarioManifest = {}

-- 原 describe("acceptance4lua.scenario_manifest.utc_now")

function TestScenarioManifest:test_utc_now_returns_an_iso_8601_utc_string_with_the_z_suffix()
  local now = scenario_manifest.utc_now()
  lu.assertEvalToTrue(now:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$"))
end

-- 原 describe("acceptance4lua.scenario_manifest.read")

function TestScenarioManifest:test_read_returns_nil_when_the_feature_has_no_manifest_block()
  lu.assertNil(scenario_manifest.read("Feature: x\nScenario: s\n"))
end

function TestScenarioManifest:test_read_returns_nil_when_manifest_json_is_malformed()
  local source =
    "# acceptance-mutation-manifest-begin\n# {not json\n# acceptance-mutation-manifest-end\n"
  lu.assertNil(scenario_manifest.read(source))
end

function TestScenarioManifest:test_read_round_trips_through_serialize()
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
  lu.assertNotNil(parsed)
  lu.assertIs(parsed.version, scenario_manifest.VERSION)
  lu.assertIs(#parsed.scenarios, 1)
  lu.assertIs(parsed.scenarios[1].name, "alpha")
end

-- 原 describe("acceptance4lua.scenario_manifest.apply")

function TestScenarioManifest:test_apply_inserts_a_manifest_block_at_the_top_of_an_unstamped_feature()
  local source = "Feature: x\n"
  local result = scenario_manifest.apply(source, _sample_manifest())
  lu.assertEvalToTrue(result:find("^# acceptance%-mutation%-manifest%-begin\n"))
  lu.assertEvalToTrue(result:find("Feature: x", 1, true))
end

function TestScenarioManifest:test_apply_places_the_manifest_block_after_an_existing_mutation_stamp_line()
  local source = "# mutation-stamp: sha256=abc\nFeature: x\n"
  local result = scenario_manifest.apply(source, _sample_manifest())
  lu.assertEvalToTrue(result:find("^# mutation%-stamp: sha256=abc\n# acceptance%-mutation%-manifest%-begin"))
end

function TestScenarioManifest:test_apply_replaces_an_existing_manifest_block_instead_of_duplicating_it()
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
  lu.assertIs(count, 1)
  lu.assertEvalToTrue(second:find("\"name\": \"second\"", 1, true))
end

-- 原 describe("acceptance4lua.scenario_manifest.find_entry_for_index")

function TestScenarioManifest:test_find_entry_for_index_locates_entries_by_0_based_index()
  local manifest = _sample_manifest({
    { index = 0, name = "zero" },
    { index = 1, name = "one" },
  })
  lu.assertIs(scenario_manifest.find_entry_for_index(manifest, 0).name, "zero")
  lu.assertIs(scenario_manifest.find_entry_for_index(manifest, 1).name, "one")
end

function TestScenarioManifest:test_find_entry_for_index_returns_nil_for_missing_indices_and_for_a_nil_manifest()
  local manifest = _sample_manifest({ { index = 0, name = "only" } })
  lu.assertNil(scenario_manifest.find_entry_for_index(manifest, 5))
  lu.assertNil(scenario_manifest.find_entry_for_index(nil, 0))
end

-- 原 describe("acceptance4lua.scenario_manifest.decide_scenario_skip")

function TestScenarioManifest:test_decide_scenario_skip_returns_false_when_no_manifest_is_provided()
  lu.assertFalse(scenario_manifest.decide_scenario_skip(
    nil, _sample_scenario("alpha"), 0, _state_with(), "hard"
  ))
end

function TestScenarioManifest:test_decide_scenario_skip_returns_false_at_level_full_regardless_of_manifest_validity()
  local scenario = _sample_scenario("alpha")
  local manifest = _sample_manifest({ _clean_entry(scenario, 0) })
  lu.assertFalse(scenario_manifest.decide_scenario_skip(
    manifest, scenario, 0, _state_with(), "full"
  ))
end

function TestScenarioManifest:test_decide_scenario_skip_returns_true_when_every_condition_holds_at_level_hard()
  local scenario = _sample_scenario("alpha")
  local manifest = _sample_manifest({ _clean_entry(scenario, 0) })
  lu.assertTrue(scenario_manifest.decide_scenario_skip(
    manifest, scenario, 0, _state_with(), "hard"
  ))
end

function TestScenarioManifest:test_decide_scenario_skip_returns_false_at_level_hard_when_implementation_hash_differs()
  local scenario = _sample_scenario("alpha")
  local manifest = _sample_manifest({ _clean_entry(scenario, 0) })
  manifest.implementation_hash = "impl-old"
  lu.assertFalse(scenario_manifest.decide_scenario_skip(
    manifest, scenario, 0, _state_with(), "hard"
  ))
end

function TestScenarioManifest:test_decide_scenario_skip_returns_true_at_level_soft_when_implementation_hash_differs()
  local scenario = _sample_scenario("alpha")
  local manifest = _sample_manifest({ _clean_entry(scenario, 0) })
  manifest.implementation_hash = "impl-old"
  lu.assertTrue(scenario_manifest.decide_scenario_skip(
    manifest, scenario, 0, _state_with(), "soft"
  ))
end

function TestScenarioManifest:test_decide_scenario_skip_returns_false_when_background_hash_differs()
  local scenario = _sample_scenario("alpha")
  local manifest = _sample_manifest({ _clean_entry(scenario, 0) })
  manifest.background_hash = "bg-old"
  lu.assertFalse(scenario_manifest.decide_scenario_skip(
    manifest, scenario, 0, _state_with(), "hard"
  ))
end

function TestScenarioManifest:test_decide_scenario_skip_returns_false_when_scenario_hash_mismatches()
  local scenario = _sample_scenario("alpha")
  local manifest = _sample_manifest({ _clean_entry(scenario, 0) })
  manifest.scenarios[1].scenario_hash = "wrong"
  lu.assertFalse(scenario_manifest.decide_scenario_skip(
    manifest, scenario, 0, _state_with(), "hard"
  ))
end

function TestScenarioManifest:test_decide_scenario_skip_returns_false_when_scenario_name_was_changed_since_the_manifest_was_written()
  local scenario = _sample_scenario("renamed")
  local manifest = _sample_manifest({ _clean_entry(_sample_scenario("original"), 0) })
  lu.assertFalse(scenario_manifest.decide_scenario_skip(
    manifest, scenario, 0, _state_with(), "hard"
  ))
end

function TestScenarioManifest:test_decide_scenario_skip_returns_false_when_prior_survived_count_was_non_zero()
  local scenario = _sample_scenario("alpha")
  local entry = _clean_entry(scenario, 0)
  entry.result.Survived = 1
  local manifest = _sample_manifest({ entry })
  lu.assertFalse(scenario_manifest.decide_scenario_skip(
    manifest, scenario, 0, _state_with(), "hard"
  ))
end

function TestScenarioManifest:test_decide_scenario_skip_returns_false_when_prior_errors_count_was_non_zero()
  local scenario = _sample_scenario("alpha")
  local entry = _clean_entry(scenario, 0)
  entry.result.Errors = 2
  local manifest = _sample_manifest({ entry })
  lu.assertFalse(scenario_manifest.decide_scenario_skip(
    manifest, scenario, 0, _state_with(), "hard"
  ))
end

function TestScenarioManifest:test_decide_scenario_skip_returns_false_when_manifest_version_differs()
  local scenario = _sample_scenario("alpha")
  local manifest = _sample_manifest({ _clean_entry(scenario, 0) })
  manifest.version = scenario_manifest.VERSION + 99
  lu.assertFalse(scenario_manifest.decide_scenario_skip(
    manifest, scenario, 0, _state_with(), "hard"
  ))
end

function TestScenarioManifest:test_decide_scenario_skip_returns_false_when_scenario_is_missing_from_the_manifest_entirely()
  local manifest = _sample_manifest({})
  lu.assertFalse(scenario_manifest.decide_scenario_skip(
    manifest, _sample_scenario("alpha"), 0, _state_with(), "hard"
  ))
end

-- 原 describe("acceptance4lua.scenario_manifest.build_entry")

function TestScenarioManifest:test_build_entry_counts_killed_survived_error_statuses_correctly()
  local scenario = _sample_scenario("alpha")
  local results = {
    { status = "killed" },
    { status = "killed" },
    { status = "survived" },
    { status = "error" },
  }
  local entry = scenario_manifest.build_entry(scenario, 0, 5, results, "2026-05-23T00:00:00Z")
  lu.assertIs(entry.index, 0)
  lu.assertIs(entry.name, "alpha")
  lu.assertIs(entry.mutation_count, 5)
  lu.assertIs(entry.scenario_hash, spec_hash.compute_scenario_hash(scenario))
  lu.assertIs(entry.result.Total, 4)
  lu.assertIs(entry.result.Killed, 2)
  lu.assertIs(entry.result.Survived, 1)
  lu.assertIs(entry.result.Errors, 1)
  lu.assertIs(entry.tested_at, "2026-05-23T00:00:00Z")
end

function TestScenarioManifest:test_build_entry_auto_fills_tested_at_with_utc_now_when_omitted()
  local entry = scenario_manifest.build_entry(_sample_scenario(), 0, 0, {})
  lu.assertEvalToTrue(entry.tested_at:match("Z$"))
end


return TestScenarioManifest
