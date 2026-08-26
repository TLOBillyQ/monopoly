-- src.ui.schema.popup 纯数据契约 pin：钉画布名/标题/图片与关闭节点逐名形态。
-- #293 清扫：dismiss_nodes 未 pin 时"字面量 → nil"幸存。
local lu = require("luaunit")

TestSchemaPopup = {}

function TestSchemaPopup:test_pins_popup_screen_nodes_in_full()
  package.loaded["src.ui.schema.popup"] = nil
  local schema = require("src.ui.schema.popup")

  lu.assertIs(schema.canvas, "卡牌展示屏", "canvas node name")
  lu.assertIs(schema.title, "卡牌展示_标题", "title node name")
  lu.assertIs(schema.card, "卡牌展示_图片", "card node name")

  lu.assertIs(schema.dismiss_nodes[1], "卡牌展示_灰底")
  lu.assertIs(schema.dismiss_nodes[2], "卡牌展示_图片")
end

return TestSchemaPopup
