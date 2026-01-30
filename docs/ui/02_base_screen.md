# 基础屏（base_screen）

主界面 HUD 与棋盘表现层入口。节点名来自 `UIManagerNodes.lua` 与 `docs/ui_naming_list.md`。

## 结构建议

base_screen（ECanvas）
- backgroud_rect_base（EImage，背景）
- panel_title（ELabel）
- panel_turn（ELabel）
- panel_player_1（EImage，面板容器）
  - panel_player_1_name（ELabel，玩家名）
  - panel_player_1_detail（ELabel，总资产）
  - panel_player_1_avatar（EImage，头像）
  - panel_player_1_cash（ELabel）
  - 玩家1底板（EImage，可选装饰）
  - 玩家1底板颜色（EImage，可选装饰）
- panel_player_2（EImage，面板容器）
  - panel_player_2_name（ELabel，玩家名）
  - panel_player_2_detail（ELabel，总资产）
  - panel_player_2_avatar（EImage，头像）
  - panel_player_2_cash（ELabel）
  - panel_player_2_land_count（ELabel）
  - 玩家2底板（EImage，可选装饰）
  - 玩家2底板颜色（EImage，可选装饰）
- panel_player_3（EImage，面板容器）
  - panel_player_3_name（ELabel，玩家名）
  - panel_player_3_detail（ELabel，总资产）
  - panel_player_3_avatar（EImage，头像）
  - panel_player_3_cash（ELabel）
  - panel_player_3_land_count（ELabel）
  - 玩家3底板（EImage，可选装饰）
  - 玩家3底板颜色（EImage，可选装饰）
- panel_player_4（EImage，面板容器）
  - panel_player_4_name（ELabel，玩家名）
  - panel_player_4_detail（ELabel，总资产）
  - panel_player_4_avatar（EImage，头像）
  - panel_player_4_cash（ELabel）
  - 玩家4底板（EImage，可选装饰）
  - 玩家4底板颜色（EImage，可选装饰）
- item_slot_1（建议可点击）
- item_slot_2（建议可点击）
- item_slot_3（建议可点击）
- item_slot_4（建议可点击）
- item_slot_5（建议可点击）
- btn_next（EButton）
- btn_auto（EButton）

基础屏不再包含 tile_1..tile_45 或格子详情面板节点，棋盘格子与覆盖物由场景单位渲染。
当前 ui_data 仅导出 `panel_player_2_land_count` 与 `panel_player_3_land_count`，其余玩家地块数量需在 Eggitor 侧补齐并重新导出。

## 文本刷新来源

- `EggyLayerUI.refresh_panel`（`Manager/TurnManager/GUI/UIState.lua`）：
  - panel_title
  - panel_turn
  - panel_player_1_name
  - panel_player_1_detail（总资产）
  - panel_player_1_cash
  - panel_player_1_land_count
  - panel_player_2_name
  - panel_player_2_detail（总资产）
  - panel_player_2_cash
  - panel_player_2_land_count
  - panel_player_3_name
  - panel_player_3_detail（总资产）
  - panel_player_3_cash
  - panel_player_3_land_count
  - panel_player_4_name
  - panel_player_4_detail（总资产）
  - panel_player_4_cash
  - panel_player_4_land_count
  - btn_next
  - btn_auto
- `EggyLayerUI.refresh_item_slots`（`Manager/TurnManager/GUI/UIState.lua`）：
  - item_slot_1（图片纹理/点击开关）
  - item_slot_2（图片纹理/点击开关）
  - item_slot_3（图片纹理/点击开关）
  - item_slot_4（图片纹理/点击开关）
  - item_slot_5（图片纹理/点击开关）

说明：panel_player_*_name 为玩家名，panel_player_*_cash 为现金，panel_player_*_land_count 为地块数量，panel_player_*_detail 为总资产。头像与底图类节点在 Eggitor 侧配置，运行时不刷新图片。

道具槽位需支持 `image_texture` 与 `disabled` 属性，图片使用道具贴图，空槽位显示“空”贴图并禁用点击。

## 点击事件（当前已注册）

- btn_next -> `ui_button` id=next
- btn_auto -> `ui_button` id=auto
- item_slot_1 -> `ui_button` id=item_slot_1
- item_slot_2 -> `ui_button` id=item_slot_2
- item_slot_3 -> `ui_button` id=item_slot_3
- item_slot_4 -> `ui_button` id=item_slot_4
- item_slot_5 -> `ui_button` id=item_slot_5

## 点击事件（预留，默认未注册）

- panel_* 等
