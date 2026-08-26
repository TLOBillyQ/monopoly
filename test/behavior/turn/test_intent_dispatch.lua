local suite = require("test.support.scenario_suites.turn_flow.intent_dispatch")

TestIntentDispatch = {}

for _, case in ipairs(suite.tests or suite) do
  TestIntentDispatch["test_" .. case.name] = function(self)
    case.run()
  end
end


return TestIntentDispatch
