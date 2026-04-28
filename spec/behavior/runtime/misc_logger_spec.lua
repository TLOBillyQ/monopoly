local cases = require("suites.runtime.misc_logger")

describe("runtime.misc_logger", function()
  for _, case in ipairs(cases) do
    it(case.name, case.run)
  end
end)
