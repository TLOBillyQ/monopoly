-- luacheck: ignore 143
require("test.bootstrap").install_package_paths()
local luassert = assert
-- Behavior specs for src/ui/view/gameplay_read_port.lua 的投入总额计算:
-- level 归一化边界与非法 price 的兜底必须保持。

local function _assert_eq(actual, expected, message)
  luassert.is.equal(expected, actual, message)
end
local gameplay_read_port = require("src.ui.view.gameplay_read_port")

local function _tile_with_upgrade_costs(costs)
  return {
    price = 100,
    upgrade_costs = costs,
  }
end

describe("TestGameplayReadPort", function()

it("test_zero_level_adds_no_upgrade_costs", function()
  -- 杀 L7 的 0->1:level=0 时不得误计第一档升级费。
  _assert_eq(gameplay_read_port.total_land_invested(_tile_with_upgrade_costs({ 10, 20 }), 0), 100,
    "level 0 should add no upgrade costs")
end)

it("test_negative_level_is_normalized_to_zero", function()
  -- 杀 L7 的 or->and:负数 level 必须归一为 0,不能原样带进求和。
  _assert_eq(gameplay_read_port.total_land_invested(_tile_with_upgrade_costs({ 10, 20 }), -1), 100,
    "negative level should normalize to zero upgrade costs")
end)

it("test_non_numeric_price_falls_back_to_zero", function()
  -- 杀 L19 的 0->1:非法 price 必须按 0 计,不能按 1。
  _assert_eq(gameplay_read_port.total_land_invested({ price = "abc", upgrade_costs = {} }, 1), 0,
    "non-numeric price should fall back to 0")
end)

end)
