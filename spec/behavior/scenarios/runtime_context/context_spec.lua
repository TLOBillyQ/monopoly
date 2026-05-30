local suite = require("spec.support.scenario_suites.runtime.context")

describe(suite.name, function()
  -- These scenarios drive roadblock candidate priority + landing branch
  -- selection through math.random(); when a sibling (notably
  -- spec/behavior/rules/item_spec.lua) runs first in the same busted process
  -- it consumes a variable number of RNG calls and shifts state on entry to
  -- these cases. The result is a code-path flip in src/rules/items/roadblock.lua
  -- (~L98/L103/L159 priority branches) and src/rules/board/init.lua (~L209
  -- next_index/passed_start branch) — invisible at w=1/3/6 because item_spec
  -- and context_spec land in the same shard, but at w=8 LPT splits them and
  -- the drift materialises as a -0.04% src/rules coverage delta. Re-seed to
  -- spec/support/test_env.lua install_defaults()'s seed (1) so each case
  -- starts from a known RNG state regardless of what ran before.
  before_each(function()
    math.randomseed(1)
  end)
  for _, case in ipairs(suite.tests or suite) do
    it(case.name, case.run)
  end
end)
