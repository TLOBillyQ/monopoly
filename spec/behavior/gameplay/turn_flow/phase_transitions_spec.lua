local suite = require("suites.gameplay.turn_flow.phase_transitions")
local cases = suite.tests or suite
local label = suite.name or "gameplay.turn_flow.phase_transitions"

describe(label, function()
  for _, case in ipairs(cases) do
    it(case.name, case.run)
  end
end)
