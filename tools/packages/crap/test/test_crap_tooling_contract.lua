if arg then rawset(arg, 0, "tools/packages/crap/test/test_crap_tooling_contract.lua") end
require("test.bootstrap").install_package_paths()
local suite = require("test.support.tooling_suites.architecture.crap_tooling_contract")

describe("crap tooling contracts", function()
  for _, case in ipairs(suite.tests) do
    it(case.name, case.run)
  end
end)
