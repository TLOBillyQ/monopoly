# UI 术语与 Eggitor 画布对应

本目录用于把 `docs/ui_naming_list.md` 的命名与 Eggitor 画布设计对齐，避免 screen 和 panel 混用。

## 术语统一

- 画布：Eggitor 的画布，对应 UIManager 的 ECanvas。项目内统一叫“画布”，不再用 screen。
- 面板：画布里的视觉分区或容器，通常由一组 panel_* 节点构成。
- 控件和节点：UIManager 直接访问的命名节点（如 btn_next、panel_title）。

## 命名约束

- 节点名大小写敏感，必须与 `ui_data.lua` 一致。
- UIManager 按名称查询只取第一个命中节点（`UIManager.query_nodes_by_name` 取 `list[1]`），所以全局不要重名。

## Eggitor 画布与节点名

- 基础屏 -> base_screen（ECanvas）
- 加载屏 -> loading_screen（ECanvas）
- 黑市屏 -> market_panel（ECanvas）
- 弹窗屏 -> modal_choice（EImage）与 modal_popup（ECanvas）两个根节点并列
  - 建议放在同一“弹窗屏”画布下，但不要互为父子，以免 visible 互相干扰。

## 显示与隐藏事件的来源

- Lua 直接控制：modal_choice、modal_popup、market_panel 的显示与隐藏由 Lua 调用 `ui:set_visible` 完成。
- ECA 事件控制：loading_screen 与 base_screen 由 ECA 场景切换。
  - 事件名：显示加载屏、隐藏加载屏、显示基础屏、隐藏基础屏（`src/adapters/eggy/eggy_runtime.lua`）。
  - 事件转发机制：`UIManager.forward_eca_event` -> 自定义事件 `ui_forward` -> ECA 读取 `get_forward_ui_event()`。
  - ECA 侧需按事件名实现具体显隐逻辑。

参考官方文档：https://u5-creator.s3.game.163.com/manual/
