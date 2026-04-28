local suite = require("suites.presentation.presentation_market_confirm_flow")

describe(suite.name, function()
  for _, case in ipairs(suite.tests) do
    it(case.name, case.run)
  end
end)
