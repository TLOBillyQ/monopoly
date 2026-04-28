local suite = require("suites.architecture.busted_infra_tooling")
local cases = suite.tests or {}
describe(suite.name or "busted_infra_tooling", function()
  for _, case in ipairs(cases) do
    it(case.name, case.run)
  end
end)
