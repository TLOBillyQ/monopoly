# 基础屏（base_screen）

主界面 HUD 与棋盘表现层入口。节点名来自 `ui_data.lua` 与 `docs/ui_naming_list.md`。

## 结构建议

base_screen（ECanvas）
- background_rect（EImage，背景）
- panel_title（ELabel）
- panel_turn（ELabel）
- panel_current_title（ELabel）
- panel_current_name（ELabel）
- panel_current_role（ELabel）
- panel_current_phase（ELabel）
- panel_players_title（ELabel）
- panel_player_1（ELabel）
  - panel_player_1_detail（ELabel，总资产）
  - panel_player_1_info（EImage，可选底图）
  - panel_player_1_avatar（EImage，头像）
  - panel_player_1_cash（ELabel）
  - panel_player_1_land_count（ELabel）
  - panel_player_1_base（EImage，可选装饰）
  - panel_player_1_base_color（EImage，可选装饰）
- panel_player_2（ELabel）
  - panel_player_2_detail（ELabel，总资产）
  - panel_player_2_info（EImage，可选底图）
  - panel_player_2_avatar（EImage，头像）
  - panel_player_2_cash（ELabel）
  - panel_player_2_land_count（ELabel）
  - panel_player_2_base（EImage，可选装饰）
  - panel_player_2_base_color（EImage，可选装饰）
- panel_player_3（ELabel）
  - panel_player_3_detail（ELabel，总资产）
  - panel_player_3_info（EImage，可选底图）
  - panel_player_3_avatar（EImage，头像）
  - panel_player_3_cash（ELabel）
  - panel_player_3_land_count（ELabel）
  - panel_player_3_base（EImage，可选装饰）
  - panel_player_3_base_color（EImage，可选装饰）
- panel_player_4（ELabel）
  - panel_player_4_detail（ELabel，总资产）
  - panel_player_4_info（EImage，可选底图）
  - panel_player_4_avatar（EImage，头像）
  - panel_player_4_cash（ELabel）
  - panel_player_4_land_count（ELabel）
  - panel_player_4_base（EImage，可选装饰）
  - panel_player_4_base_color（EImage，可选装饰）
- panel_item_slots（ELabel）
  - item_slot_1（建议可点击）
  - item_slot_2（建议可点击）
  - item_slot_3（建议可点击）
  - item_slot_4（建议可点击）
  - item_slot_5（建议可点击）
- panel_log_title（ELabel）
- panel_log_body（ELabel）
- btn_next（EButton）
- btn_auto（EButton）
- btn_restart（EButton）
  - btn_auto_label（ELabel，可选文本层）
- overlay_mask（EImage，可选遮罩）

基础屏不再包含 tile_1..tile_45 或格子详情面板节点，棋盘格子与覆盖物由场景单位渲染。

## 文本刷新来源

- `EggyLayerUI.refresh_panel`：
  - panel_title
  - panel_turn
  - panel_current_title
  - panel_current_name
  - panel_current_role
  - panel_current_phase
  - panel_players_title
  - panel_player_1
  - panel_player_1_detail（总资产）
  - panel_player_1_cash
  - panel_player_1_land_count
  - panel_player_2
  - panel_player_2_detail（总资产）
  - panel_player_2_cash
  - panel_player_2_land_count
  - panel_player_3
  - panel_player_3_detail（总资产）
  - panel_player_3_cash
  - panel_player_3_land_count
  - panel_player_4
  - panel_player_4_detail（总资产）
  - panel_player_4_cash
  - panel_player_4_land_count
  - panel_log_title
  - panel_log_body
  - btn_next
  - btn_auto
  - btn_restart
- `EggyLayerUI.refresh_item_slots`：
  - item_slot_1（图片纹理/点击开关）
  - item_slot_2（图片纹理/点击开关）
  - item_slot_3（图片纹理/点击开关）
  - item_slot_4（图片纹理/点击开关）
  - item_slot_5（图片纹理/点击开关）

说明：panel_player_* 为玩家名，panel_player_*_cash 为现金，panel_player_*_land_count 为地块数量，panel_player_*_detail 为总资产。头像与底图类节点在 Eggitor 侧配置，运行时不刷新图片。

道具槽位需支持 `image_texture` 与 `disabled` 属性，图片使用道具贴图，空槽位显示“空”贴图并禁用点击。

## 点击事件（当前已注册）

- btn_next -> `ui_button` id=next
- btn_auto -> `ui_button` id=auto
- btn_restart -> `ui_button` id=restart
- item_slot_1 -> `ui_button` id=item_slot_1
- item_slot_2 -> `ui_button` id=item_slot_2
- item_slot_3 -> `ui_button` id=item_slot_3
- item_slot_4 -> `ui_button` id=item_slot_4
- item_slot_5 -> `ui_button` id=item_slot_5

## 点击事件（预留，默认未注册）

- overlay_mask、panel_* 等
