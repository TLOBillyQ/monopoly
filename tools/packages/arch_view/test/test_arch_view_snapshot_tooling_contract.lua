local suite = require("test.support.tooling_suites.architecture.arch_view_snapshot_tooling_contract")
local cases = suite.tests or {}

TestArchViewSnapshotToolingContract = {}

for _, case in ipairs(cases) do
  TestArchViewSnapshotToolingContract["test_" .. case.name] = function(self)
    case.run()
  end
end


return TestArchViewSnapshotToolingContract
