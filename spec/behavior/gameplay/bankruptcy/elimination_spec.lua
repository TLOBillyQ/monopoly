local suite = require("suites.gameplay.bankruptcy.elimination")
local cases = suite.tests or suite
local label = suite.name or "gameplay.bankruptcy.elimination"

describe(label, function()
  for _, case in ipairs(cases) do
    it(case.name, case.run)
  end
end)
