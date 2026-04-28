local config_reset = require("spec.support.config_reset")
local suite = require("suites.runtime.config_reset_isolation")

describe(suite.name, function()
  before_each(config_reset.reset_all)

  for _, case in ipairs(suite.tests) do
    it(case.name, case.run)
  end
end)
