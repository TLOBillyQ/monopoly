local suite = require("suites.runtime.runtime_bootstrap")

describe(suite.name, function()
  for _, case in ipairs(suite.tests) do
    it(case.name, case.run)
  end
end)
