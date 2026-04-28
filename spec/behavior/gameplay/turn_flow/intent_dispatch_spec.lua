local suite = require("suites.gameplay.turn_flow.intent_dispatch")
local cases = suite.tests or suite
local label = suite.name or "gameplay.turn_flow.intent_dispatch"

describe(label, function()
  for _, case in ipairs(cases) do
    it(case.name, case.run)
  end
end)
