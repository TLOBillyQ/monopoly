local autotest_results = require("src.app.testing.autotest_results")

-- 行格式是与 tools/ops/autotest_report.ps1 的解析契约；这里钉住格式。
describe("autotest_results", function()
  it("begin_line_carries_selector_and_total", function()
    assert.equals("[autotest] begin selector=all total=35",
      autotest_results.begin_line("all", 35))
  end)

  it("profile_line_formats_pass_entry_as_key_value_pairs", function()
    local line = autotest_results.profile_line({
      profile = "solo_missile",
      index = 9,
      result = "pass",
      reason = "expect_met",
      turns = 2,
      seconds = 1.74,
      warns = 0,
    })
    assert.equals(
      "[autotest] profile=solo_missile index=9 result=pass reason=expect_met turns=2 seconds=1.7 warns=0",
      line)
  end)

  it("profile_line_appends_sanitized_message_for_failures", function()
    local line = autotest_results.profile_line({
      profile = "solo_mine",
      index = 3,
      result = "fail",
      reason = "tick_error",
      turns = 4,
      seconds = 2,
      warns = 1,
      message = 'boom "quoted"\nsecond line',
    })
    assert.equals(
      "[autotest] profile=solo_mine index=3 result=fail reason=tick_error turns=4 seconds=2.0 warns=1"
        .. " message=\"boom 'quoted' second line\"",
      line)
  end)

  it("recorder_totals_aggregate_pass_fail_and_seconds", function()
    local recorder = autotest_results.new_recorder()
    recorder:record({ profile = "a", index = 1, result = "pass", reason = "budget_turns", seconds = 1.5 })
    recorder:record({ profile = "b", index = 2, result = "fail", reason = "tick_error", seconds = 2 })
    recorder:record({ profile = "c", index = 3, result = "pass", reason = "expect_met", seconds = 0.5 })

    local totals = recorder:totals()
    assert.equals(3, totals.total)
    assert.equals(2, totals.pass)
    assert.equals(1, totals.fail)
    assert.equals(4, totals.seconds)
    assert.equals("[autotest] summary total=3 pass=2 fail=1 seconds=4.0",
      autotest_results.summary_line(recorder))
  end)

  it("recorder_rejects_invalid_result_values", function()
    local recorder = autotest_results.new_recorder()
    assert(not pcall(function()
      recorder:record({ profile = "a", result = "skip" })
    end), "unknown result value must raise")
  end)

  it("error_line_flattens_newlines_and_quotes", function()
    assert.equals('[autotest] error message="bad \'selector\' here"',
      autotest_results.error_line('bad "selector"\nhere'))
  end)
end)
