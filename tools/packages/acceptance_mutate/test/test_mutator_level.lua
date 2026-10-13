require("test.bootstrap").install_package_paths()
local check = require("luassert")
local env_lib = require("foundation.env")
local fs_lib = require("foundation.fs")
local mutator = require("acceptance4lua.mutator")

-- 12 个实际引擎用例静态迁入显式 busted DSL；Windows capability 分区排除本入口。
-- 纯 level 参数验证仍在 selected test_mutator_status_format.lua。

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

-- POSIX-only engine examples remain explicitly excluded on native Windows.

-- -------------------------------------------------- level validation

local function
defaults_missing_level_to_hard_and_runs_without_level_level_error()
  _with_tmp_feature(_minimal_feature_body(), function(feature_path, tmp_root)
    local report, err = mutator.run({
      feature = feature_path,
      work_dir = tmp_root .. "/work",
    })
    check.is_nil(err)
    check.is_not_nil(report)
  end)
end

local function
accepts_level_full()
  _with_tmp_feature(_minimal_feature_body(), function(feature_path, tmp_root)
    local report, err = mutator.run({
      feature = feature_path,
      work_dir = tmp_root .. "/work",
      level = "full",
    })
    check.is_nil(err)
    check.is_not_nil(report)
  end)
end

local function
accepts_level_hard()
  _with_tmp_feature(_minimal_feature_body(), function(feature_path, tmp_root)
    local report, err = mutator.run({
      feature = feature_path,
      work_dir = tmp_root .. "/work",
      level = "hard",
    })
    check.is_nil(err)
    check.is_not_nil(report)
  end)
end

local function
accepts_level_soft()
  _with_tmp_feature(_minimal_feature_body(), function(feature_path, tmp_root)
    local report, err = mutator.run({
      feature = feature_path,
      work_dir = tmp_root .. "/work",
      level = "soft",
    })
    check.is_nil(err)
    check.is_not_nil(report)
  end)
end

-- -------------------------------------------------- feature stamp interaction

local function
writes_a_stamp_to_the_feature_file_after_a_successful_run()
  _with_tmp_feature(_minimal_feature_body(), function(feature_path, tmp_root)
    local feature_stamp = require("acceptance4lua.feature_stamp")

    local before = assert(fs_lib.read_file(feature_path))
    check.is_nil(feature_stamp.read_stamp(before))

    local report, err = mutator.run({
      feature = feature_path,
      work_dir = tmp_root .. "/work",
      level = "hard",
    })
    check.is_nil(err)
    check.is_not_nil(report)

    local after = assert(fs_lib.read_file(feature_path))
    check.is_not_nil(feature_stamp.read_stamp(after))
    check.is_true(feature_stamp.is_stamp_current(after))
  end)
end

local function
skips_the_feature_on_a_second_hard_level_run_when_the_stamp_is_current()
  _with_tmp_feature(_minimal_feature_body(), function(feature_path, tmp_root)
    local first, first_err = mutator.run({
      feature = feature_path,
      work_dir = tmp_root .. "/work",
      level = "hard",
    })
    check.is_nil(first_err)
    check.equal(0, first.summary.skipped_scenarios)

    local second, second_err = mutator.run({
      feature = feature_path,
      work_dir = tmp_root .. "/work",
      level = "hard",
    })
    check.is_nil(second_err)
    check.is_true((second.summary.skipped_scenarios or 0) >= 1)
    check.equal(0, second.summary.total)
  end)
end

local function
ignores_the_stamp_at_level_full()
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
    check.is_nil(err)
    check.equal(0, full_run.summary.skipped_scenarios)
  end)
end

-- -------------------------------------------------- scenario manifest interaction

local function
writes_a_scenario_manifest_after_a_successful_run()
  _with_tmp_feature(_two_scenario_body(), function(feature_path, tmp_root)
    local scenario_manifest = require("acceptance4lua.scenario_manifest")

    local report, err = mutator.run({
      feature = feature_path,
      work_dir = tmp_root .. "/work",
      level = "hard",
    })
    check.is_nil(err)
    check.is_not_nil(report)

    local after = assert(fs_lib.read_file(feature_path))
    local manifest = scenario_manifest.read(after)
    check.is_not_nil(manifest)
    check.equal(scenario_manifest.VERSION, manifest.version)
    check.equal(2, #manifest.scenarios)
  end)
end

local function
skips_both_scenarios_on_a_clean_second_hard_level_run()
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
    check.is_nil(err)
    check.equal(2, second.summary.skipped_scenarios)
    check.equal(0, second.summary.total)
  end)
end

local function
does_not_rewrite_the_feature_file_when_all_scenarios_are_skipped()
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
    check.equal(first_scenario_tested_at, second_manifest.scenarios[1].tested_at)
    check.equal(first_content, second_content)
  end)
end

local function
does_not_skip_via_manifest_at_level_full()
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
    check.is_nil(err)
    check.equal(0, full_run.summary.skipped_scenarios)
  end)
end

local function
preserves_a_leading_language_zh_cn_line_across_stamp_and_manifest_writes()
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
    check.is_nil(first_err)
    check.is_not_nil(first)

    local content = assert(fs_lib.read_file(feature_path))
    check.truthy(content:find("^# language: zh%-CN\n"))
    check.truthy(content:find("# mutation%-stamp: sha256="))
    check.truthy(content:find("# acceptance%-mutation%-manifest%-begin"))

    local second, second_err = mutator.run({
      feature = feature_path,
      work_dir = tmp_root .. "/work",
      level = "hard",
    })
    check.is_nil(second_err)
    check.is_true((second.summary.skipped_scenarios or 0) >= 1)
  end)
end


describe("acceptance mutator levels POSIX capability", function()
  it("defaults_missing_level_to_hard_and_runs_without_level_level_error", defaults_missing_level_to_hard_and_runs_without_level_level_error)
  it("accepts_level_full", accepts_level_full)
  it("accepts_level_hard", accepts_level_hard)
  it("accepts_level_soft", accepts_level_soft)
  it("writes_a_stamp_to_the_feature_file_after_a_successful_run", writes_a_stamp_to_the_feature_file_after_a_successful_run)
  it("skips_the_feature_on_a_second_hard_level_run_when_the_stamp_is_current", skips_the_feature_on_a_second_hard_level_run_when_the_stamp_is_current)
  it("ignores_the_stamp_at_level_full", ignores_the_stamp_at_level_full)
  it("writes_a_scenario_manifest_after_a_successful_run", writes_a_scenario_manifest_after_a_successful_run)
  it("skips_both_scenarios_on_a_clean_second_hard_level_run", skips_both_scenarios_on_a_clean_second_hard_level_run)
  it("does_not_rewrite_the_feature_file_when_all_scenarios_are_skipped", does_not_rewrite_the_feature_file_when_all_scenarios_are_skipped)
  it("does_not_skip_via_manifest_at_level_full", does_not_skip_via_manifest_at_level_full)
  it("preserves_a_leading_language_zh_cn_line_across_stamp_and_manifest_writes", preserves_a_leading_language_zh_cn_line_across_stamp_and_manifest_writes)
end)
