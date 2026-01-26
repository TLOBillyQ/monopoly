# UI 资源命名清单（Eggy）

本文件用于对齐 Eggitor UI 资源命名，与 `src/adapters/eggy/*` 的节点访问保持一致。你可以在 UI 资源侧按此清单改名。

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

- panel_player_1
- panel_player_1_detail
- panel_player_2
- panel_player_2_detail
- panel_player_3
- panel_player_3_detail
- panel_player_4
- panel_player_4_detail

## 格子详情

- panel_tile_title
- tile_detail_name
- tile_detail_price
- tile_detail_level
- tile_detail_owner
- tile_detail_roadblock
- tile_detail_mine

## 主按钮

- btn_next
- btn_auto
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

以下名称来自 `src/adapters/eggy/market_ui.lua` 的配置，需要 UI 资源中存在：

- MarketUI.container
- MarketUI.confirm_button
- MarketUI.cancel_button（若使用）
- MarketUI.icon_placeholder（默认值 icon_placeholder）

## 托管/自动控制事件约束

- 点击 `btn_auto` 时，UI 事件 payload 中应带 `id="auto"` 或 `button_id="auto"`，用于触发自动控制切换。
