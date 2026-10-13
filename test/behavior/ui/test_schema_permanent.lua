-- src.ui.schema.permanent 纯数据契约 pin：钉画布名与道具槽的逐名形态。
-- #293 清扫：纯数据表不 pin 时"字段 → nil / 字面量 → nil"变异全幸存。
-- luacheck: ignore 143 (genuine busted injects luassert)
local luassert = assert
local function assert_identity(actual, expected, message)
  luassert.is.equal(expected, actual, message)
end

describe("TestSchemaPermanent", function()

it("test_pins_permanent_screen_nodes_in_full", function()
  package.loaded["src.ui.schema.permanent"] = nil
  local schema = require("src.ui.schema.permanent")

  assert_identity(schema.canvas, "常驻屏", "canvas node name")

  assert_identity(schema.item_slots[1], "常驻_道具槽位1")
  assert_identity(schema.item_slots[2], "常驻_道具槽位2")
  assert_identity(schema.item_slots[3], "常驻_道具槽位3")
  assert_identity(schema.item_slots[4], "常驻_道具槽位4")
  assert_identity(schema.item_slots[5], "常驻_道具槽位5")
end)

end)
