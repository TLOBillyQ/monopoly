local suite = require("suites.gameplay.runtime.context")
local cases = suite.tests or suite
local label = suite.name or "gameplay.runtime.context"

describe(label, function()
  for _, case in ipairs(cases) do
    it(case.name, case.run)
  end
end)
