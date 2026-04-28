local suite = require("suites.gameplay.ui_sync.feedback")
local cases = suite.tests or suite
local label = suite.name or "gameplay.ui_sync.feedback"

describe(label, function()
  for _, case in ipairs(cases) do
    it(case.name, case.run)
  end
end)
