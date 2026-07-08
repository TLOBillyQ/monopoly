if arg then rawset(arg, 0, "tools/ops/autotest_report/spec/script_tools_contract_spec.lua") end
local suite = require("spec.support.tooling_suites.architecture.script_tools_contract")

describe("script_tools_contract autotest_report", function()
  for _, case in ipairs(suite.cases_for_owner(suite.tests, "autotest_report")) do
    it(case.name, case.run)
  end
  for _, case in ipairs(suite.cases_for_owner(suite.tooling_tests, "autotest_report")) do
    it(case.name, case.run)
  end
end)
