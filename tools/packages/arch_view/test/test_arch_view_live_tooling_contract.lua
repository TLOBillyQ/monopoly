require("test.bootstrap").install_package_paths()
local suite = require("test.support.tooling_suites.architecture.arch_view_live_tooling_contract")

describe("arch view live tooling contracts", function()
  for _, case in ipairs(suite.tests) do
    it(case.name, case.run)
  end
end)
