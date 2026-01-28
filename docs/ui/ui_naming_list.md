# UI 资源命名清单（Eggy）

本文件用于对齐 Eggitor UI 资源命名，与 `src/adapters/eggy/*` 的节点访问保持一致。你可以在 UI 资源侧按此清单改名。

## 现状说明

当前命名清单以统一的小写蛇形命名为准，`ui_data.lua` 与 Eggy 适配层已直接使用这些名称，不再依赖中文映射。UI 资源侧需要保持同名，保证审计脚本可直接命中。

## 基础面板

- panel_title
- panel_turn
- panel_current_title
- panel_current_name
- panel_current_role
- panel_current_phase
- panel_current_dice
- panel_players_title

## 基础屏与遮罩

- base_screen
- loading_screen
- loading_tip
- overlay_mask
- background_rect

## 玩家状态（4 人）

左下信息面板对应玩家状态区。
panel_player_* 为玩家名，panel_player_*_cash 为现金，panel_player_*_land_count 为地块数量，panel_player_*_detail 为总资产；头像与底图类节点由 Eggitor 资源配置。

- panel_player_1
- panel_player_1_detail
- panel_player_1_info
- panel_player_1_avatar
- panel_player_1_cash
- panel_player_1_land_count
- panel_player_1_base
- panel_player_1_base_color
- panel_player_2
- panel_player_2_detail
- panel_player_2_info
- panel_player_2_avatar
- panel_player_2_cash
- panel_player_2_land_count
- panel_player_2_base
- panel_player_2_base_color
- panel_player_3
- panel_player_3_detail
- panel_player_3_info
- panel_player_3_avatar
- panel_player_3_cash
- panel_player_3_land_count
- panel_player_3_base
- panel_player_3_base_color
- panel_player_4
- panel_player_4_detail
- panel_player_4_info
- panel_player_4_avatar
- panel_player_4_cash
- panel_player_4_land_count
- panel_player_4_base
- panel_player_4_base_color

## 道具槽位（中下 5 格）

- panel_item_slots
- item_slot_1
- item_slot_2
- item_slot_3
- item_slot_4
- item_slot_5

item_slot_* 需支持 `image_texture` 与 `disabled`，用于道具图片与点击开关。

## 主按钮

- btn_next（行动按钮）
- btn_auto（自动控制开关）
- btn_restart
- btn_auto_label

## 日志区

- panel_log_title
- panel_log_body

## 选择弹窗（choice modal）

- modal_choice
- choice_title
- choice_body
- choice_cancel
- choice_option_1
- choice_option_2
- choice_option_3
- choice_option_4

## 确认弹窗（popup modal）

- modal_popup
- popup_title
- popup_body
- popup_confirm
- popup_card
- popup_confirm_alt

## 黑市与商城 UI（如有）

以下名称来自 `src/adapters/eggy/market_ui.lua` 的当前配置：

- MarketUI.container = market_panel
- MarketUI.confirm_button = market_confirm_button
- MarketUI.cancel_button = market_cancel_button
- MarketUI.price_label = market_price_label
- MarketUI.selected_card = market_selected_card
- MarketUI.item_buttons[1] = market_item_button_1
- MarketUI.item_buttons[2] = market_item_button_2
- MarketUI.item_buttons[3] = market_item_button_3
- MarketUI.item_buttons[4] = market_item_button_4
- MarketUI.item_buttons[5] = market_item_button_5
- MarketUI.item_buttons[6] = market_item_button_6
- MarketUI.item_buttons[7] = market_item_button_7
- MarketUI.item_buttons[8] = market_item_button_8
- MarketUI.item_buttons[9] = market_item_button_9
- MarketUI.item_buttons[10] = market_item_button_10
- MarketUI.item_labels[1] = market_item_label_1
- MarketUI.item_labels[2] = market_item_label_2
- MarketUI.item_labels[3] = market_item_label_3
- MarketUI.item_labels[4] = market_item_label_4
- MarketUI.item_labels[5] = market_item_label_5
- MarketUI.item_labels[6] = market_item_label_6
- MarketUI.item_labels[7] = market_item_label_7
- MarketUI.item_labels[8] = market_item_label_8
- MarketUI.item_labels[9] = market_item_label_9
- MarketUI.item_labels[10] = market_item_label_10
- MarketUI.item_frames[1] = market_item_frame_1
- MarketUI.item_frames[2] = market_item_frame_2
- MarketUI.item_frames[3] = market_item_frame_3
- MarketUI.item_frames[4] = market_item_frame_4
- MarketUI.item_frames[5] = market_item_frame_5
- MarketUI.item_frames[6] = market_item_frame_6
- MarketUI.item_frames[7] = market_item_frame_7
- MarketUI.item_frames[8] = market_item_frame_8
- MarketUI.item_frames[9] = market_item_frame_9
- MarketUI.item_frames[10] = market_item_frame_10
- MarketUI.icon_placeholder = market_icon_placeholder

## 托管与自动控制事件约束

- 点击 `btn_auto` 时应触发 UIManager 点击事件，由适配层基于节点名判定动作。
- 右上“自动控制”按钮对应 `btn_auto`，文字节点使用 `btn_auto_label`。

## ECA 界面事件名（需在关卡内实现）

- 显示加载屏
- 隐藏加载屏
- 显示基础屏
- 隐藏基础屏

## Lua 已绑定点击事件（UIManager.EVENT.CLICK）

- btn_next
- btn_auto
- btn_restart
- item_slot_1
- item_slot_2
- item_slot_3
- item_slot_4
- item_slot_5
- popup_confirm
- popup_confirm_alt
- choice_cancel
- choice_option_1
- choice_option_2
- choice_option_3
- choice_option_4
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
- market_confirm_button
- market_cancel_button
