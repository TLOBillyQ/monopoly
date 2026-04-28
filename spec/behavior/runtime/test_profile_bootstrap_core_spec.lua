local suite = require("suites.runtime.test_profile_bootstrap_core")

describe(suite.name, function()
  for _, case in ipairs(suite.tests) do
    it(case.name, case.run)
  end
end)
