local suite = require("spec.support.scenario_suites.turn_flow.intent_dispatch")

describe(suite.name, function()
  for _, case in ipairs(suite.tests or suite) do
    it(case.name, case.run)
  end
end)
