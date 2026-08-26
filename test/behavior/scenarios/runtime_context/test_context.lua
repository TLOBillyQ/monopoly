local support = require("test.support.shared_support")
local suite = require("test.support.scenario_suites.runtime.context")

TestContext = {}

function TestContext:tearDown()
  -- 场景用例内部会把共享端口基线拆到未配置态,必须装回,否则 mutate 车道窄 suite 子集会撞空端口(#217)。
  support.restore_runtime_services()
end

-- These scenarios drive roadblock candidate priority + landing branch
-- selection through math.random(); their entry RNG state must be independent
-- of what siblings (notably test/behavior/rules/test_item.lua) consumed earlier
-- in the same process/worker. That reseed is now the suite-level responsibility
-- of test/helper.lua(每例 test/start 重播 test_env.DEFAULT_SEED),取代原先此处的
-- per-spec math.randomseed(1) band-aid(#45/#46)。守卫见
-- test/behavior/foundation/test_rng_reset_isolation.lua。
for _, case in ipairs(suite.tests or suite) do
  TestContext["test_" .. case.name] = function(self)
    case.run()
  end
end


return TestContext
