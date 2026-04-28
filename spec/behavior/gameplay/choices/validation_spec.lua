local suite = require("suites.gameplay.choices.validation")
local cases = suite.tests or suite
local label = suite.name or "gameplay.choices.validation"

describe(label, function()
  for _, case in ipairs(cases) do
    it(case.name, case.run)
  end
end)
