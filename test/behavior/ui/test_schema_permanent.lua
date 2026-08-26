-- src.ui.schema.permanent 纯数据契约 pin：钉画布名与道具槽的逐名形态。
-- #293 清扫：纯数据表不 pin 时"字段 → nil / 字面量 → nil"变异全幸存。
local lu = require("luaunit")

TestSchemaPermanent = {}

function TestSchemaPermanent:test_pins_permanent_screen_nodes_in_full()
  package.loaded["src.ui.schema.permanent"] = nil
  local schema = require("src.ui.schema.permanent")

  lu.assertIs(schema.canvas, "常驻屏", "canvas node name")

  lu.assertIs(schema.item_slots[1], "常驻_道具槽位1")
  lu.assertIs(schema.item_slots[2], "常驻_道具槽位2")
  lu.assertIs(schema.item_slots[3], "常驻_道具槽位3")
  lu.assertIs(schema.item_slots[4], "常驻_道具槽位4")
  lu.assertIs(schema.item_slots[5], "常驻_道具槽位5")
end

return TestSchemaPermanent
