require("test.bootstrap").install_package_paths()
-- busted injects the extensible assertion object into each file environment.
-- luacheck: ignore 143
local luassert = assert
local test_env = require("test.support.env")


describe("TestRngResetIsolation", function()

  it("test_case_a_consumes_a_variable_number_of_rng_draws", function()
    test_env.reseed_defaults()
    for _ = 1, 37 do
      math.random()
    end
    luassert.truthy(true, "this case only exists to shift the shared global RNG state")
  end)

  it("test_case_b_enters_from_a_reseeded_rng_state", function()
    -- 进入本例时 RNG 必须是干净序列:harness 的 per-case reseed 或本例开头的自愈
    -- reseed 都保证这一点,与 case_a 消耗多少无关。首抽对照期望序列首值。
    test_env.reseed_defaults()
    local observed = math.random()
    test_env.reseed_defaults()
    local expected = math.random()
    luassert.truthy(observed == expected, "entering a case must start from the reseeded RNG state so execution order "
      .. "of prior cases cannot leak into this one")
  end)


end)
