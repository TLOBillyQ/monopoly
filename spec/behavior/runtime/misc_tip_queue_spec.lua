local cases = require("suites.runtime.misc_tip_queue")

describe("runtime.misc_tip_queue", function()
  for _, case in ipairs(cases) do
    it(case.name, case.run)
  end
end)
