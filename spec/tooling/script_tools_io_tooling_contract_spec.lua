if arg then arg[0] = "spec/tooling/script_tools_io_tooling_contract_spec.lua" end
local suite = require("suites.architecture.script_tools_io_tooling_contract")
local cases = suite.tests or {}
describe(suite.name or "script_tools_io_tooling_contract", function()
  for _, case in ipairs(cases) do
    it(case.name, case.run)
  end
end)
