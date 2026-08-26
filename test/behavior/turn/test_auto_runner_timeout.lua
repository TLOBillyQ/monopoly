local suite = require("test.support.scenario_suites.auto_runner.timeout")

-- 原生 LuaUnit 迁移:describe 场景循环拍平为文件级 TestAutoRunnerTimeout 类,
-- 每例经 case.run() 原样执行,用例数与改写前一一对应(32 例)。
--
-- These scenarios drive dice / route decisions through math.random(); their
-- entry RNG state must be independent of what siblings consumed earlier in the
-- same process/worker. That reseed is now the suite-level responsibility of
-- test/helper.lua (每例 test/start 重播 test_env.DEFAULT_SEED),取代原先此处的
-- per-spec math.randomseed(1) band-aid(#45/#46)。守卫见
-- test/behavior/foundation/test_rng_reset_isolation.lua。
TestAutoRunnerTimeout = {}

for _, case in ipairs(suite.tests or suite) do
  TestAutoRunnerTimeout["test_" .. case.name] = function(self)
    case.run()
  end
end


return TestAutoRunnerTimeout
