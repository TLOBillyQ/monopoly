if arg then arg[0] = "spec/tooling/scrap4lua_tooling_contract_spec.lua" end
local suite = require("spec.support.tooling_suites.architecture.scrap4lua_tooling_contract")
local cases = suite.tests or {}
describe(suite.name or "scrap4lua_tooling_contract", function()
  for _, case in ipairs(cases) do
    it(case.name, case.run)
  end
end)
