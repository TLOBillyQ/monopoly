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

## 格子详情

- panel_tile_title
- tile_detail_name
- tile_detail_price
- tile_detail_level
- tile_detail_owner
- tile_detail_roadblock
- tile_detail_mine

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

## 棋盘格子文本

- tile_1 … tile_N（N 为棋盘格子数，与 `src/adapters/core/presenter.lua` 的 BOARD_TILES 数量一致）

## 黑市/商城 UI（如有）

以下名称来自 `src/adapters/eggy/market_ui.lua` 的当前配置：

- MarketUI.container = market_panel
- MarketUI.confirm_button = market_confirm_button
- MarketUI.cancel_button = market_cancel_button
- MarketUI.price_label = market_price_label
- MarketUI.selected_card = market_selected_card
- MarketUI.item_buttons = market_item_button_1…10
- MarketUI.item_labels = market_item_label_1…10
- MarketUI.item_frames = market_item_frame_1…10
- MarketUI.icon_placeholder = market_icon_placeholder

## 托管/自动控制事件约束

- 点击 `btn_auto` 时应触发 UIManager 点击事件，由适配层基于节点名判定动作。
- 右上“自动控制”按钮对应 `btn_auto`，文字节点使用 `btn_auto_label`。
