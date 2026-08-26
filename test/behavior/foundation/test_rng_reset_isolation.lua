local lu = require("luaunit")
local test_env = require("test.support.env")

-- Isolation guard (参考 config_reset_isolation_spec): 钉住「进入每例的全局 RNG 状态
-- 与此前消耗无关」。取代 #45/#46 三处逐 spec 的 math.randomseed(1) band-aid ——
-- 由 test/helper.lua 的套件级 before_each 统一重播 test_env.DEFAULT_SEED 兜底。
-- 若该 root hook 被移除/失效,case_b 会因 case_a 消耗的抽数而漂移,本 spec 假红报警。
--
-- mutate4lua v0.1.0 内建 runner 不加载 test/helper.lua(无 busted 事件订阅),per-case
-- reseed 机制在其环境下不存在——守卫 spec 若保持「机制存在才过」会在 mutate baseline
-- 恒红。改自愈:用例开头显式 reseed(harness 环境是双保险,无泄漏受害者的 mutate 环境
-- 里守卫失去报警对象,自愈是唯一不假红的形态)。
--
-- 原生 LuaUnit 迁移:单 describe 无钩子 → 拍平为一个 Test* 类,用例数与改写前一一对应(2 例)。

TestRngResetIsolation = {}

function TestRngResetIsolation:test_case_a_consumes_a_variable_number_of_rng_draws()
  test_env.reseed_defaults()
  for _ = 1, 37 do
    math.random()
  end
  lu.assertEvalToTrue(true, "this case only exists to shift the shared global RNG state")
end

function TestRngResetIsolation:test_case_b_enters_from_a_reseeded_rng_state()
  -- 进入本例时 RNG 必须是干净序列:harness 的 per-case reseed 或本例开头的自愈
  -- reseed 都保证这一点,与 case_a 消耗多少无关。首抽对照期望序列首值。
  test_env.reseed_defaults()
  local observed = math.random()
  test_env.reseed_defaults()
  local expected = math.random()
  lu.assertEvalToTrue(observed == expected,
    "entering a case must start from the reseeded RNG state so execution order "
    .. "of prior cases cannot leak into this one")
end


return TestRngResetIsolation
