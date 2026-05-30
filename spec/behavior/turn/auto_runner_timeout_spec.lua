local suite = require("spec.support.scenario_suites.auto_runner.timeout")

describe(suite.name, function()
  -- These scenarios drive dice / route decisions through math.random(); when
  -- siblings (notably spec/behavior/app/startup_profile_spec.lua's app_init_*
  -- tests via _reload_app_init_with_stubs) consume a variable number of RNG
  -- calls during runtime composition, the RNG state on entry to these cases
  -- shifts and ~28 of the 32 cases silently take a different code path that
  -- never reaches pay_rent — dropping ~0.1% of src/rules coverage in shard
  -- mode. Re-seed to the same value spec/support/test_env.lua's
  -- install_defaults() uses on first install (1) so each case starts from a
  -- known RNG state regardless of what ran before in the same process.
  before_each(function()
    math.randomseed(1)
  end)
  for _, case in ipairs(suite.tests or suite) do
    it(case.name, case.run)
  end
end)
