require("test.bootstrap").install_package_paths()
local check = require("luassert")
local json = require("acceptance4lua.json")
local mutator = require("acceptance4lua.mutator")

-- 原 busted 结构为三个并列顶层 describe（format_text_report skipped section /
-- success output budget / format_json_report skipped fields），均无钩子、无嵌套，
-- 拍平进单一类 TestMutatorReportSkipped，共 10 个用例。

local function _summary(overrides)
  local base = {
    total = 0,
    killed = 0,
    survived = 0,
    errors = 0,
  }
  for key, value in pairs(overrides or {}) do
    base[key] = value
  end
  return base
end

describe("mutator report skipped", function()

it("omits the skipped line when no scenarios or mutations were skipped", function()
  local report = { summary = _summary(), results = {} }
  local text = mutator.format_text_report(report)
  check.truthy(text:find("total=0", 1, true))
  check.is_nil(text:find("skipped_scenarios", 1, true))
  check.is_nil(text:find("skipped_mutations", 1, true))
end)

it("emits the skipped line when skipped scenarios is positive", function()
  local report = {
    summary = _summary({ skipped_scenarios = 3, skipped_mutations = 0 }),
    results = {},
  }
  local text = mutator.format_text_report(report)
  check.truthy(text:find("skipped_scenarios=3 skipped_mutations=0", 1, true))
end)

it("emits the skipped line when only skipped mutations is positive", function()
  local report = {
    summary = _summary({ skipped_scenarios = 0, skipped_mutations = 7 }),
    results = {},
  }
  local text = mutator.format_text_report(report)
  check.truthy(text:find("skipped_scenarios=0 skipped_mutations=7", 1, true))
end)

it("places the skipped line immediately after the summary line", function()
  local report = {
    summary = _summary({ killed = 2, skipped_scenarios = 1, skipped_mutations = 4 }),
    results = {},
  }
  local text = mutator.format_text_report(report)
  local lines = {}
  for line in text:gmatch("([^\n]+)") do
    lines[#lines + 1] = line
  end
  check.truthy(lines[1]:find("total="))
  check.truthy(lines[2]:find("skipped_scenarios="))
end)

it("omits killed mutation rows by default", function()
  local report = {
    summary = _summary({ total = 2, killed = 2 }),
    results = {
      {
        status = "killed",
        mutation = { description = "first noisy killed detail" },
        output = "",
        error = "",
      },
      {
        status = "killed",
        mutation = { description = "second noisy killed detail" },
        output = "",
        error = "",
      },
    },
  }

  local text = mutator.format_text_report(report)

  check.truthy(text:find("total=2 killed=2 survived=0 errors=0", 1, true))
  check.is_nil(text:find("first noisy killed detail", 1, true))
  check.is_nil(text:find("second noisy killed detail", 1, true))
end)

it("keeps killed mutation rows when verbose is requested", function()
  local report = {
    summary = _summary({ total = 1, killed = 1 }),
    results = {
      {
        status = "killed",
        mutation = { description = "verbose killed detail" },
        output = "",
        error = "",
      },
    },
  }

  local text = mutator.format_text_report(report, { verbose = true })

  check.truthy(text:find("verbose killed detail", 1, true))
end)

it("preserves survived diagnostics without verbose", function()
  local report = {
    summary = _summary({ total = 1, survived = 1 }),
    results = {
      {
        status = "survived",
        mutation = { description = "important survivor" },
        output = "runner output",
        error = "survivor error",
      },
    },
  }

  local text = mutator.format_text_report(report)

  check.truthy(text:find("important survivor", 1, true))
  check.truthy(text:find("survivor error", 1, true))
  check.truthy(text:find("runner output", 1, true))
end)

it("omits skipped scenarios and skipped mutations when no skips occurred", function()
  local report = { summary = _summary(), results = {} }
  local decoded = json.decode(mutator.format_json_report(report))
  check.is_nil(decoded.summary.SkippedScenarios)
  check.is_nil(decoded.summary.SkippedMutations)
end)

it("includes skipped scenarios and skipped mutations when skips are present", function()
  local report = {
    summary = _summary({ skipped_scenarios = 2, skipped_mutations = 5 }),
    results = {},
  }
  local decoded = json.decode(mutator.format_json_report(report))
  check.equal(2, decoded.summary.SkippedScenarios)
  check.equal(5, decoded.summary.SkippedMutations)
end)

it("preserves existing summary key casing alongside the new fields", function()
  local report = {
    summary = _summary({
      total = 3,
      killed = 3,
      skipped_scenarios = 1,
      skipped_mutations = 2,
    }),
    results = {},
  }
  local decoded = json.decode(mutator.format_json_report(report))
  check.equal(3, decoded.summary.Total)
  check.equal(3, decoded.summary.Killed)
  check.equal(0, decoded.summary.Survived)
  check.equal(0, decoded.summary.Errors)
  check.equal(1, decoded.summary.SkippedScenarios)
  check.equal(2, decoded.summary.SkippedMutations)
end)


end)
