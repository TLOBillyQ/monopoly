if arg then rawset(arg, 0, "tools/packages/mutate/test/test_mutate4lua_tooling_contract.lua") end
require("test.bootstrap").install_package_paths()
local suite = require("test.support.tooling_suites.architecture.mutate4lua_tooling_contract")

describe("mutate4lua tooling contracts", function()
  for _, case in ipairs(suite.tests) do
    it(case.name, case.run)
  end
end)
