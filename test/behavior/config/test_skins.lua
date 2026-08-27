local lu = require("luaunit")

TestSkins = {}

function TestSkins:test_prices_every_default_skin_as_a_jindou_purchase()
  package.loaded["src.config.content.skins"] = nil
  local skins = require("src.config.content.skins")
  local expected_price = { [5005] = 68, [5006] = 98, [5003] = 198, [5004] = 198 }

  for _, skin in ipairs(skins) do
    lu.assertEvalToTrue(skin.unlock == "purchase", "default skin should be purchase: " .. tostring(skin.product_id))
    lu.assertEvalToTrue(skin.currency == "金豆", "default skin currency should be 金豆: " .. tostring(skin.product_id))
    lu.assertEvalToTrue(skin.price == expected_price[skin.product_id], "default skin price mismatch: " .. tostring(skin.product_id))
  end
end

function TestSkins:test_pins_default_skin_identity_and_ordering()
  package.loaded["src.config.content.skins"] = nil
  local skins = require("src.config.content.skins")
  local expected = {
    { order = 1, product_id = 5005, name = "奶龙", creature_key = "nailong" },
    { order = 2, product_id = 5006, name = "水豚嘟嘟", creature_key = "capybara_dudu" },
    { order = 5, product_id = 5003, name = "海绵宝宝", creature_key = "spongebob" },
    { order = 6, product_id = 5004, name = "派大星", creature_key = "patrick_star" },
  }

  lu.assertEvalToTrue(#skins == #expected, "default skin count mismatch")
  for i, fields in ipairs(expected) do
    local skin = skins[i]
    lu.assertEvalToTrue(skin.order == fields.order, "skin order mismatch at " .. tostring(i))
    lu.assertEvalToTrue(skin.product_id == fields.product_id, "skin product_id mismatch at " .. tostring(i))
    lu.assertEvalToTrue(skin.name == fields.name, "skin name mismatch at " .. tostring(i))
    lu.assertEvalToTrue(skin.creature_key == fields.creature_key, "skin creature key mismatch at " .. tostring(i))
  end
end


return TestSkins
