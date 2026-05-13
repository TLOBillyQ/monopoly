local suite = require("spec.support.gameplay_suites.ui_sync.prompts")

describe(suite.name, function()
  for _, case in ipairs(suite.tests or suite) do
    it(case.name, case.run)
  end
end)
