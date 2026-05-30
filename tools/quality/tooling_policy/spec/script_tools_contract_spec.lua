if arg then rawset(arg, 0, "tools/quality/tooling_policy/spec/script_tools_contract_spec.lua") end
local suite = require("spec.support.tooling_suites.architecture.script_tools_contract")

describe("script_tools_contract tooling_policy", function()
  for _, case in ipairs(suite.cases_for_owner(suite.tests, "tooling_policy")) do
    it(case.name, case.run)
  end
  for _, case in ipairs(suite.cases_for_owner(suite.tooling_tests, "tooling_policy")) do
    it(case.name, case.run)
  end
end)
