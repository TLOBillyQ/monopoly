if arg then rawset(arg, 0, "tools/packages/mutate/test/test_script_tools_contract.lua") end
local suite = require("test.support.tooling_suites.architecture.script_tools_contract")

describe("script tools mutate contracts", function()
  for _, cases in ipairs({ suite.tests, suite.tooling_tests }) do
    for _, case in ipairs(suite.cases_for_owner(cases, "mutate")) do
      it(case.name, case.run)
    end
  end
end)
