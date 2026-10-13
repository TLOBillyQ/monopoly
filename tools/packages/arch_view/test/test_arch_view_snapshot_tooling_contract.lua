require("test.bootstrap").install_package_paths()
local suite = require("test.support.tooling_suites.architecture.arch_view_snapshot_tooling_contract")

describe("arch view snapshot tooling contracts", function()
  for _, case in ipairs(suite.tests) do
    it(case.name, case.run)
  end
end)
