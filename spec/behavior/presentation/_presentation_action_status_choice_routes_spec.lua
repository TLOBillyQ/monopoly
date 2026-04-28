local suite = require("suites.presentation._presentation_action_status_choice_routes")

describe(suite.name, function()
  for _, case in ipairs(suite.tests) do
    it(case.name, case.run)
  end
end)
