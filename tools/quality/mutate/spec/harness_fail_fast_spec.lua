---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/quality/mutate/spec/harness_fail_fast_spec.lua") end
require("spec.bootstrap").install_package_paths()

local harness = require("tools.quality.shared.test_harness")

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

describe("test_harness fail-fast", function()
  it("stops at the first failing case across suites when stop_on_first_failure is set", function()
    local calls = {}
    local result = harness.run_all(failing_suites(calls), quiet_opts({ stop_on_first_failure = true }))
    assert.is_true(result.failed)
    assert.are.same({ "c1" }, calls)
  end)

  it("runs every case after a failure by default (no early stop)", function()
    local calls = {}
    local result = harness.run_all(failing_suites(calls), quiet_opts())
    assert.is_true(result.failed)
    assert.are.same({ "c1", "c2", "c3" }, calls)
  end)

  it("runs every case when all pass even with fail-fast enabled", function()
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
    assert.is_false(result.failed)
    assert.are.same({ "p1", "p2" }, calls)
  end)
end)
