-- effect_transit 守卫闭合(#259 变异清扫):
-- item_draw_and_give.apply 的 "missing drawn item cfg" -> nil。
local luax = require("test.support.luax")
local support = require("test.support.shared_support")
local effect_transit = require("src.rules.land.effect_transit")
local inventory = require("src.rules.items.inventory")

TestLandEffectTransit = {}

function TestLandEffectTransit:test_item_draw_and_give_rejects_an_empty_draw_with_the_guard_message(self)
  local apply = effect_transit.executors.item_draw_and_give.apply
  support.with_patches({
    { target = inventory, key = "draw_random", value = function() return nil end },
  }, function()
    luax.has_error(function()
      apply({ game = {}, player = { id = 1 }, tile = { type = "item" } })
    end, "missing drawn item cfg")
  end)
end


return TestLandEffectTransit
