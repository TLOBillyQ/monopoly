local suite = require("test.support.scenario_suites.auto_runner.timeout")

-- 每个 descriptor 经独立 it 原样调用 case.run()，保留场景集合。
--
-- These scenarios drive dice / route decisions through math.random(); their
-- entry RNG state must be independent of what siblings consumed earlier in the
-- same process/worker. That reseed is now the suite-level responsibility of
-- test/helper.lua (每例 test/start 重播 test_env.DEFAULT_SEED),取代原先此处的
-- per-spec math.randomseed(1) band-aid(#45/#46)。守卫见
-- test/behavior/foundation/test_rng_reset_isolation.lua。
describe("TestAutoRunnerTimeout", function()
  for _, case in ipairs(suite.tests or suite) do
    it("test_" .. case.name, function()
      case.run()
    end)
  end
end)
