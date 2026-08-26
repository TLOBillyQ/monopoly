if arg then rawset(arg, 0, "tools/packages/ops/test/test_script_tools_contract.lua") end
local suite = require("test.support.tooling_suites.architecture.script_tools_contract")

TestScriptToolsContractDeploy = {}

for _, case in ipairs(suite.cases_for_owner(suite.tests, "deploy")) do
  TestScriptToolsContractDeploy["test_" .. case.name] = function(self)
    case.run()
  end
end
for _, case in ipairs(suite.cases_for_owner(suite.tooling_tests, "deploy")) do
  TestScriptToolsContractDeploy["test_" .. case.name] = function(self)
    case.run()
  end
end


return TestScriptToolsContractDeploy
