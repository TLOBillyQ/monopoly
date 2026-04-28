local suite = require("suites.presentation.presentation_action_anim_effect_routes")

describe(suite.name, function()
  for _, case in ipairs(suite.tests) do
    it(case.name, case.run)
  end
end)
