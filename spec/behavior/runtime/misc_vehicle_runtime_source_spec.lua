local suite = require("suites.runtime.misc_vehicle_runtime_source")

describe(suite.name, function()
  for _, case in ipairs(suite.tests) do
    it(case.name, case.run)
  end
end)
