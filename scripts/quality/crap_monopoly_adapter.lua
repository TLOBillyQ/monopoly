local bootstrap = require("tests.bootstrap")
local catalog = require("tests.catalog")
local harness = require("TestHarness")
local regression_mode = require("tests.support.regression_mode")

bootstrap.install_package_paths()

local adapter = {}

function adapter.resolve_lane_suites(lane, mode)
  if lane == "behavior" then
    return catalog.load_behavior_suites(), regression_mode.resolve_behavior_mode(mode)
  end
  if lane == "contract" then
    return catalog.load_contract_suites(), "dev"
  end
  error("unsupported lane for CRAP coverage: " .. tostring(lane))
end

function adapter.run_all(suites, opts)
  return harness.run_all(suites, opts)
end

return adapter
