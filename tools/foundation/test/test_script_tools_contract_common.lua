if arg then rawset(arg, 0, "tools/foundation/test/test_script_tools_contract_common.lua") end
local suite = require("test.support.tooling_suites.architecture.script_tools_contract")

TestScriptToolsContractFoundation = {}

-- 原 busted 场景循环:for _, case in ipairs(...) do it(case.name, case.run) end
for _, case in ipairs(suite.cases_for_owner(suite.tests, "foundation")) do
  TestScriptToolsContractFoundation["test_" .. case.name] = function(self)
    case.run()
  end
end
for _, case in ipairs(suite.cases_for_owner(suite.tooling_tests, "foundation")) do
  TestScriptToolsContractFoundation["test_" .. case.name] = function(self)
    case.run()
  end
end


return TestScriptToolsContractFoundation
