# 黑市屏（market_panel）

黑市界面由 Lua 自动打开与关闭，节点命名需与 `src/adapters/eggy/market_ui.lua` 一致。

## 结构建议

market_panel（ECanvas）
- market_item_button1（EImage，可点击）
- market_item_button2（EImage，可点击）
- market_item_button3（EImage，可点击）
- market_item_button4（EImage，可点击）
- market_item_button5（EImage，可点击）
- market_item_button6（EImage，可点击）
- market_item_button7（EImage，可点击）
- market_item_button8（EImage，可点击）
- market_item_button9（EImage，可点击）
- market_item_button10（EImage，可点击）
- market_item_label_1（ELabel）
- market_item_label_2（ELabel）
- market_item_label_3（ELabel）
- market_item_label_4（ELabel）
- market_item_label_5（ELabel）
- market_item_label_6（ELabel）
- market_item_label_7（ELabel）
- market_item_label_8（ELabel）
- market_item_label_9（ELabel）
- market_item_label_10（ELabel）
- market_item_frame_1（EImage）
- market_item_frame_2（EImage）
- market_item_frame_3（EImage）
- market_item_frame_4（EImage）
- market_item_frame_5（EImage）
- market_item_frame_6（EImage）
- market_item_frame_7（EImage）
- market_item_frame_8（EImage）
- market_item_frame_9（EImage）
- market_item_frame_10（EImage）
- market_panel_backgroud（EImage）
- market_selected_card（EImage）
- market_price_label（ELabel）
- market_confirm_button（EButton）
- market_cancel_button（EButton）
- market_panel_close（EButton，可点击）
- market_item_containter（EImage）

## 显示与隐藏

- 打开：`EggyLayerMarket.open_market_panel`
- 关闭：`EggyLayerMarket.close_market_panel`

## 点击事件（已注册）

- market_item_button1 -> 选择商品
- market_item_button2 -> 选择商品
- market_item_button3 -> 选择商品
- market_item_button4 -> 选择商品
- market_item_button5 -> 选择商品
- market_item_button6 -> 选择商品
- market_item_button7 -> 选择商品
- market_item_button8 -> 选择商品
- market_item_button9 -> 选择商品
- market_item_button10 -> 选择商品
- market_confirm_button -> 确认购买
- market_cancel_button -> 取消购买
- market_panel_close -> 取消购买

## 资源引用规则

- 物品卡图与载具卡图：按 `product_id` 或名称映射到 `src/adapters/eggy/refs.lua`。
- 稀有度框：`MarketUI.rarity_ref_keys` -> lv1、lv2、lv3。
- 空白图：key 为 “空”。
