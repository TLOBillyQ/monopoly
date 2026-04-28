local bootstrap = require("spec.bootstrap")
local catalog = require("tools.quality.shared.test_catalog")
local harness = require("tools.quality.shared.test_harness")

bootstrap.install_package_paths()

local adapter = {}

function adapter.resolve_suites(lane)
  if lane == "behavior" then
    return catalog.load_behavior_suites()
  end
  if lane == "contract" then
    return catalog.load_contract_suites()
  end
  error("unsupported lane for CRAP coverage: " .. tostring(lane))
end

function adapter.run(suites, opts)
  return harness.run_all(suites, opts)
end

adapter.debug_api = debug

adapter.resolve_lane_suites = adapter.resolve_suites
adapter.run_all = adapter.run

return adapter
