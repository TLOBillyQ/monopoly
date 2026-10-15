---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/verify/test/test_verify_full.lua") end
require("test.bootstrap").install_package_paths()

local check = require("luassert")
local verify_full = require("packages.verify.main")

local function _count_lines(text)
  local count = 0
  for _ in (tostring(text or "") .. "\n"):gmatch("[^\n]*\n") do
    count = count + 1
  end
  return count - 1
end

local function _all_pass_results()
  return {
    results = {
      { label = "contract", ok = true, elapsed = 5, output = "ok 1\nok 2\n1..2\n" },
      { label = "guards", ok = true, elapsed = 3, output = "ok 1\n1..1\n" },
      { label = "encoding", ok = true, elapsed = 1, output = "encoding ok\n" },
    },
    skipped = {},
    total_elapsed = 10,
  }
end

local function _one_fail_results()
  return {
    results = {
      { label = "contract", ok = true, elapsed = 5, output = "ok 1\n1..1\n" },
      {
        label = "guards",
        ok = false,
        elapsed = 4,
        output = "ok 1\nnot ok 2 - failing: guard check\n# Failure message: boom\n1..2\n",
      },
    },
    skipped = {},
    total_elapsed = 9,
  }
end

-- Compact output contracts.

local function
happy_path_emits_at_most_3_lines()
  local input = _all_pass_results()
  local out = verify_full.build_output(input)
  local lines = _count_lines(out.stdout)
  check.is_true(lines <= 3, "expected <= 3 lines on happy path, got " .. lines .. ":\n" .. out.stdout)
  check.equal(0, out.exit_code)
end

local function
happy_path_includes_aggregate_summary_with_passed_failed_skipped_counts()
  local input = _all_pass_results()
  local out = verify_full.build_output(input)
  check.truthy(out.stdout:find("passed=3", 1, true), "summary should report passed=3: " .. out.stdout)
  check.truthy(out.stdout:find("failed=0", 1, true))
  check.truthy(out.stdout:find("skipped=0", 1, true))
  check.truthy(out.stdout:find("PASS", 1, true))
end

local function
happy_path_suppresses_per_lane_stdout()
  local input = _all_pass_results()
  local out = verify_full.build_output(input)
  check.is_nil(out.stdout:find("ok 1", 1, true), "lane stdout should be suppressed on success")
  check.is_nil(out.stdout:find("encoding ok", 1, true), "lane stdout should be suppressed on success")
end

local function
failure_path_emits_failing_lane_stdout_verbatim()
  local input = _one_fail_results()
  local out = verify_full.build_output(input)
  check.equal(1, out.exit_code)
  check.truthy(out.stdout:find("not ok 2 %- failing: guard check"),
    "failing lane stdout must be preserved: " .. out.stdout)
  check.truthy(out.stdout:find("Failure message: boom", 1, true),
    "failing diagnostic must be preserved")
end

local function
failure_path_does_not_include_passing_lane_stdout()
  local input = _one_fail_results()
  local out = verify_full.build_output(input)
  check.is_nil(out.stdout:find("ok 1\n1..1", 1, true),
    "passing lane stdout should still be suppressed on failure")
end

local function
skipped_lanes_appear_in_summary()
  local input = _all_pass_results()
  input.skipped = { "lint-src", "lint-test" }
  local out = verify_full.build_output(input)
  check.truthy(out.stdout:find("skipped=2", 1, true))
  check.truthy(out.stdout:find("skipped: lint-src, lint-test", 1, true))
end

-- #112:退 3 的车道是「不可用」(工具自举网络失败),既不算通过也不混进 failed;
-- 摘要单列 unavailable,整体退出码非 0。
local function _unavailable_lane()
  return { label = "lint-src", ok = false, exit_code = 3, elapsed = 2,
    output = "[lint] status=unavailable tool=luacheck step=install\n" }
end

