local config_reset = require("spec.support.config_reset")
local suite = require("suites.domain.direction_coverage")
local cases = suite.tests or suite
local label = suite.name or "domain.direction_coverage"

describe(label, function()
  before_each(function()
    config_reset.reset_all()
  end)
  for _, case in ipairs(cases) do
    it(case.name, case.run)
  end
end)
