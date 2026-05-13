local suite = require("spec.support.gameplay_suites.turn_flow.interrupts")

describe(suite.name, function()
  for _, case in ipairs(suite.tests or suite) do
    it(case.name, case.run)
  end
end)