local function
unavailable_lane_is_reported_and_never_passes()
  local input = _all_pass_results()
  input.results[#input.results + 1] = _unavailable_lane()
  local out = verify_full.build_output(input)
  check.equal(3, out.exit_code)
  check.truthy(out.stdout:find("[verify] UNAVAILABLE lint-src", 1, true), out.stdout)
  check.truthy(out.stdout:find("status=unavailable tool=luacheck", 1, true), out.stdout)
  check.truthy(out.stdout:find("[verify] UNAVAILABLE  passed=3 failed=0 unavailable=1", 1, true), out.stdout)
  check.is_nil(out.stdout:find("[verify] PASS", 1, true), out.stdout)
end

local function
real_failure_outranks_unavailable_lane()
  local input = _one_fail_results()
  input.results[#input.results + 1] = _unavailable_lane()
  local out = verify_full.build_output(input)
  check.equal(1, out.exit_code)
  check.truthy(out.stdout:find("[verify] FAIL  passed=1 failed=1 unavailable=1", 1, true), out.stdout)
end

-- 串行 verify 的 run_step 必须保住子进程退出码 3,否则不可用会被折成普通失败。
local function
serial_step_exit_3_surfaces_as_unavailable()
  local lua54 = require("foundation.lua54").lua54_bin()
  local step = require("packages.verify.runner").run_step("lint-src", { lua54, "-e", "os.exit(3)" })
  local out = verify_full.build_output({ results = { step }, skipped = {}, total_elapsed = 1 })
  check.is_false(step.ok)
  check.equal(3, out.exit_code)
  check.truthy(out.stdout:find("unavailable=1", 1, true), out.stdout)
end

-- Verbose output contracts.

local function
verbose_preserves_all_lane_stdout_on_success()
  local input = _all_pass_results()
  input.verbose = true
  local out = verify_full.build_output(input)
  check.truthy(out.stdout:find("encoding ok", 1, true), "verbose must include lane stdout")
  check.truthy(out.stdout:find("ok 1", 1, true), "verbose must include lane stdout")
end

local function
verbose_preserves_all_lane_stdout_on_failure()
  local input = _one_fail_results()
  input.verbose = true
  local out = verify_full.build_output(input)
  check.truthy(out.stdout:find("not ok 2", 1, true))
  check.truthy(out.stdout:find("ok 1\n1..1", 1, true),
    "verbose must include passing lane stdout too: " .. out.stdout)
end

local function
verbose_includes_per_step_pass_fail_trace_lines()
  local input = _all_pass_results()
  input.verbose = true
  local out = verify_full.build_output(input)
  check.truthy(out.stdout:find("PASS contract", 1, true),
    "verbose must include per-step trace: " .. out.stdout)
end
-- Slim lane plan contracts.

-- #449: slim 计划里 lint 拆成 lint-src / lint-test / lint-tools 三条子车道,
-- 不再有统一的 "lint" 车道。
local function
slim_plan_splits_lint_into_three_directory_lanes()
  local plan = verify_full._resolve_lanes({
    env = { lua54_bin = "lua5.4" },
  })
  local labels = {}
  for _, lane in ipairs(plan.lanes) do
    labels[lane.label] = lane.cmd
  end
  check.is_not_nil(labels["lint-src"], "expect lint-src lane")
  check.is_not_nil(labels["lint-test"], "expect lint-test lane")
  check.is_not_nil(labels["lint-tools"], "expect lint-tools lane")
  check.is_nil(labels["lint"], "unified lint lane should be gone")
  check.truthy(labels["lint-test"]:find("lint/runner.lua", 1, true) ~= nil,
    "lint-test lane must invoke lint runner: " .. labels["lint-test"])
  -- lint 车道走钉定 5.4 解释器 + 原生 argv 定界(^"),不再是 PATH 上的 luacheck。
  check.truthy(labels["lint-test"]:find('^"test^"', 1, true) ~= nil,
    "lint-test lane must target test dir: " .. labels["lint-test"])
end

-- luacheck 不再由 PATH 探测供给(装进项目 tree 后经钉定 5.4 跑),所以
-- "全局没有 luacheck" 不再是跳过 lint 车道的理由——三条 lint 车道恒在。
local function
missing_global_luacheck_keeps_project_install_lanes()
  local plan = verify_full._resolve_lanes({
    env = { lua54_bin = "lua5.4" },
  })
  local skipped = {}
  for _, label in ipairs(plan.skipped) do
    skipped[label] = true
  end
  check.is_nil(skipped["lint-src"])
  check.is_nil(skipped["lint-test"])
  check.is_nil(skipped["lint-tools"])
end

-- #94:旧外部架构工具 / CRAP / 覆盖率车道退场;层边界门禁住 guards 车道,
-- CRAP 与变异走显式 `uml crap|mutate`。slim 计划恰好七条车道。
local function
slim_plan_has_exactly_the_retained_lanes()
  local plan = verify_full._resolve_lanes({
    env = { lua54_bin = "lua5.4" },
  })
  local labels = {}
  for _, lane in ipairs(plan.lanes) do
    labels[#labels + 1] = lane.label
  end
  check.same({ "contract", "guards", "behavior", "lint-src", "lint-test", "lint-tools", "encoding" }, labels)
  check.same({}, plan.skipped)
end

describe("verify public output and lane plan", function()
  it("happy_path_emits_at_most_3_lines", happy_path_emits_at_most_3_lines)
  it("happy_path_includes_aggregate_summary_with_passed_failed_skipped_counts", happy_path_includes_aggregate_summary_with_passed_failed_skipped_counts)
  it("happy_path_suppresses_per_lane_stdout", happy_path_suppresses_per_lane_stdout)
  it("failure_path_emits_failing_lane_stdout_verbatim", failure_path_emits_failing_lane_stdout_verbatim)
  it("failure_path_does_not_include_passing_lane_stdout", failure_path_does_not_include_passing_lane_stdout)
  it("skipped_lanes_appear_in_summary", skipped_lanes_appear_in_summary)
  it("unavailable_lane_is_reported_and_never_passes", unavailable_lane_is_reported_and_never_passes)
  it("real_failure_outranks_unavailable_lane", real_failure_outranks_unavailable_lane)
  it("serial_step_exit_3_surfaces_as_unavailable", serial_step_exit_3_surfaces_as_unavailable)
  it("verbose_preserves_all_lane_stdout_on_success", verbose_preserves_all_lane_stdout_on_success)
  it("verbose_preserves_all_lane_stdout_on_failure", verbose_preserves_all_lane_stdout_on_failure)
  it("verbose_includes_per_step_pass_fail_trace_lines", verbose_includes_per_step_pass_fail_trace_lines)
  it("slim_plan_splits_lint_into_three_directory_lanes", slim_plan_splits_lint_into_three_directory_lanes)
  it("missing_global_luacheck_keeps_project_install_lanes", missing_global_luacheck_keeps_project_install_lanes)
  it("slim_plan_has_exactly_the_retained_lanes", slim_plan_has_exactly_the_retained_lanes)
end)
