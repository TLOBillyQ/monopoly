if arg then rawset(arg, 0, "tools/packages/encoding/test/test_script_tools_contract.lua") end
local suite = require("test.support.tooling_suites.architecture.script_tools_contract")

describe("script tools encoding contracts", function()
  for _, cases in ipairs({ suite.tests, suite.tooling_tests }) do
    for _, case in ipairs(suite.cases_for_owner(cases, "encoding")) do
      it(case.name, case.run)
    end
  end
end)
