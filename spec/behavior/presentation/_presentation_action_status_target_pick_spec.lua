local suite = require("suites.presentation._presentation_action_status_target_pick")

describe(suite.name, function()
  for _, case in ipairs(suite.tests) do
    it(case.name, case.run)
  end
end)
