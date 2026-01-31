# 画布清单与职责

本清单面向 Eggitor 画布与节点结构，给出“要做几张画布、各自负责什么”。

## 必需画布

1. base_screen（基础屏）
   - 用途：主 HUD + 操作按钮。
   - 主要节点：
     - backgroud_rect_base
     - panel_title
     - panel_turn
     - panel_player_1（面板容器）
     - panel_player_1_name（玩家名）
     - panel_player_1_detail（总资产）
     - panel_player_1_avatar（头像）
     - panel_player_1_cash
     - 玩家1底板（可选装饰）
     - 玩家1底板颜色（可选装饰）
     - panel_player_2（面板容器）
     - panel_player_2_name（玩家名）
     - panel_player_2_detail（总资产）
     - panel_player_2_avatar（头像）
     - panel_player_2_cash
     - panel_player_2_land_count
     - 玩家2底板（可选装饰）
     - 玩家2底板颜色（可选装饰）
     - panel_player_3（面板容器）
     - panel_player_3_name（玩家名）
     - panel_player_3_detail（总资产）
     - panel_player_3_avatar（头像）
     - panel_player_3_cash
     - panel_player_3_land_count
     - 玩家3底板（可选装饰）
     - 玩家3底板颜色（可选装饰）
     - panel_player_4（面板容器）
     - panel_player_4_name（玩家名）
     - panel_player_4_detail（总资产）
     - panel_player_4_avatar（头像）
     - panel_player_4_cash
     - 玩家4底板（可选装饰）
     - 玩家4底板颜色（可选装饰）
     - item_slot_1
     - item_slot_2
     - item_slot_3
     - item_slot_4
     - item_slot_5
     - btn_next
     - btn_auto
   - 说明：当前 ui_data 仅导出 `panel_player_2_land_count` 与 `panel_player_3_land_count`，其余玩家地块数量需在 Eggitor 侧补齐并重新导出。
   - 显示控制：默认显示；如需切换，用 ECA 事件控制。
   - 说明：基础屏只展示头像、现金、地块数量、总资产，不再包含 tile_1..tile_45 或格子详情相关节点。道具槽位以图片显示，空槽位使用“空”贴图并禁用点击。

2. loading_screen（加载屏）
   - 用途：遮罩与加载提示。
   - 主要节点：
     - loading_tip
     - backgroud_loading
   - 显示控制：ECA 事件控制，启动时先显示加载屏并隐藏基础屏，短延时后隐藏加载屏并显示基础屏。

3. market_panel（黑市屏）
   - 用途：黑市购买界面。
   - 主要节点：
     - market_item_button1
     - market_item_button2
     - market_item_button3
     - market_item_button4
     - market_item_button5
     - market_item_button6
     - market_item_button7
     - market_item_button8
     - market_item_button9
     - market_item_button10
     - market_item_label_1
     - market_item_label_2
     - market_item_label_3
     - market_item_label_4
     - market_item_label_5
     - market_item_label_6
     - market_item_label_7
     - market_item_label_8
     - market_item_label_9
     - market_item_label_10
     - market_item_frame_1
     - market_item_frame_2
     - market_item_frame_3
     - market_item_frame_4
     - market_item_frame_5
     - market_item_frame_6
     - market_item_frame_7
     - market_item_frame_8
     - market_item_frame_9
     - market_item_frame_10
     - market_panel_backgroud
     - market_selected_card
     - market_price_label
     - market_confirm_button
     - market_cancel_button
     - market_item_containter
   - 显示控制：Lua 自动打开与关闭（`Manager/MarketManager/GUI/UIMarket.lua`）。

4. modal_choice 与 modal_popup（弹窗）
   - 用途：选择弹窗、确认弹窗。
   - 主要节点：
     - modal_choice
     - choice_title
     - choice_body
     - choice_cancel
     - choice_option1
     - choice_option2
     - choice_option3
     - choice_option4
     - modal_popup
     - popup_title
     - popup_body
     - popup_confirm
     - popup_card
  - 显示控制：Lua 自动打开与关闭（`Manager/System/RuntimeUI.lua`）。

## 层级建议

- loading_screen 在最上层（覆盖全部）。
- base_screen 常驻底层。
- market_panel 与 modal_choice、modal_popup 覆盖 base_screen。
- backgroud_rect_base 可作为基础底色，层级低于交互节点。
