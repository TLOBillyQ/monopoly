# UI 资源命名清单（Eggy）

本文件用于对齐 Eggitor UI 资源命名，与 `Manager/Adapter/Eggy/*` 的节点访问保持一致。你可以在 UI 资源侧按此清单改名。

## 现状说明

当前导出同时包含小写蛇形与少量中文节点名（如“玩家1底板/玩家1底板颜色”），以 `Data/UIManagerNodes.lua` 为准。UI 资源侧需保持同名，避免中间映射层。

## 基础面板

- panel_title
- panel_turn

## 基础屏与遮罩

- base_screen
- loading_screen
- loading_tip
- backgroud_rect_base
- backgroud_loading

## 玩家状态（4 人）

左下信息面板对应玩家状态区。
panel_player_*_name 为玩家名，panel_player_*_cash 为现金，panel_player_*_land_count 为地块数量，panel_player_*_detail 为总资产；panel_player_* 为面板容器，底板类节点使用中文名。

- panel_player_1
- panel_player_1_name
- panel_player_1_detail
- panel_player_1_avatar
- panel_player_1_cash
- 玩家1底板
- 玩家1底板颜色
- panel_player_2
- panel_player_2_name
- panel_player_2_detail
- panel_player_2_avatar
- panel_player_2_cash
- panel_player_2_land_count
- 玩家2底板
- 玩家2底板颜色
- panel_player_3
- panel_player_3_name
- panel_player_3_detail
- panel_player_3_avatar
- panel_player_3_cash
- panel_player_3_land_count
- 玩家3底板
- 玩家3底板颜色
- panel_player_4
- panel_player_4_name
- panel_player_4_detail
- panel_player_4_avatar
- panel_player_4_cash
- 玩家4底板
- 玩家4底板颜色

备注：当前 `UIManagerNodes.lua` 仅包含 `panel_player_2_land_count` 与 `panel_player_3_land_count`，其余玩家地块数量需在 Eggitor 侧补齐。

## 道具槽位（中下 5 格）

- item_slot_1
- item_slot_2
- item_slot_3
- item_slot_4
- item_slot_5

item_slot_* 需支持 `image_texture` 与 `disabled`，用于道具图片与点击开关。

## 主按钮

- btn_next（行动按钮）
- btn_auto（自动控制开关）

## 选择弹窗（choice modal）

- modal_choice
- choice_title
- choice_body
- choice_cancel
- choice_option1
- choice_option2
- choice_option3
- choice_option4

## 确认弹窗（popup modal）

- modal_popup
- popup_title
- popup_body
- popup_confirm
- popup_card

## 黑市与商城 UI（如有）

以下名称来自 `Manager/Adapter/Eggy/MarketUI.lua` 的当前配置：

- MarketUI.container = market_panel
- MarketUI.confirm_button = market_confirm_button
- MarketUI.cancel_button = market_cancel_button
- MarketUI.price_label = market_price_label
- MarketUI.selected_card = market_selected_card
- market_panel_backgroud
- market_panel_close
- MarketUI.item_buttons[1] = market_item_button1
- MarketUI.item_buttons[2] = market_item_button2
- MarketUI.item_buttons[3] = market_item_button3
- MarketUI.item_buttons[4] = market_item_button4
- MarketUI.item_buttons[5] = market_item_button5
- MarketUI.item_buttons[6] = market_item_button6
- MarketUI.item_buttons[7] = market_item_button7
- MarketUI.item_buttons[8] = market_item_button8
- MarketUI.item_buttons[9] = market_item_button9
- MarketUI.item_buttons[10] = market_item_button10
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
- MarketUI.icon_placeholder = market_item_containter

## 托管与自动控制事件约束

- 点击 `btn_auto` 时应触发 UIManager 点击事件，由适配层基于节点名判定动作。
- 右上“自动控制”按钮对应 `btn_auto`，文字直接写在 `btn_auto`。

## ECA 界面事件名（需在关卡内实现）

- 显示加载屏
- 隐藏加载屏
- 显示基础屏
- 隐藏基础屏

## Lua 已绑定点击事件（UIManager.EVENT.CLICK）

- btn_next
- btn_auto
- item_slot_1
- item_slot_2
- item_slot_3
- item_slot_4
- item_slot_5
- popup_confirm
- choice_cancel
- choice_option1
- choice_option2
- choice_option3
- choice_option4
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
- market_confirm_button
- market_cancel_button
- market_panel_close
