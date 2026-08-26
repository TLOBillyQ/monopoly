-- 契约钉:src/ui/schema/market_layout.lua 的节点名是宿主 UI 契约——
-- 硬编码字符串断言使字段值->nil 变异露馅(测试与"变异后的字段"比对时,
-- 双方同变 nil 会假通过,必须钉死字面量)。

local P = require("test.support.shared_support")
local _assert_eq = P.assert_eq
local market_layout = require("src.ui.schema.market_layout")

TestMarketLayoutContract = {}

function TestMarketLayoutContract:test_core_screen_node_names_are_pinned()
  _assert_eq(market_layout.container, "黑市屏", "container node name is pinned")
  _assert_eq(market_layout.tab_item, "黑市-道具商店按钮", "tab_item node name is pinned")
  _assert_eq(market_layout.tab_item_gray, "黑市-道具商店灰底", "tab_item_gray node name is pinned")
  _assert_eq(market_layout.tab_item_gray_label, "黑市-道具商店灰底文本", "tab_item_gray_label node name is pinned")
  _assert_eq(market_layout.selected_card, "黑市_选中卡牌", "selected_card node name is pinned")
  _assert_eq(market_layout.cash_background, "黑市_现金显示底框", "cash_background node name is pinned")
  _assert_eq(market_layout.cash_shadow, "黑市_现金显示底框投影", "cash_shadow node name is pinned")
  _assert_eq(market_layout.countdown, "黑市_倒计时", "countdown node name is pinned")
  _assert_eq(market_layout.countdown_line, "黑市_倒计时横线", "countdown_line node name is pinned")
  _assert_eq(market_layout.empty_ref_key, "Empty", "empty_ref_key is pinned")
end

function TestMarketLayoutContract:test_item_slot_tables_start_at_index_one()
  -- 杀 L37 循环 1->0:item_* 表不得多出 [0] 条目。
  _assert_eq(market_layout.item_buttons[0], nil, "item buttons must start at index 1")
  _assert_eq(market_layout.item_labels[0], nil, "item labels must start at index 1")
  _assert_eq(market_layout.item_frames[0], nil, "item frames must start at index 1")
  _assert_eq(market_layout.item_selection_frames[0], nil, "selection frames must start at index 1")
  _assert_eq(market_layout.sold_out_badges[0], nil, "sold out badges must start at index 1")
  _assert_eq(market_layout.sold_out_labels[0], nil, "sold out labels must start at index 1")
end

return TestMarketLayoutContract
