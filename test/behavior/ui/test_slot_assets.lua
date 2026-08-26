local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local slot_assets = require("src.ui.render.market.slot_assets")
local runtime_assets = require("src.config.runtime_assets")

TestSlotAssets = {}

-- selection_icon_key 商品图命中:商品图可用时直接取键,不走兜底。
function TestSlotAssets:test_selection_icon_key_uses_item_icon_when_available()
  _with_patches({
    { target = runtime_assets, key = "image_for_market_item", value = function()
      return { ok = true, image_key = "item_key" }
    end },
    { target = runtime_assets, key = "empty_image", value = function()
      error("empty fallback must not run when the item icon resolves")
    end },
  }, function()
    _assert_eq(slot_assets.selection_icon_key(nil, 1, { id = 1 }, nil), "item_key",
      "resolved item icon should win")
  end)
end

-- selection_icon_key 的商品图回落:商品图缺失时直接取空图键(#511 已移除稀有度兜底)。
function TestSlotAssets:test_selection_icon_key_falls_back_to_empty_image()
  _with_patches({
    { target = runtime_assets, key = "image_for_market_item", value = function() return { ok = false } end },
    { target = runtime_assets, key = "empty_image", value = function()
      return { image_key = "empty_key" }
    end },
  }, function()
    _assert_eq(slot_assets.selection_icon_key(nil, 1, { id = 1 }, nil), "empty_key",
      "fallback should use the empty image key")
  end)
end

return TestSlotAssets
