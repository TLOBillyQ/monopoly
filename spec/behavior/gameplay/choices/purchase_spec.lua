local suite = require("suites.gameplay.choices.purchase")
local cases = suite.tests or suite
local label = suite.name or "gameplay.choices.purchase"

describe(label, function()
  for _, case in ipairs(cases) do
    it(case.name, case.run)
  end
end)
