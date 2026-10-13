-- #293 批3 pin:src/ui/schema/remote_choice.lua 为纯数据表,幸存者均为
-- 字段值换 nil。逐字段钉死数据契约(遥控骰子屏的节点名与六选项槽)。

local luassert = assert
local remote_choice = require("src.ui.schema.remote_choice")

local function _assert_eq(a, b, msg)
  luassert.is.equal(b, a, msg)
end

describe("TestRemoteChoiceSchema", function()

it("test_canvas_and_screen_node_names_are_pinned", function()
  -- canvas / title / body / underlay 换 nil:四个节点名必须稳定。
  _assert_eq(remote_choice.canvas, "遥控骰子屏", "canvas node name")
  _assert_eq(remote_choice.title, "遥控骰子_标题", "title node name")
  _assert_eq(remote_choice.body, "遥控骰子_正文", "body node name")
  _assert_eq(remote_choice.underlay, "遥控骰子_灰底", "underlay node name")
end)

it("test_options_has_six_slots", function()
  -- options 表与各槽换 nil:六个选项节点必须齐全。
  _assert_eq(#remote_choice.options, 6, "options slot count")
  local expected = {
    "遥控骰子_选项_01", "遥控骰子_选项_02", "遥控骰子_选项_03",
    "遥控骰子_选项_04", "遥控骰子_选项_05", "遥控骰子_选项_06",
  }
  for index, node_name in ipairs(expected) do
    _assert_eq(remote_choice.options[index], node_name, "option slot " .. index)
  end
end)

end)
