local suite = require("suites.presentation.presentation_action_anim_tip_text")

describe(suite.name, function()
  for _, case in ipairs(suite.tests) do
    it(case.name, case.run)
  end
end)
