local suite = require("suites.architecture.arch_view_snapshot_tooling_contract")
local cases = suite.tests or {}
describe(suite.name or "arch_view_snapshot_tooling_contract", function()
  for _, case in ipairs(cases) do
    it(case.name, case.run)
  end
end)
