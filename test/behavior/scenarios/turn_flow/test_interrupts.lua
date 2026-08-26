local suite = require("test.support.scenario_suites.turn_flow.interrupts")

TestInterrupts = {}

for _, case in ipairs(suite.tests or suite) do
  TestInterrupts["test_" .. case.name] = function(self)
    case.run()
  end
end


return TestInterrupts
