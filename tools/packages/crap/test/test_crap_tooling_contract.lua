if arg then rawset(arg, 0, "tools/packages/crap/test/test_crap_tooling_contract.lua") end
local suite = require("test.support.tooling_suites.architecture.crap_tooling_contract")
local cases = suite.tests or {}

TestCrapToolingContract = {}

for _, case in ipairs(cases) do
  TestCrapToolingContract["test_" .. case.name] = function(self)
    case.run()
  end
end


return TestCrapToolingContract
