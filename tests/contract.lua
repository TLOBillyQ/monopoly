local bootstrap = require("tests.bootstrap")
local catalog = require("tests.catalog")
local harness = require("TestHarness")

local M = {}

function M.run()
  bootstrap.install_package_paths()
  print("[contract] mode=dev")
  return harness.run_all(catalog.load_contract_suites(), {
    mode = "dev",
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
