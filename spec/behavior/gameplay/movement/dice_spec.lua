local suite = require("suites.gameplay.movement.dice")
local cases = suite.tests or suite
local label = suite.name or "gameplay.movement.dice"

describe(label, function()
  for _, case in ipairs(cases) do
    it(case.name, case.run)
  end
end)
