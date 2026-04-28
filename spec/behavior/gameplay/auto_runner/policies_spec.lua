local suite = require("suites.gameplay.auto_runner.policies")
local cases = suite.tests or suite
local label = suite.name or "gameplay.auto_runner.policies"

describe(label, function()
  for _, case in ipairs(cases) do
    it(case.name, case.run)
  end
end)
