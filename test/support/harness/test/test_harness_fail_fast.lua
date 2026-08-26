---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "test/support/harness/test/test_harness_fail_fast.lua") end
require("test.bootstrap").install_package_paths()

local lu = require("luaunit")
local harness = require("test.support.harness")

local function quiet_opts(extra)
  local opts = {
    quiet = true,
    capture_logs = false,
    raise_on_failure = false,
    reporter = {
      case_pass = function() end,
      case_fail = function() end,
      finish = function() end,
    },
  }
  for key, value in pairs(extra or {}) do
    opts[key] = value
  end
  return opts
end

-- Two suites; the first case raises. `calls` records execution order so we can
-- assert exactly which cases ran.
local function failing_suites(calls)
  return {
    {
      name = "suite_a",
      module_name = "suite_a",
      tests = {
        { name = "c1", run = function() calls[#calls + 1] = "c1"; error("boom") end },
        { name = "c2", run = function() calls[#calls + 1] = "c2" end },
      },
    },
    {
      name = "suite_b",
      module_name = "suite_b",
      tests = {
        { name = "c3", run = function() calls[#calls + 1] = "c3" end },
      },
    },
  }
end

-- 原生 LuaUnit 迁移:单个 describe 拍平成一个 TestHarnessFailFast 类,
-- 用例数与改写前一一对应(3 例)。

TestHarnessFailFast = {}

function TestHarnessFailFast:test_stops_at_first_failing_case_across_suites_when_stop_on_first_failure_is_set()
  local calls = {}
  local result = harness.run_all(failing_suites(calls), quiet_opts({ stop_on_first_failure = true }))
  lu.assertTrue(result.failed)
  lu.assertEquals(calls, { "c1" })
end

function TestHarnessFailFast:test_runs_every_case_after_a_failure_by_default_no_early_stop()
  local calls = {}
  local result = harness.run_all(failing_suites(calls), quiet_opts())
  lu.assertTrue(result.failed)
  lu.assertEquals(calls, { "c1", "c2", "c3" })
end

function TestHarnessFailFast:test_runs_every_case_when_all_pass_even_with_fail_fast_enabled()
  local calls = {}
  local suites = {
    {
      name = "s",
      module_name = "s",
      tests = {
        { name = "p1", run = function() calls[#calls + 1] = "p1" end },
        { name = "p2", run = function() calls[#calls + 1] = "p2" end },
      },
    },
  }
  local result = harness.run_all(suites, quiet_opts({ stop_on_first_failure = true }))
  lu.assertFalse(result.failed)
  lu.assertEquals(calls, { "p1", "p2" })
end


return TestHarnessFailFast
