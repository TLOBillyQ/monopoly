local suite = require("test.support.scenario_suites.turn_flow.interrupts")

describe("TestInterrupts", function()
  for _, case in ipairs(suite.tests) do
    it("test_" .. case.name, case.run)
  end
end)
