local suite = require("suites.gameplay.items.startup")
local cases = suite.tests or suite
local label = suite.name or "gameplay.items.startup"

describe(label, function()
  for _, case in ipairs(cases) do
    it(case.name, case.run)
  end
end)
