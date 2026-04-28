local suite = require("suites.presentation.presentation_action_anim_overlay_units")

describe(suite.name, function()
  for _, case in ipairs(suite.tests) do
    it(case.name, case.run)
  end
end)
