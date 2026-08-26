local lu = require("luaunit")
local env_lib = require("foundation.env")
local fs_lib = require("foundation.fs")
local mutator = require("acceptance4lua.mutator")

-- 原生 LuaUnit 迁移:三个顶层 describe(level validation / feature stamp interaction /
-- scenario manifest interaction)均无钩子、无共享 local,全部拍平进 TestMutatorLevel,
-- 用例数与改写前一致(6 + 3 + 5 = 14 例);第三组的 _two_scenario_body 提升为文件级 helper。

local function _with_tmp_feature(body, fn)
  local tmp_root = env_lib.make_temp_path("acceptance_mutator_level_", "")
  fs_lib.remove_path(tmp_root)
  fs_lib.ensure_dir(tmp_root)
  local feature_path = tmp_root .. "/a.feature"
  local handle = assert(io.open(feature_path, "w"))
  handle:write(body)
  handle:close()
  local ok, err = xpcall(function()
    fn(feature_path, tmp_root)
  end, debug.traceback)
  fs_lib.remove_path(tmp_root)
  if not ok then
    error(err)
  end
end

local function _minimal_feature_body()
  return table.concat({
    "Feature: empty",
    "",
    "Scenario: no examples",
    "  Given nothing happens",
    "",
  }, "\n")
end

local function _two_scenario_body()
  return table.concat({
    "Feature: two scenarios",
    "",
    "Scenario: first",
    "  Given nothing happens here",
    "",
    "Scenario: second",
    "  Given nothing happens there",
    "",
  }, "\n")
end

TestMutatorLevel = {}

-- -------------------------------------------------- level validation

function TestMutatorLevel:test_defaults_missing_level_to_hard_and_runs_without_level_level_error()
  _with_tmp_feature(_minimal_feature_body(), function(feature_path, tmp_root)
    local report, err = mutator.run({
      feature = feature_path,
      work_dir = tmp_root .. "/work",
    })
    lu.assertNil(err)
    lu.assertNotNil(report)
  end)
end

function TestMutatorLevel:test_accepts_level_full()
  _with_tmp_feature(_minimal_feature_body(), function(feature_path, tmp_root)
    local report, err = mutator.run({
      feature = feature_path,
      work_dir = tmp_root .. "/work",
      level = "full",
    })
    lu.assertNil(err)
    lu.assertNotNil(report)
  end)
end

function TestMutatorLevel:test_accepts_level_hard()
  _with_tmp_feature(_minimal_feature_body(), function(feature_path, tmp_root)
    local report, err = mutator.run({
      feature = feature_path,
      work_dir = tmp_root .. "/work",
      level = "hard",
    })
    lu.assertNil(err)
    lu.assertNotNil(report)
  end)
end

function TestMutatorLevel:test_accepts_level_soft()
  _with_tmp_feature(_minimal_feature_body(), function(feature_path, tmp_root)
    local report, err = mutator.run({
      feature = feature_path,
      work_dir = tmp_root .. "/work",
      level = "soft",
    })
    lu.assertNil(err)
    lu.assertNotNil(report)
  end)
end

function TestMutatorLevel:test_rejects_an_unknown_level_value_before_touching_the_filesystem()
  local report, err = mutator.run({
    feature = "/nonexistent/path/intentionally-bad.feature",
    work_dir = "/tmp/will-not-be-created",
    level = "nonsense",
  })
  lu.assertNil(report)
  lu.assertNotNil(err)
  lu.assertEvalToTrue(tostring(err):match("invalid level"))
end

function TestMutatorLevel:test_rejects_non_string_level_values()
  local report, err = mutator.run({
    feature = "/dev/null",
    work_dir = "/tmp",
    level = 42,
  })
  lu.assertNil(report)
  lu.assertEvalToTrue(tostring(err):match("invalid level"))
end

-- -------------------------------------------------- feature stamp interaction

function TestMutatorLevel:test_writes_a_stamp_to_the_feature_file_after_a_successful_run()
  _with_tmp_feature(_minimal_feature_body(), function(feature_path, tmp_root)
    local feature_stamp = require("acceptance4lua.feature_stamp")

    local before = assert(fs_lib.read_file(feature_path))
    lu.assertNil(feature_stamp.read_stamp(before))

    local report, err = mutator.run({
      feature = feature_path,
      work_dir = tmp_root .. "/work",
      level = "hard",
    })
    lu.assertNil(err)
    lu.assertNotNil(report)

    local after = assert(fs_lib.read_file(feature_path))
    lu.assertNotNil(feature_stamp.read_stamp(after))
    lu.assertTrue(feature_stamp.is_stamp_current(after))
  end)
end

function TestMutatorLevel:test_skips_the_feature_on_a_second_hard_level_run_when_the_stamp_is_current()
  _with_tmp_feature(_minimal_feature_body(), function(feature_path, tmp_root)
    local first, first_err = mutator.run({
      feature = feature_path,
      work_dir = tmp_root .. "/work",
      level = "hard",
    })
    lu.assertNil(first_err)
    lu.assertIs(first.summary.skipped_scenarios, 0)

    local second, second_err = mutator.run({
      feature = feature_path,
      work_dir = tmp_root .. "/work",
      level = "hard",
    })
    lu.assertNil(second_err)
    lu.assertTrue((second.summary.skipped_scenarios or 0) >= 1)
    lu.assertIs(second.summary.total, 0)
  end)
