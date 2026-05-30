local common = require("shared.lib.common")
local mutator = require("acceptance4lua.mutator")

local function _with_tmp_feature(body, fn)
  local tmp_root = common.make_temp_path("acceptance_mutator_level_", "")
  common.remove_path(tmp_root)
  common.ensure_dir(tmp_root)
  local feature_path = tmp_root .. "/a.feature"
  local handle = assert(io.open(feature_path, "w"))
  handle:write(body)
  handle:close()
  local ok, err = xpcall(function()
    fn(feature_path, tmp_root)
  end, debug.traceback)
  common.remove_path(tmp_root)
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

describe("acceptance4lua.mutator.run level validation", function()
  it("defaults missing level to hard and runs without level-level error", function()
    _with_tmp_feature(_minimal_feature_body(), function(feature_path, tmp_root)
      local report, err = mutator.run({
        feature = feature_path,
        work_dir = tmp_root .. "/work",
      })
      assert.is_nil(err)
      assert.is_not_nil(report)
    end)
  end)

  it("accepts level=full", function()
    _with_tmp_feature(_minimal_feature_body(), function(feature_path, tmp_root)
      local report, err = mutator.run({
        feature = feature_path,
        work_dir = tmp_root .. "/work",
        level = "full",
      })
      assert.is_nil(err)
      assert.is_not_nil(report)
    end)
  end)

  it("accepts level=hard", function()
    _with_tmp_feature(_minimal_feature_body(), function(feature_path, tmp_root)
      local report, err = mutator.run({
        feature = feature_path,
        work_dir = tmp_root .. "/work",
        level = "hard",
      })
      assert.is_nil(err)
      assert.is_not_nil(report)
    end)
  end)

  it("accepts level=soft", function()
    _with_tmp_feature(_minimal_feature_body(), function(feature_path, tmp_root)
      local report, err = mutator.run({
        feature = feature_path,
        work_dir = tmp_root .. "/work",
        level = "soft",
      })
      assert.is_nil(err)
      assert.is_not_nil(report)
    end)
  end)

  it("rejects an unknown level value before touching the filesystem", function()
    local report, err = mutator.run({
      feature = "/nonexistent/path/intentionally-bad.feature",
      work_dir = "/tmp/will-not-be-created",
      level = "nonsense",
    })
    assert.is_nil(report)
    assert.is_not_nil(err)
    assert.is_truthy(tostring(err):match("invalid level"))
  end)

  it("rejects non-string level values", function()
    local report, err = mutator.run({
      feature = "/dev/null",
      work_dir = "/tmp",
      level = 42,
    })
    assert.is_nil(report)
    assert.is_truthy(tostring(err):match("invalid level"))
  end)
end)

describe("acceptance4lua.mutator.run feature stamp interaction", function()
  it("writes a stamp to the feature file after a successful run", function()
    _with_tmp_feature(_minimal_feature_body(), function(feature_path, tmp_root)
      local feature_stamp = require("acceptance4lua.feature_stamp")

      local before = assert(common.read_file(feature_path))
      assert.is_nil(feature_stamp.read_stamp(before))

      local report, err = mutator.run({
        feature = feature_path,
        work_dir = tmp_root .. "/work",
        level = "hard",
      })
      assert.is_nil(err)
      assert.is_not_nil(report)

      local after = assert(common.read_file(feature_path))
      assert.is_not_nil(feature_stamp.read_stamp(after))
      assert.is_true(feature_stamp.is_stamp_current(after))
    end)
  end)

  it("skips the feature on a second hard-level run when the stamp is current", function()
    _with_tmp_feature(_minimal_feature_body(), function(feature_path, tmp_root)
      local first, first_err = mutator.run({
        feature = feature_path,
        work_dir = tmp_root .. "/work",
        level = "hard",
      })
      assert.is_nil(first_err)
      assert.are.equal(0, first.summary.skipped_scenarios)

      local second, second_err = mutator.run({
        feature = feature_path,
        work_dir = tmp_root .. "/work",
        level = "hard",
      })
      assert.is_nil(second_err)
      assert.is_true((second.summary.skipped_scenarios or 0) >= 1)
      assert.are.equal(0, second.summary.total)
    end)
  end)

  it("ignores the stamp at level=full", function()
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
      assert.is_nil(err)
      assert.are.equal(0, full_run.summary.skipped_scenarios)
    end)
  end)
end)

describe("acceptance4lua.mutator.run scenario manifest interaction", function()
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

  it("writes a scenario manifest after a successful run", function()
    _with_tmp_feature(_two_scenario_body(), function(feature_path, tmp_root)
      local scenario_manifest = require("acceptance4lua.scenario_manifest")

      local report, err = mutator.run({
        feature = feature_path,
        work_dir = tmp_root .. "/work",
        level = "hard",
      })
      assert.is_nil(err)
      assert.is_not_nil(report)

      local after = assert(common.read_file(feature_path))
      local manifest = scenario_manifest.read(after)
      assert.is_not_nil(manifest)
      assert.are.equal(scenario_manifest.VERSION, manifest.version)
      assert.are.equal(2, #manifest.scenarios)
    end)
  end)

  it("skips both scenarios on a clean second hard-level run", function()
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
      assert.is_nil(err)
      assert.are.equal(2, second.summary.skipped_scenarios)
      assert.are.equal(0, second.summary.total)
    end)
  end)

  it("does not rewrite the feature file when all scenarios are skipped", function()
    _with_tmp_feature(_two_scenario_body(), function(feature_path, tmp_root)
      local scenario_manifest = require("acceptance4lua.scenario_manifest")

      mutator.run({
        feature = feature_path,
        work_dir = tmp_root .. "/work",
        level = "hard",
      })
      local first_manifest = scenario_manifest.read(assert(common.read_file(feature_path)))
      local first_scenario_tested_at = first_manifest.scenarios[1].tested_at
      local first_content = assert(common.read_file(feature_path))

      mutator.run({
        feature = feature_path,
        work_dir = tmp_root .. "/work",
        level = "hard",
      })
      local second_content = assert(common.read_file(feature_path))
      local second_manifest = scenario_manifest.read(second_content)
      assert.are.equal(first_scenario_tested_at, second_manifest.scenarios[1].tested_at)
      assert.are.equal(first_content, second_content)
    end)
  end)

  it("does not skip via manifest at level=full", function()
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
      assert.is_nil(err)
      assert.are.equal(0, full_run.summary.skipped_scenarios)
    end)
  end)

  it("preserves a leading # language: zh-CN line across stamp+manifest writes", function()
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
      assert.is_nil(first_err)
      assert.is_not_nil(first)

      local content = assert(common.read_file(feature_path))
      assert.is_truthy(content:find("^# language: zh%-CN\n"))
      assert.is_truthy(content:find("# mutation%-stamp: sha256="))
      assert.is_truthy(content:find("# acceptance%-mutation%-manifest%-begin"))

      local second, second_err = mutator.run({
        feature = feature_path,
        work_dir = tmp_root .. "/work",
        level = "hard",
      })
      assert.is_nil(second_err)
      assert.is_true((second.summary.skipped_scenarios or 0) >= 1)
    end)
  end)
end)
