---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/packages/verify/test/test_verify_full.lua") end
require("test.bootstrap").install_package_paths()

local lu = require("luaunit")
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
      { label = "arch", ok = true, elapsed = 1, output = "arch ok\n" },
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

TestVerifyFullBuildOutput = {}

function TestVerifyFullBuildOutput:test_happy_path_emits_at_most_3_lines()
  local input = _all_pass_results()
  local out = verify_full.build_output(input)
  local lines = _count_lines(out.stdout)
  lu.assertTrue(lines <= 3, "expected <= 3 lines on happy path, got " .. lines .. ":\n" .. out.stdout)
  lu.assertIs(out.exit_code, 0)
end

function TestVerifyFullBuildOutput:test_happy_path_includes_aggregate_summary_with_passed_failed_skipped_counts()
  local input = _all_pass_results()
  local out = verify_full.build_output(input)
  lu.assertEvalToTrue(out.stdout:find("passed=3", 1, true), "summary should report passed=3: " .. out.stdout)
  lu.assertEvalToTrue(out.stdout:find("failed=0", 1, true))
  lu.assertEvalToTrue(out.stdout:find("skipped=0", 1, true))
  lu.assertEvalToTrue(out.stdout:find("PASS", 1, true))
end

function TestVerifyFullBuildOutput:test_happy_path_suppresses_per_lane_stdout()
  local input = _all_pass_results()
  local out = verify_full.build_output(input)
  lu.assertNil(out.stdout:find("ok 1", 1, true), "lane stdout should be suppressed on success")
  lu.assertNil(out.stdout:find("arch ok", 1, true), "lane stdout should be suppressed on success")
end

function TestVerifyFullBuildOutput:test_failure_path_emits_failing_lane_stdout_verbatim()
  local input = _one_fail_results()
  local out = verify_full.build_output(input)
  lu.assertIs(out.exit_code, 1)
  lu.assertEvalToTrue(out.stdout:find("not ok 2 %- failing: guard check"),
    "failing lane stdout must be preserved: " .. out.stdout)
  lu.assertEvalToTrue(out.stdout:find("Failure message: boom", 1, true),
    "failing diagnostic must be preserved")
end

function TestVerifyFullBuildOutput:test_failure_path_does_not_include_passing_lane_stdout()
  local input = _one_fail_results()
  local out = verify_full.build_output(input)
  lu.assertNil(out.stdout:find("ok 1\n1..1", 1, true),
    "passing lane stdout should still be suppressed on failure")
end

function TestVerifyFullBuildOutput:test_skipped_lanes_appear_in_summary()
  local input = _all_pass_results()
  input.skipped = { "lint", "coverage" }
  local out = verify_full.build_output(input)
  lu.assertEvalToTrue(out.stdout:find("skipped=2", 1, true))
  lu.assertEvalToTrue(out.stdout:find("skipped: lint, coverage", 1, true))
end

TestVerifyFullBuildOutputVerbose = {}

function TestVerifyFullBuildOutputVerbose:test_verbose_preserves_all_lane_stdout_on_success()
  local input = _all_pass_results()
  input.verbose = true
  local out = verify_full.build_output(input)
  lu.assertEvalToTrue(out.stdout:find("arch ok", 1, true), "verbose must include lane stdout")
  lu.assertEvalToTrue(out.stdout:find("ok 1", 1, true), "verbose must include lane stdout")
end

function TestVerifyFullBuildOutputVerbose:test_verbose_preserves_all_lane_stdout_on_failure()
  local input = _one_fail_results()
  input.verbose = true
  local out = verify_full.build_output(input)
  lu.assertEvalToTrue(out.stdout:find("not ok 2", 1, true))
  lu.assertEvalToTrue(out.stdout:find("ok 1\n1..1", 1, true),
    "verbose must include passing lane stdout too: " .. out.stdout)
end

function TestVerifyFullBuildOutputVerbose:test_verbose_includes_per_step_pass_fail_trace_lines()
  local input = _all_pass_results()
  input.verbose = true
  local out = verify_full.build_output(input)
  lu.assertEvalToTrue(out.stdout:find("PASS contract", 1, true),
    "verbose must include per-step trace: " .. out.stdout)
end
TestVerifyLanePlan = {}

-- #449: slim 计划里 lint 拆成 lint-src / lint-test / lint-tools 三条子车道,
-- 不再有统一的 "lint" 车道。
function TestVerifyLanePlan:test_slim_plan_splits_lint_into_three_directory_lanes()
  local plan = verify_full._resolve_lanes({
    env = { lua54_bin = "lua5.4", luacheck_available = true },
  })
  local labels = {}
  for _, lane in ipairs(plan.lanes) do
    labels[lane.label] = lane.cmd
  end
  lu.assertNotNil(labels["lint-src"], "expect lint-src lane")
  lu.assertNotNil(labels["lint-test"], "expect lint-test lane")
  lu.assertNotNil(labels["lint-tools"], "expect lint-tools lane")
  lu.assertNil(labels["lint"], "unified lint lane should be gone")
  lu.assertEvalToTrue(labels["lint-test"]:find("lint/runner.lua", 1, true) ~= nil,
    "lint-test lane must invoke lint runner: " .. labels["lint-test"])
  lu.assertEvalToTrue(labels["lint-test"]:find("'test'", 1, true) ~= nil,
    "lint-test lane must target test dir: " .. labels["lint-test"])
end

function TestVerifyLanePlan:test_missing_luacheck_skips_all_three_lint_lanes()
  local plan = verify_full._resolve_lanes({
    env = { lua54_bin = "lua5.4", luacheck_available = false },
  })
  local skipped = {}
  for _, label in ipairs(plan.skipped) do
    skipped[label] = true
  end
  lu.assertTrue(skipped["lint-src"] == true, "lint-src should be skipped")
  lu.assertTrue(skipped["lint-test"] == true, "lint-test should be skipped")
  lu.assertTrue(skipped["lint-tools"] == true, "lint-tools should be skipped")
end


return TestVerifyFullBuildOutput
