local suite = require("test.support.tooling_suites.architecture.luaunit_runner_infra_tooling")
local cases = suite.tests or {}

TestLuaunitRunnerInfraTooling = {}

-- 原 busted 场景循环:for _, case in ipairs(cases) do it(case.name, case.run) end
for _, case in ipairs(cases) do
  TestLuaunitRunnerInfraTooling["test_" .. case.name] = function(self)
    case.run()
  end
end


return TestLuaunitRunnerInfraTooling
