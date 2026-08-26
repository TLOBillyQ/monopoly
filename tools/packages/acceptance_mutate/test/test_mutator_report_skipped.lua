local lu = require("luaunit")
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

TestMutatorReportSkipped = {}

function TestMutatorReportSkipped:test_omits_the_skipped_line_when_no_scenarios_or_mutations_were_skipped()
  local report = { summary = _summary(), results = {} }
  local text = mutator.format_text_report(report)
  lu.assertEvalToTrue(text:find("total=0", 1, true))
  lu.assertNil(text:find("skipped_scenarios", 1, true))
  lu.assertNil(text:find("skipped_mutations", 1, true))
end

function TestMutatorReportSkipped:test_emits_the_skipped_line_when_skipped_scenarios_is_positive()
  local report = {
    summary = _summary({ skipped_scenarios = 3, skipped_mutations = 0 }),
    results = {},
  }
  local text = mutator.format_text_report(report)
  lu.assertEvalToTrue(text:find("skipped_scenarios=3 skipped_mutations=0", 1, true))
end

function TestMutatorReportSkipped:test_emits_the_skipped_line_when_only_skipped_mutations_is_positive()
  local report = {
    summary = _summary({ skipped_scenarios = 0, skipped_mutations = 7 }),
    results = {},
  }
  local text = mutator.format_text_report(report)
  lu.assertEvalToTrue(text:find("skipped_scenarios=0 skipped_mutations=7", 1, true))
end

function TestMutatorReportSkipped:test_places_the_skipped_line_immediately_after_the_summary_line()
  local report = {
    summary = _summary({ killed = 2, skipped_scenarios = 1, skipped_mutations = 4 }),
    results = {},
  }
  local text = mutator.format_text_report(report)
  local lines = {}
  for line in text:gmatch("([^\n]+)") do
    lines[#lines + 1] = line
  end
  lu.assertEvalToTrue(lines[1]:find("total="))
  lu.assertEvalToTrue(lines[2]:find("skipped_scenarios="))
end

function TestMutatorReportSkipped:test_omits_killed_mutation_rows_by_default()
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

  lu.assertEvalToTrue(text:find("total=2 killed=2 survived=0 errors=0", 1, true))
  lu.assertNil(text:find("first noisy killed detail", 1, true))
  lu.assertNil(text:find("second noisy killed detail", 1, true))
end

function TestMutatorReportSkipped:test_keeps_killed_mutation_rows_when_verbose_is_requested()
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

  lu.assertEvalToTrue(text:find("verbose killed detail", 1, true))
end

function TestMutatorReportSkipped:test_preserves_survived_diagnostics_without_verbose()
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

  lu.assertEvalToTrue(text:find("important survivor", 1, true))
  lu.assertEvalToTrue(text:find("survivor error", 1, true))
  lu.assertEvalToTrue(text:find("runner output", 1, true))
end

function TestMutatorReportSkipped:test_omits_skippedscenarios_and_skippedmutations_when_no_skips_occurred()
  local report = { summary = _summary(), results = {} }
  local decoded = json.decode(mutator.format_json_report(report))
  lu.assertNil(decoded.summary.SkippedScenarios)
  lu.assertNil(decoded.summary.SkippedMutations)
end

function TestMutatorReportSkipped:test_includes_skippedscenarios_and_skippedmutations_when_skips_are_present()
  local report = {
    summary = _summary({ skipped_scenarios = 2, skipped_mutations = 5 }),
    results = {},
  }
  local decoded = json.decode(mutator.format_json_report(report))
  lu.assertIs(decoded.summary.SkippedScenarios, 2)
  lu.assertIs(decoded.summary.SkippedMutations, 5)
end

function TestMutatorReportSkipped:test_preserves_the_existing_summary_key_casing_alongside_the_new_fields()
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
  lu.assertIs(decoded.summary.Total, 3)
  lu.assertIs(decoded.summary.Killed, 3)
  lu.assertIs(decoded.summary.Survived, 0)
  lu.assertIs(decoded.summary.Errors, 0)
  lu.assertIs(decoded.summary.SkippedScenarios, 1)
  lu.assertIs(decoded.summary.SkippedMutations, 2)
end


return TestMutatorReportSkipped
