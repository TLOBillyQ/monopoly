local suite = require("suites.presentation.gameplay_t5_characterization")

describe(suite.name, function()
  for _, case in ipairs(suite.tests) do
    it(case.name, case.run)
  end
end)
