-- src.ui.schema.player_choice 纯数据契约 pin：钉画布名/标题/灰底与四槽位逐名形态。
-- #293 清扫：underlay 字段未 pin 时"字面量 → nil"幸存。
local lu = require("luaunit")

TestSchemaPlayerChoice = {}

function TestSchemaPlayerChoice:test_pins_player_choice_screen_nodes_in_full()
  package.loaded["src.ui.schema.player_choice"] = nil
  local schema = require("src.ui.schema.player_choice")

  lu.assertIs(schema.canvas, "玩家选择屏", "canvas node name")
  lu.assertIs(schema.title, "玩家选择_标题", "title node name")
  lu.assertIs(schema.underlay, "玩家选择_灰底", "underlay node name")

  lu.assertIs(schema.slots[1], "玩家选择_槽位1")
  lu.assertIs(schema.slots[2], "玩家选择_槽位2")
  lu.assertIs(schema.slots[3], "玩家选择_槽位3")
  lu.assertIs(schema.slots[4], "玩家选择_槽位4")
end

return TestSchemaPlayerChoice
