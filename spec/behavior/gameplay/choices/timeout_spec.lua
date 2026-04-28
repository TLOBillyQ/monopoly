local suite = require("suites.gameplay.choices.timeout")
local cases = suite.tests or suite
local label = suite.name or "gameplay.choices.timeout"

describe(label, function()
  for _, case in ipairs(cases) do
    it(case.name, case.run)
  end
end)
