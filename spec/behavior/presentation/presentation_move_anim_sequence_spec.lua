local suite = require("suites.presentation.presentation_move_anim_sequence")

describe(suite.name, function()
  for _, case in ipairs(suite.tests) do
    it(case.name, case.run)
  end
end)
