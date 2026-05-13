if arg then arg[0] = "spec/tooling/scrap4lua_contract_spec.lua" end
local suite = require("spec.support.tooling_suites.architecture.scrap4lua_contract")
local label = suite.name or "architecture.scrap4lua_contract"

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
