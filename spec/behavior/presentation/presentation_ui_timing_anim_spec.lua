local suite = require("suites.presentation.presentation_ui_timing_anim")

describe(suite.name, function()
  for _, case in ipairs(suite.tests) do
    it(case.name, case.run)
  end
end)
