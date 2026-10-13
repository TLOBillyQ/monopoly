-- src.ui.schema.player_choice 纯数据契约 pin：钉画布名/标题/灰底与四槽位逐名形态。
-- #293 清扫：underlay 字段未 pin 时"字面量 → nil"幸存。
require("test.bootstrap").install_package_paths()
local luassert = assert(require("test.support.luassert_loader").load())
local function assert_identity(actual, expected, message)
  luassert.is.equal(expected, actual, message)
end

TestSchemaPlayerChoice = {}

function TestSchemaPlayerChoice:test_pins_player_choice_screen_nodes_in_full()
  package.loaded["src.ui.schema.player_choice"] = nil
  local schema = require("src.ui.schema.player_choice")

  assert_identity(schema.canvas, "玩家选择屏", "canvas node name")
  assert_identity(schema.title, "玩家选择_标题", "title node name")
  assert_identity(schema.underlay, "玩家选择_灰底", "underlay node name")

  assert_identity(schema.slots[1], "玩家选择_槽位1")
  assert_identity(schema.slots[2], "玩家选择_槽位2")
  assert_identity(schema.slots[3], "玩家选择_槽位3")
  assert_identity(schema.slots[4], "玩家选择_槽位4")
end

return TestSchemaPlayerChoice
