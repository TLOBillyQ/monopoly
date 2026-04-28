local suite = require("suites.gameplay.items.passive")
local cases = suite.tests or suite
local label = suite.name or "gameplay.items.passive"

describe(label, function()
  for _, case in ipairs(cases) do
    it(case.name, case.run)
  end
end)
