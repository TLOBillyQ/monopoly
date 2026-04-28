local suite = require("suites.presentation.presentation_player_colors")

describe(suite.name, function()
  for _, case in ipairs(suite.tests) do
    it(case.name, case.run)
  end
end)
