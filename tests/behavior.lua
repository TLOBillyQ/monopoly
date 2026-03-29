local bootstrap = require("tests.bootstrap")
local catalog = require("tests.catalog")
local harness = require("TestHarness")

local M = {}

function M.run(opts)
  bootstrap.install_package_paths()
  local result = harness.run_all(catalog.load_behavior_suites(), {
    capture_logs = true,
  })
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
