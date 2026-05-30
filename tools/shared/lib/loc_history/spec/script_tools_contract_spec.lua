if arg then rawset(arg, 0, "tools/shared/lib/loc_history/spec/script_tools_contract_spec.lua") end
local suite = require("spec.support.tooling_suites.architecture.script_tools_contract")

describe("script_tools_contract loc_history", function()
  for _, case in ipairs(suite.cases_for_owner(suite.tests, "loc_history")) do
    it(case.name, case.run)
  end
  for _, case in ipairs(suite.cases_for_owner(suite.tooling_tests, "loc_history")) do
    it(case.name, case.run)
  end
end)
