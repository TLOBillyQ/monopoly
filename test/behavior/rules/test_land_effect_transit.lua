require("test.bootstrap").install_package_paths()
local luassert = require("luassert")
-- effect_transit 守卫闭合(#259 变异清扫):
-- item_draw_and_give.apply 的 "missing drawn item cfg" -> nil。
local support = require("test.support.shared_support")
local effect_transit = require("src.rules.land.effect_transit")
local inventory = require("src.rules.items.inventory")


describe("TestLandEffectTransit", function()
  it("test_item_draw_and_give_rejects_an_empty_draw_with_the_guard_message", function()
    local apply = effect_transit.executors.item_draw_and_give.apply
    support.with_patches({
      { target = inventory, key = "draw_random", value = function() return nil end },
    }, function()
      luassert.has_error(function()
        apply({ game = {}, player = { id = 1 }, tile = { type = "item" } })
      end, "missing drawn item cfg")
    end)
  end)


end)
