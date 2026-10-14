require("test.bootstrap").install_package_paths()
local suite = require("test.support.tooling_suites.architecture.runner_infra_tooling")

describe("runner infrastructure tooling", function()
  for _, case in ipairs(suite.tests) do
    it(case.name, case.run)
  end
end)
