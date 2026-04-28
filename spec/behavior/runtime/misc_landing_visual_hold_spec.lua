local cases = require("suites.runtime.misc_landing_visual_hold")

describe("runtime.misc_landing_visual_hold", function()
  for _, case in ipairs(cases) do
    it(case.name, case.run)
  end
end)
