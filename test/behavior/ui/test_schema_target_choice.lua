-- src.ui.schema.target_choice 纯数据契约 pin：逐个钉画布名/文案与 7 槽位按钮/
-- 标签/投影的逐名形态。#293 清扫:纯数据表不 pin 时「字段 → nil / 字面量 → nil」
-- 变异全幸存——内容配置是行为面,改了任何一格都该被合同钉住。
local luassert = assert
local function assert_identity(actual, expected, message)
  luassert.is.equal(expected, actual, message)
end

describe("TestSchemaTargetChoice", function()

it("test_pins_choice_screen_text_slots_in_full", function()
  package.loaded["src.ui.schema.target_choice"] = nil
  local schema = require("src.ui.schema.target_choice")

  assert_identity(schema.canvas, "位置选择屏", "canvas node name")
  assert_identity(schema.title, "位置_副标题", "title node name")
  assert_identity(schema.body, "位置_放置文本", "body node name")
  assert_identity(schema.confirm, "位置_确认按钮", "confirm node name")
  assert_identity(schema.cancel, "位置_取消按钮", "cancel node name")

  assert_identity(schema.slot_buttons[1], "位置-槽位1按钮")
  assert_identity(schema.slot_buttons[2], "位置-槽位2按钮")
  assert_identity(schema.slot_buttons[3], "位置-槽位3按钮")
  assert_identity(schema.slot_buttons[4], "位置-槽位4按钮")
  assert_identity(schema.slot_buttons[5], "位置-槽位5按钮")
  assert_identity(schema.slot_buttons[6], "位置-槽位6按钮")
  assert_identity(schema.slot_buttons[7], "位置-槽位7按钮")

  assert_identity(schema.slot_labels[1], "位置-槽位1文本")
  assert_identity(schema.slot_labels[2], "位置-槽位2文本")
  assert_identity(schema.slot_labels[3], "位置-槽位3文本")
  assert_identity(schema.slot_labels[4], "位置-槽位4文本")
  assert_identity(schema.slot_labels[5], "位置-槽位5文本")
  assert_identity(schema.slot_labels[6], "位置-槽位6文本")
  assert_identity(schema.slot_labels[7], "位置-槽位7文本")

  assert_identity(schema.slot_projections[1], "位置-槽位1投影")
  assert_identity(schema.slot_projections[2], "位置-槽位2投影")
  assert_identity(schema.slot_projections[3], "位置-槽位3投影")
  assert_identity(schema.slot_projections[4], "位置-槽位4投影")
  assert_identity(schema.slot_projections[5], "位置-槽位5投影")
  assert_identity(schema.slot_projections[6], "位置-槽位6投影")
  assert_identity(schema.slot_projections[7], "位置-槽位7投影")
end)

end)