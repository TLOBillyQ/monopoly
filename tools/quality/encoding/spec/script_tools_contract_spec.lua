if arg then rawset(arg, 0, "tools/quality/encoding/spec/script_tools_contract_spec.lua") end
local suite = require("spec.support.tooling_suites.architecture.script_tools_contract")

describe("script_tools_contract encoding", function()
  for _, case in ipairs(suite.cases_for_owner(suite.tests, "encoding")) do
    it(case.name, case.run)
  end
  for _, case in ipairs(suite.cases_for_owner(suite.tooling_tests, "encoding")) do
    it(case.name, case.run)
  end
end)