end

function TestMutatorLevel:test_ignores_the_stamp_at_level_full()
  _with_tmp_feature(_minimal_feature_body(), function(feature_path, tmp_root)
    mutator.run({
      feature = feature_path,
      work_dir = tmp_root .. "/work",
      level = "hard",
    })
    local full_run, err = mutator.run({
      feature = feature_path,
      work_dir = tmp_root .. "/work",
      level = "full",
    })
    lu.assertNil(err)
    lu.assertIs(full_run.summary.skipped_scenarios, 0)
  end)
end

-- -------------------------------------------------- scenario manifest interaction

function TestMutatorLevel:test_writes_a_scenario_manifest_after_a_successful_run()
  _with_tmp_feature(_two_scenario_body(), function(feature_path, tmp_root)
    local scenario_manifest = require("acceptance4lua.scenario_manifest")

    local report, err = mutator.run({
      feature = feature_path,
      work_dir = tmp_root .. "/work",
      level = "hard",
    })
    lu.assertNil(err)
    lu.assertNotNil(report)

    local after = assert(fs_lib.read_file(feature_path))
    local manifest = scenario_manifest.read(after)
    lu.assertNotNil(manifest)
    lu.assertIs(manifest.version, scenario_manifest.VERSION)
    lu.assertIs(#manifest.scenarios, 2)
  end)
end

function TestMutatorLevel:test_skips_both_scenarios_on_a_clean_second_hard_level_run()
  _with_tmp_feature(_two_scenario_body(), function(feature_path, tmp_root)
    mutator.run({
      feature = feature_path,
      work_dir = tmp_root .. "/work",
      level = "hard",
    })
    local second, err = mutator.run({
      feature = feature_path,
      work_dir = tmp_root .. "/work",
      level = "hard",
    })
    lu.assertNil(err)
    lu.assertIs(second.summary.skipped_scenarios, 2)
    lu.assertIs(second.summary.total, 0)
  end)
end

function TestMutatorLevel:test_does_not_rewrite_the_feature_file_when_all_scenarios_are_skipped()
  _with_tmp_feature(_two_scenario_body(), function(feature_path, tmp_root)
    local scenario_manifest = require("acceptance4lua.scenario_manifest")

    mutator.run({
      feature = feature_path,
      work_dir = tmp_root .. "/work",
      level = "hard",
    })
    local first_manifest = scenario_manifest.read(assert(fs_lib.read_file(feature_path)))
    local first_scenario_tested_at = first_manifest.scenarios[1].tested_at
    local first_content = assert(fs_lib.read_file(feature_path))

    mutator.run({
      feature = feature_path,
      work_dir = tmp_root .. "/work",
      level = "hard",
    })
    local second_content = assert(fs_lib.read_file(feature_path))
    local second_manifest = scenario_manifest.read(second_content)
    lu.assertIs(second_manifest.scenarios[1].tested_at, first_scenario_tested_at)
    lu.assertIs(second_content, first_content)
  end)
end

function TestMutatorLevel:test_does_not_skip_via_manifest_at_level_full()
  _with_tmp_feature(_two_scenario_body(), function(feature_path, tmp_root)
    mutator.run({
      feature = feature_path,
      work_dir = tmp_root .. "/work",
      level = "hard",
    })
    local full_run, err = mutator.run({
      feature = feature_path,
      work_dir = tmp_root .. "/work",
      level = "full",
    })
    lu.assertNil(err)
    lu.assertIs(full_run.summary.skipped_scenarios, 0)
  end)
end

function TestMutatorLevel:test_preserves_a_leading_language_zh_cn_line_across_stamp_and_manifest_writes()
  local chinese_body = table.concat({
    "# language: zh-CN",
    "",
    "功能: 中文示例",
    "",
    "场景: 一个空场景",
    "  假如 什么都不做",
    "",
  }, "\n")
  _with_tmp_feature(chinese_body, function(feature_path, tmp_root)
    local first, first_err = mutator.run({
      feature = feature_path,
      work_dir = tmp_root .. "/work",
      level = "hard",
    })
    lu.assertNil(first_err)
    lu.assertNotNil(first)

    local content = assert(fs_lib.read_file(feature_path))
    lu.assertEvalToTrue(content:find("^# language: zh%-CN\n"))
    lu.assertEvalToTrue(content:find("# mutation%-stamp: sha256="))
    lu.assertEvalToTrue(content:find("# acceptance%-mutation%-manifest%-begin"))

    local second, second_err = mutator.run({
      feature = feature_path,
      work_dir = tmp_root .. "/work",
      level = "hard",
    })
    lu.assertNil(second_err)
    lu.assertTrue((second.summary.skipped_scenarios or 0) >= 1)
  end)
end


return TestMutatorLevel
