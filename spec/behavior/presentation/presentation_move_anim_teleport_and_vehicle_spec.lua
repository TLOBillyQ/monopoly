local suite = require("suites.presentation.presentation_move_anim_teleport_and_vehicle")

describe(suite.name, function()
  for _, case in ipairs(suite.tests) do
    it(case.name, case.run)
  end
end)
