local suite = require("suites.presentation.gameplay_t6_characterization")

describe(suite.name, function()
  for _, case in ipairs(suite.tests) do
    it(case.name, case.run)
  end
end)
