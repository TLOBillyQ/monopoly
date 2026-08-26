---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/foundation/test/test_tap_summary.lua") end
require("test.bootstrap").install_package_paths()

local lu = require("luaunit")
local tap_summary = require("foundation.tap_summary")

TestTapSummary = {}

function TestTapSummary:test_counts_numbered_ok_lines_and_reports_the_passing_total()
  local text, passed, failed = tap_summary.compress("ok 1 - a\nok 2 - b\n1..2\n")
  lu.assertIs(passed, 2)
  lu.assertIs(failed, 0)
  lu.assertIs(text, "2 passed\n")
end

function TestTapSummary:test_counts_numbered_not_ok_lines_and_keeps_them_in_the_summary()
  local text, passed, failed = tap_summary.compress("ok 1 - a\nnot ok 2 - b\n1..2\n")
  lu.assertIs(passed, 1)
  lu.assertIs(failed, 1)
  lu.assertEvalToTrue(text:find("not ok 2 - b", 1, true) ~= nil)
  lu.assertEvalToTrue(text:find("1 passed, 1 failed", 1, true) ~= nil)
end

-- 工单 #135 的回归护栏。runner 在 spec 加载失败时发的是**无编号**的
-- `not ok - failed to load ...`。旧实现只认 `^not ok%s+%d`,这行会掉进
-- 「保留」分支而 failed 不计数 → failed == 0 提前 return "N passed",
-- kept 被整个丢弃 → 摘要显示全绿,失败行凭空消失。
function TestTapSummary:test_counts_an_unnumbered_not_ok_line_so_a_load_failure_cannot_read_as_all_green()
  local raw = "ok 1 - a\nnot ok - failed to load 'spec.behavior.broken'\n"
  local text, passed, failed = tap_summary.compress(raw)
  lu.assertIs(passed, 1)
  lu.assertIs(failed, 1, "an unnumbered not ok must count as a failure")
  lu.assertEvalToTrue(
    text:find("failed to load", 1, true) ~= nil,
    "the load-failure line must survive into the summary"
  )
  lu.assertEvalToFalse(
    text:match("^1 passed\n$") ~= nil,
    "a load failure must never compress to a bare passing summary"
  )
end

-- 前沿匹配的反向护栏:`not okay` 是散文,不是 TAP 结果行,不得被计成失败。
-- (无失败时 compress 会丢弃保留行,所以这里只断言计数,不断言文本。)
function TestTapSummary:test_does_not_mistake_prose_starting_with_not_ok_for_a_tap_failure_line()
  local _, passed, failed = tap_summary.compress("not okay, this is prose\n")
  lu.assertIs(passed, 0)
  lu.assertIs(failed, 0, "prose must not be counted as a TAP failure")
end

function TestTapSummary:test_drops_the_tap_plan_line_from_the_kept_output()
  local _, passed, failed = tap_summary.compress("1..0\n")
  lu.assertIs(passed, 0)
  lu.assertIs(failed, 0)
end

-- #361 P5:compress_tap 原「nil 输入 → 0 passed」回归钉随 spec_lane 删例退场,
-- 行为面归位到真源层:压缩器对空输出必须报 0 passed 而不是崩溃。
function TestTapSummary:test_treats_nil_input_as_zero_passes()
  local text, passed, failed = tap_summary.compress(nil)
  lu.assertIs(passed, 0)
  lu.assertIs(failed, 0)
  lu.assertIs(text, "0 passed\n")
end


return TestTapSummary
