local suite = require("test.support.tooling_suites.architecture.arch_view_live_tooling_contract")
local cases = suite.tests or {}

TestArchViewLiveToolingContract = {}

for _, case in ipairs(cases) do
  TestArchViewLiveToolingContract["test_" .. case.name] = function(self)
    case.run()
  end
end


return TestArchViewLiveToolingContract
