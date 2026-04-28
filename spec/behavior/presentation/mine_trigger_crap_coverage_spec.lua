local suite = require("suites.presentation.mine_trigger_crap_coverage")

describe(suite.name, function()
  for _, case in ipairs(suite.tests) do
    it(case.name, case.run)
  end
end)
