if arg then rawset(arg, 0, "tools/packages/spec_lane/test/test_script_tools_contract.lua") end
local suite = require("test.support.tooling_suites.architecture.script_tools_contract")

-- 工具链策略契约(owner = tooling_policy):cli 帮助双语、参考工具 rock 不暴露
-- bin 入口。原住 tools/quality/tooling_policy/test/,#317 四分法顶层残留归位
-- 时迁来本包——tooling 车道发现式(tools/**/test/)自动收养,owner 过滤口径不变。

TestScriptToolsContractToolingPolicy = {}
for _, case in ipairs(suite.cases_for_owner(suite.tests, "tooling_policy")) do
  TestScriptToolsContractToolingPolicy["test_" .. case.name] = function(self)
    case.run()
  end
end
for _, case in ipairs(suite.cases_for_owner(suite.tooling_tests, "tooling_policy")) do
  TestScriptToolsContractToolingPolicy["test_" .. case.name] = function(self)
    case.run()
  end
end


return TestScriptToolsContractToolingPolicy
