if arg then arg[0] = "spec/tooling/script_tools_contract_spec.lua" end
local suite = require("suites.architecture.script_tools_contract")
local label = suite.name or "script_tools_contract"

describe(label, function()
  for _, case in ipairs(suite.tests or {}) do
    it(case.name, case.run)
  end
end)

describe(label .. " (tooling)", function()
  for _, case in ipairs(suite.tooling_tests or {}) do
    it(case.name, case.run)
  end
end)
