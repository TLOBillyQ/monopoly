local suite = require("suites.presentation.effect_track_crap_coverage")

describe(suite.name, function()
  for _, case in ipairs(suite.tests) do
    it(case.name, case.run)
  end
end)
