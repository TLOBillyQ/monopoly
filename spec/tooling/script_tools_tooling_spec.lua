if arg then arg[0] = "spec/tooling/script_tools_tooling_spec.lua" end
local suite = require("spec.support.tooling_suites.architecture.script_tools_tooling")
local cases = suite.tests or {}
describe(suite.name or "script_tools_tooling", function()
  for _, case in ipairs(cases) do
    it(case.name, case.run)
  end
end)
