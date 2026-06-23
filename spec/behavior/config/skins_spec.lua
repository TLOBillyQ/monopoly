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

  it("pins default skin identity and ordering", function()
    package.loaded["src.config.content.skins"] = nil
    local skins = require("src.config.content.skins")
    local expected = {
      { order = 1, product_id = 5001, name = "小猪佩奇", creature_key = "peppa_pig" },
      { order = 2, product_id = 5002, name = "小猪乔治", creature_key = "george_pig" },
      { order = 3, product_id = 5003, name = "海绵宝宝", creature_key = "spongebob" },
      { order = 4, product_id = 5004, name = "派大星", creature_key = "patrick_star" },
      { order = 5, product_id = 5005, name = "奶龙", creature_key = "nailong" },
      { order = 6, product_id = 5006, name = "水豚嘟嘟", creature_key = "capybara_dudu" },
    }

    assert(#skins == #expected, "default skin count mismatch")
    for i, fields in ipairs(expected) do
      local skin = skins[i]
      assert(skin.order == fields.order, "skin order mismatch at " .. tostring(i))
      assert(skin.product_id == fields.product_id, "skin product_id mismatch at " .. tostring(i))
      assert(skin.name == fields.name, "skin name mismatch at " .. tostring(i))
      assert(skin.creature_key == fields.creature_key, "skin creature key mismatch at " .. tostring(i))
    end
  end)
end)
