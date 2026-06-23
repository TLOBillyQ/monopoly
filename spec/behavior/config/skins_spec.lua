describe("default skin catalog", function()
  it("prices every default skin as a 198 jindou purchase", function()
    package.loaded["src.config.content.skins"] = nil
    local skins = require("src.config.content.skins")

    for _, skin in ipairs(skins) do
      assert(skin.unlock == "purchase", "default skin should be purchase: " .. tostring(skin.product_id))
      assert(skin.currency == "金豆", "default skin currency should be 金豆: " .. tostring(skin.product_id))
      assert(skin.price == 198, "default skin price should be 198: " .. tostring(skin.product_id))
    end
  end)
end)
