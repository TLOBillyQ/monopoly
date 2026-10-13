local suite = require("test.support.scenario_suites.turn_flow.intent_dispatch")

describe("TestIntentDispatch", function()
  for _, case in ipairs(suite.tests or suite) do
    it("test_" .. case.name, function()
      case.run()
    end)
  end
end)
