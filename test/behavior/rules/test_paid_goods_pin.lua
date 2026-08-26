-- paid_goods 配置完整性 pin:#293 复核——2 个 source="external" 被 nil 替换
-- 存活,根因是测试从不读这张配置。硬编码钉死。
local lu = require("luaunit")

local paid_goods = require("src.rules.commerce.paid_goods")

TestPaidGoodsPin = {}

function TestPaidGoodsPin:test_paid_currencies_carry_external_sources()
  lu.assertEvalToTrue(paid_goods.enabled == true, "paid goods should be enabled")
  lu.assertEvalToTrue(paid_goods.currencies["金豆"] ~= nil
    and paid_goods.currencies["金豆"].source == "external",
    "金豆 source should be external")
  lu.assertEvalToTrue(paid_goods.currencies["乐园币"] ~= nil
    and paid_goods.currencies["乐园币"].source == "external",
    "乐园币 source should be external")
end

return TestPaidGoodsPin
