local support = require("test.support.shared_support")
local suite = require("test.support.scenario_suites.runtime.context")

describe("TestContext", function()
  after_each(function()
    support.restore_runtime_services()
  end)
  for _, case in ipairs(suite.tests) do
    it("test_" .. case.name, case.run)
  end
end)
