if arg then rawset(arg, 0, "tools/packages/spec_lane/test/test_script_tools_contract.lua") end
local suite = require("test.support.tooling_suites.architecture.script_tools_contract")

-- CLI 双语帮助及参考工具安装清单的公开策略契约。
describe("script tools policy contracts", function()
  for _, cases in ipairs({ suite.tests, suite.tooling_tests }) do
    for _, case in ipairs(suite.cases_for_owner(cases, "tooling_policy")) do
      it(case.name, case.run)
    end
  end
end)
