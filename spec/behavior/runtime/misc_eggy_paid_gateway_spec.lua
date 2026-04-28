local cases = require("suites.runtime.misc_eggy_paid_gateway")

describe("runtime.misc_eggy_paid_gateway", function()
  for _, case in ipairs(cases) do
    it(case.name, case.run)
  end
end)
