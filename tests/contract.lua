local bootstrap = require("tests.bootstrap")
local catalog = require("tests.catalog")
local harness = require("TestHarness")
local timing_summary = require("tests.support.timing_summary")

local M = {}

function M.run()
  bootstrap.install_package_paths()
  local result = harness.run_all(catalog.load_contract_suites(), {
    capture_logs = true,
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
