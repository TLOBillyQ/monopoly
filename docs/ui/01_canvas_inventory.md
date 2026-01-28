# 画布清单与职责

本清单面向 Eggitor 画布与节点结构，给出“要做几张画布、各自负责什么”。

## 必需画布

1. base_screen（基础屏）
   - 用途：主 HUD + 操作按钮。
   - 主要节点：
     - panel_title
     - panel_turn
     - panel_current_title
     - panel_current_name
     - panel_current_role
     - panel_current_phase
     - panel_current_dice
     - panel_players_title
     - panel_player_1
     - panel_player_1_detail（总资产）
     - panel_player_1_info（可选底图）
     - panel_player_1_avatar（头像）
     - panel_player_1_cash
     - panel_player_1_land_count
     - panel_player_1_base（可选装饰）
     - panel_player_1_base_color（可选装饰）
     - panel_player_2
     - panel_player_2_detail（总资产）
     - panel_player_2_info（可选底图）
     - panel_player_2_avatar（头像）
     - panel_player_2_cash
     - panel_player_2_land_count
     - panel_player_2_base（可选装饰）
     - panel_player_2_base_color（可选装饰）
     - panel_player_3
     - panel_player_3_detail（总资产）
     - panel_player_3_info（可选底图）
     - panel_player_3_avatar（头像）
     - panel_player_3_cash
     - panel_player_3_land_count
     - panel_player_3_base（可选装饰）
     - panel_player_3_base_color（可选装饰）
     - panel_player_4
     - panel_player_4_detail（总资产）
     - panel_player_4_info（可选底图）
     - panel_player_4_avatar（头像）
     - panel_player_4_cash
     - panel_player_4_land_count
     - panel_player_4_base（可选装饰）
     - panel_player_4_base_color（可选装饰）
     - panel_item_slots
     - item_slot_1
     - item_slot_2
     - item_slot_3
     - item_slot_4
     - item_slot_5
     - panel_log_title
     - panel_log_body
     - btn_next
     - btn_auto
     - btn_restart
     - btn_auto_label
     - overlay_mask
     - background_rect
   - 显示控制：默认显示；如需切换，用 ECA 事件控制。
   - 说明：基础屏只展示头像、现金、地块数量、总资产，不再包含 tile_1..tile_45 或格子详情相关节点。道具槽位以图片显示，空槽位使用“空”贴图并禁用点击。

2. loading_screen（加载屏）
   - 用途：遮罩与加载提示。
   - 主要节点：
     - loading_tip
     - background_rect
   - 显示控制：ECA 事件控制，启动时先显示加载屏并隐藏基础屏，短延时后隐藏加载屏并显示基础屏。

3. market_panel（黑市屏）
   - 用途：黑市购买界面。
   - 主要节点：
     - market_item_button_1
     - market_item_button_2
     - market_item_button_3
     - market_item_button_4
     - market_item_button_5
     - market_item_button_6
     - market_item_button_7
     - market_item_button_8
     - market_item_button_9
     - market_item_button_10
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
     - market_selected_card
     - market_price_label
     - market_confirm_button
     - market_cancel_button
     - market_icon_placeholder
   - 显示控制：Lua 自动打开与关闭（`EggyLayerMarket`）。

4. modal_choice 与 modal_popup（弹窗）
   - 用途：选择弹窗、确认弹窗。
   - 主要节点：
     - modal_choice
     - choice_title
     - choice_body
     - choice_cancel
     - choice_option_1
     - choice_option_2
     - choice_option_3
     - choice_option_4
     - modal_popup
     - popup_title
     - popup_body
     - popup_confirm
     - popup_confirm_alt
     - popup_card
   - 显示控制：Lua 自动打开与关闭（`EggyLayer`）。

## 层级建议

- loading_screen 在最上层（覆盖全部）。
- base_screen 常驻底层。
- market_panel 与 modal_choice、modal_popup 覆盖 base_screen。
- overlay_mask 可放在 base_screen 或弹窗画布，按需提高遮罩层级。
