local bootstrap = require("tests.bootstrap")
local catalog = require("tests.catalog")
local harness = require("TestHarness")
local regression_mode = require("tests.support.regression_mode")

local M = {}

function M.run(opts)
  bootstrap.install_package_paths()
  local mode = regression_mode.resolve_behavior_mode(opts and opts.mode)
  print("[behavior] mode=" .. mode)
  return harness.run_all(catalog.load_behavior_suites(), {
    mode = mode,
    capture_logs = true,
  })
end

function M.main()
  M.run()
end

if ... == nil then
  M.main()
else
  return M
end
