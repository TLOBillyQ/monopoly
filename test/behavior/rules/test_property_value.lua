-- property_value.lua 直测:total_invested 的价格/升级档缺省与累加语义。
-- 数值缺省(0→1 变异)被资产结算直接消费,必须钉住。
local lu = require("luaunit")
local luax = require("test.support.luax")

local property_value = require("src.rules.commerce.property_value")

TestPropertyValue = {}

function TestPropertyValue:test_rejects_a_nil_tile()
  luax.has_error(function()
    property_value.total_invested(nil, 1)
  end, "missing tile")
end

function TestPropertyValue:test_price_defaults_to_zero()
  lu.assertEvalToTrue(property_value.total_invested({}, 0) == 0,
    "a tile without a price must total zero at level 0")
end

function TestPropertyValue:test_level_defaults_to_zero()
  lu.assertEvalToTrue(property_value.total_invested({ price = 100 }, nil) == 100,
    "a nil level must not add any upgrade tier")
  -- 强化:level nil 时即使有升级档也不计入(杀 level or 0 的 0→1 变异)。
  lu.assertEvalToTrue(property_value.total_invested({ price = 100, upgrade_costs = { 50 } }, nil) == 100,
    "a nil level must ignore present upgrade tiers")
end

function TestPropertyValue:test_missing_upgrade_cost_tier_counts_as_zero()
  lu.assertEvalToTrue(property_value.total_invested({ price = 100, upgrade_costs = {} }, 2) == 100,
    "missing upgrade tiers must count as zero")
  -- 强化:缺失档位按 0 计而非 1(杀 costs[next] or 0 的 0→1 变异)。
  lu.assertEvalToTrue(property_value.total_invested({ price = 100, upgrade_costs = { 50 } }, 2) == 150,
    "a tier beyond the cost list must count as zero")
end

function TestPropertyValue:test_totals_price_plus_upgrade_tiers()
  lu.assertEvalToTrue(property_value.total_invested(
    { price = 100, upgrade_costs = { 50, 70 } }, 2) == 220,
    "level 2 must add the first two upgrade tiers")
  lu.assertEvalToTrue(property_value.total_invested(
    { price = 100, upgrade_costs = { 50, 70 } }, 0) == 100,
    "level 0 must not add any upgrade tier")
end

return TestPropertyValue
