local suite = require("suites.gameplay.choices.market")
local cases = suite.tests or suite
local label = suite.name or "gameplay.choices.market"

describe(label, function()
  for _, case in ipairs(cases) do
    it(case.name, case.run)
  end
end)
