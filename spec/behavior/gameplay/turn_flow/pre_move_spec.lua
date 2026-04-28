local suite = require("suites.gameplay.turn_flow.pre_move")
local cases = suite.tests or suite
local label = suite.name or "gameplay.turn_flow.pre_move"

describe(label, function()
  for _, case in ipairs(cases) do
    it(case.name, case.run)
  end
end)
