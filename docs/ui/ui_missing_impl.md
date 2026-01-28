# UI 节点缺失实现清单

本清单以 `Data/ui_data.lua` 为事实来源，结合适配层已使用节点生成。

## 复现命令

在仓库根目录运行：

    lua tests/ui_missing_impl_audit.lua

## ui_data 有但适配未使用

以下节点在 ui_data 中存在，但适配层未使用（包含装饰节点与基础画布节点）：

- backgroud_loading (EImage)
- backgroud_rect_base (EImage)
- base_screen (ECanvas)
- loading_screen (ECanvas)
- loading_tip (ELabel)
- market_panel_backgroud (EImage)
- panel_player_1 (EImage)
- panel_player_1_avatar (EImage)
- panel_player_2 (EImage)
- panel_player_2_avatar (EImage)
- panel_player_3 (EImage)
- panel_player_3_avatar (EImage)
- panel_player_4 (EImage)
- panel_player_4_avatar (EImage)
- popup_card (EImage)
- 玩家1底板 (EImage)
- 玩家1底板颜色 (EImage)
- 玩家2底板 (EImage)
- 玩家2底板颜色 (EImage)
- 玩家3底板 (EImage)
- 玩家3底板颜色 (EImage)
- 玩家4底板 (EImage)
- 玩家4底板颜色 (EImage)
- 自动控制按钮 (ELabel)

## 适配使用但 ui_data 缺失

以下节点被适配层使用，但 ui_data 不存在：

- 无

## 别名映射

当前审计未发现别名命中项。

## 缺省提示

适配层已对缺失节点增加一次性提示：

- `src/adapters/eggy/eggy_layer_ui.lua`：设置文本/可见性时找不到节点会提示。
- `src/adapters/eggy/eggy_runtime.lua`：对未注册的按钮事件绑定缺省提示。
