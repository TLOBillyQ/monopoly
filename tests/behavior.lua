local bootstrap = require("tests.bootstrap")
local catalog = require("tests.catalog")
local harness = require("TestHarness")
local regression_mode = require("tests.support.regression_mode")
local timing_summary = require("tests.support.timing_summary")

local M = {}

function M.run(opts)
  bootstrap.install_package_paths()
  local mode = regression_mode.resolve_behavior_mode(opts and opts.mode)
  print("[behavior] mode=" .. mode)
  local result = harness.run_all(catalog.load_behavior_suites(), {
    mode = mode,
    capture_logs = true,
  })
  timing_summary.print_lane_summary("behavior", result)
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
