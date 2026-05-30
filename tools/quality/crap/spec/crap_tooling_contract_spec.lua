if arg then rawset(arg, 0, "tools/quality/crap/spec/crap_tooling_contract_spec.lua") end
local suite = require("spec.support.tooling_suites.architecture.crap_tooling_contract")
local cases = suite.tests or {}
describe(suite.name or "crap_tooling_contract", function()
  for _, case in ipairs(cases) do
    it(case.name, case.run)
  end
end)
