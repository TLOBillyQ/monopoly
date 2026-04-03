local bootstrap = require("tests.bootstrap")
local catalog = require("tests.catalog")
local harness = require("TestHarness")
local timing_summary = require("tests.support.timing_summary")

local M = {}

local function _quiet_reporter()
  return {
    case_pass = function() end,
    case_fail = function() end,
    finish = function() end,
  }
end

function M.run()
  bootstrap.install_package_paths()
  local result = harness.run_all(catalog.load_contract_suites(), {
    capture_logs = true,
    reporter = _quiet_reporter(),
    summary_label = "contract",
  })
  timing_summary.print_lane_summary("contract", result)
  return result
end

function M.main()
  M.run()
end

if ... == nil then
  M.main()
else
  return M
end
