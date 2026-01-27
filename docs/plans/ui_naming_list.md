# UI 资源命名清单（Eggy）

本文件用于对齐 Eggitor UI 资源命名，与 `src/adapters/eggy/*` 的节点访问保持一致。你可以在 UI 资源侧按此清单改名。

## 现状说明

当前 `ui_data.lua` 使用中文节点名，适配层通过 `src/adapters/eggy/ui_state.lua` 的映射表做兼容。以下“基础面板/按钮/弹窗”等清单仍以逻辑名为主，具体缺口以 `tests/ui_nodes_audit.lua` 输出为准。

## 已映射节点（代码 -> UI 资源名）

- btn_auto -> btn_auto
- btn_next -> btn_next
- modal_popup -> 弹窗屏
- popup_confirm -> 关闭
- panel_player_1..4 -> 玩家1名字..玩家4名字
- panel_player_1_detail..4_detail -> 玩家1总资产..玩家4总资产
- item_slot_1..5 -> item_slot_1..5

## 基础面板

- panel_title
- panel_turn
- panel_current_title
- panel_current_name
- panel_current_role
- panel_current_phase
- panel_current_dice
- panel_players_title

## 玩家状态（4 人）

左下信息面板对应玩家状态区。

- panel_player_1
- panel_player_1_detail
- panel_player_2
- panel_player_2_detail
- panel_player_3
- panel_player_3_detail
- panel_player_4
- panel_player_4_detail

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

## 棋盘格子文本

- tile_1 … tile_N（N 为棋盘格子数，与 `src/adapters/core/presenter.lua` 的 BOARD_TILES 数量一致）

## 黑市/商城 UI（如有）

以下名称来自 `src/adapters/eggy/market_ui.lua` 的当前配置：

- MarketUI.container = 黑市屏
- MarketUI.confirm_button = 黑市购买按钮
- MarketUI.cancel_button = 取消按钮
- MarketUI.price_label = 售价：100
- MarketUI.selected_card = 选中卡牌
- MarketUI.item_buttons = 黑市购买项1…10
- MarketUI.item_labels = 道具名称1…10
- MarketUI.item_frames = 底框1…10
- MarketUI.icon_placeholder = icon_placeholder

事件名（UI 资源侧触发）：

- MarketUI.item_event_prefix = 点击黑市购买项（用于拼接 1…10）
- MarketUI.confirm_event = 点击黑市购买按钮
- MarketUI.cancel_event = 点击取消按钮

## 托管/自动控制事件约束

- 点击 `btn_auto` 时，UI 事件 payload 中应带 `id="auto"` 或 `button_id="auto"`，用于触发自动控制切换。
- 右上“自动控制”按钮对应 `btn_auto`。

## 待补齐清单（来自 `tests/ui_nodes_audit.lua`）

当前审计仍缺失以下类别节点/事件（以审计脚本输出为准）：

- 基础面板：`panel_title`、`panel_turn`、`panel_current_*`、`panel_players_title`
- 道具区：`panel_item_slots`
- 格子详情：`panel_tile_title`、`tile_detail_*`
- 日志区：`panel_log_title`、`panel_log_body`
- 选择弹窗：`modal_choice`、`choice_*`
- 确认弹窗：`popup_title`、`popup_body`
- 按钮：`btn_restart`
- 棋盘文本：`tile_1..tile_45`
- 黑市事件：`点击黑市购买项`、`点击黑市购买按钮`、`点击取消按钮`
- 资源占位：`icon_placeholder`
