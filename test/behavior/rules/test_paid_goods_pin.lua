-- paid_goods 配置完整性 pin:#293 复核——2 个 source="external" 被 nil 替换
-- 存活,根因是测试从不读这张配置。硬编码钉死。
require("test.bootstrap").install_package_paths()
local luassert = assert

local paid_goods = require("src.rules.commerce.paid_goods")

describe("TestPaidGoodsPin", function()
it("test_paid_currencies_carry_external_sources", function()
  luassert.truthy(paid_goods.enabled == true, "paid goods should be enabled")
  luassert.truthy(paid_goods.currencies["金豆"] ~= nil
    and paid_goods.currencies["金豆"].source == "external",
    "金豆 source should be external")
  luassert.truthy(paid_goods.currencies["乐园币"] ~= nil
    and paid_goods.currencies["乐园币"].source == "external",
    "乐园币 source should be external")
end)

end)
