if arg then arg[0] = "spec/tooling/mutate4lua_tooling_contract_spec.lua" end
local suite = require("suites.architecture.mutate4lua_tooling_contract")
local cases = suite.tests or {}
describe(suite.name or "mutate4lua_tooling_contract", function()
  for _, case in ipairs(cases) do
    it(case.name, case.run)
  end
end)
