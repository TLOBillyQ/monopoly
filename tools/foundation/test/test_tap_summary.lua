---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/foundation/test/test_tap_summary.lua") end
require("test.bootstrap").install_package_paths()

local check = require("luassert")
local tap_summary = require("foundation.tap_summary")

describe("tap summary", function()

it("counts numbered ok lines and reports the passing total", function()
  local text, passed, failed = tap_summary.compress("ok 1 - a\nok 2 - b\n1..2\n")
  check.equal(2, passed)
  check.equal(0, failed)
  check.equal("2 passed\n", text)
end)

it("counts numbered not ok lines and keeps them in the summary", function()
  local text, passed, failed = tap_summary.compress("ok 1 - a\nnot ok 2 - b\n1..2\n")
  check.equal(1, passed)
  check.equal(1, failed)
  check.truthy(text:find("not ok 2 - b", 1, true) ~= nil)
  check.truthy(text:find("1 passed, 1 failed", 1, true) ~= nil)
end)

-- 工单 #135 的回归护栏。runner 在 spec 加载失败时发的是**无编号**的
-- `not ok - failed to load ...`。旧实现只认 `^not ok%s+%d`,这行会掉进
-- 「保留」分支而 failed 不计数 → failed == 0 提前 return "N passed",
-- kept 被整个丢弃 → 摘要显示全绿,失败行凭空消失。
it("counts an unnumbered not ok line so a load failure cannot read as all green", function()
  local raw = "ok 1 - a\nnot ok - failed to load 'spec.behavior.broken'\n"
  local text, passed, failed = tap_summary.compress(raw)
  check.equal(1, passed)
  check.equal(1, failed, "an unnumbered not ok must count as a failure")
  check.truthy(
    text:find("failed to load", 1, true) ~= nil,
    "the load-failure line must survive into the summary"
  )
  check.falsy(
    text:match("^1 passed\n$") ~= nil,
    "a load failure must never compress to a bare passing summary"
  )
end)

-- 前沿匹配的反向护栏:`not okay` 是散文,不是 TAP 结果行,不得被计成失败。
-- (无失败时 compress 会丢弃保留行,所以这里只断言计数,不断言文本。)
it("does not mistake prose starting with not ok for a tap failure line", function()
  local _, passed, failed = tap_summary.compress("not okay, this is prose\n")
  check.equal(0, passed)
  check.equal(0, failed, "prose must not be counted as a TAP failure")
end)

it("drops the tap plan line from the kept output", function()
  local _, passed, failed = tap_summary.compress("1..0\n")
  check.equal(0, passed)
  check.equal(0, failed)
end)

-- #361 P5:compress_tap 原「nil 输入 → 0 passed」回归钉随 spec_lane 删例退场,
-- 行为面归位到真源层:压缩器对空输出必须报 0 passed 而不是崩溃。
it("treats nil input as zero passes", function()
  local text, passed, failed = tap_summary.compress(nil)
  check.equal(0, passed)
  check.equal(0, failed)
  check.equal("0 passed\n", text)
end)
-- #130:权威计数(runner 进程内 COUNTS)优先于 ok 行数。TAP 行被 stdout/stderr
-- 合流切开时,摘要仍要报真实通过数;返回的 TAP 计数保持不变,供调用方交叉核对。
it("prefers authoritative counts for the summary while returning the tap tally", function()
  local text, passed, failed = tap_summary.compress("ok 1 - a\nk 2 - b\n1..2\n",
    { passed = 2, failed = 0 })
  check.equal("2 passed\n", text)
  check.equal(1, passed, "tap tally still reports the corrupted line as missing")
  check.equal(0, failed)
end)

it("keeps the verbose shape when authoritative counts carry a failure", function()
  local text, passed = tap_summary.compress("ok 1 - a\n1..2\n", { passed = 1, failed = 1 })
  check.equal(1, passed)
  check.truthy(text:find("1 passed, 1 failed", 1, true) ~= nil)
  check.falsy(text == "1 passed\n")
end)

-- 失败判定是两侧并集:即便 COUNTS 全绿,TAP 的 not ok 也不能被过滤成假绿。
it("keeps a tap failure when authoritative counts claim all green", function()
  local text, passed, failed = tap_summary.compress("ok 1 - a\nnot ok 2 - b\n1..2\n",
    { passed = 2, failed = 0 })
  check.equal(1, passed)
  check.equal(1, failed)
  check.truthy(text:find("not ok 2 - b", 1, true) ~= nil)
  check.truthy(text:find("2 passed, 1 failed", 1, true) ~= nil)
end)


end)
