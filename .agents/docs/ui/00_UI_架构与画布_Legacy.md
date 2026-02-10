# 冻结声明

本文档为旧 UI 方案归档（Legacy），仅供历史追溯，不作为当前实现规范。
当前规范请查看同目录下不带 `_Legacy` 后缀的 V2 文档。

# UI 架构与画布

## 画布（Canvas）

系统共 6 个画布，注册于 `Data/UIManagerNodes.lua`：

| 画布名 | 代码常量 | 用途 |
|--------|---------|------|
| `基础屏` | `CANVAS_BASE` | 主界面，始终显示 |
| `通用选择屏` | `CANVAS_CHOICE` | 多选项弹窗 |
| `黑市屏` | `CANVAS_MARKET` | 黑市购买 |
| `弹窗屏` | `CANVAS_POPUP` | 单按钮通知 |
| `加载屏` | — | 初始化加载 |
| `调试屏` | `CANVAS_DEBUG` | 日志叠加层 |

### 互斥规则

- `基础屏` 始终可见，作为底层。
- `通用选择屏`、`黑市屏`、`弹窗屏` 同一时刻最多显示一个。
- `弹窗屏` 可中断 `通用选择屏` 或 `黑市屏`，关闭后恢复到被中断的画布。
- `调试屏` 独立叠加，不参与互斥。

### 切换机制

`_switch_canvas(ui, target)` 在 `UIView.lua` 中实现：

1. 遍历所有画布，隐藏非 `基础屏`、非目标、非保留 `调试屏` 的画布。
2. 发送 `显示基础屏` 事件。
3. 若目标非 `基础屏`，发送 `显示{目标}` 事件。

事件名由 `UIEvents.lua` 自动生成：`显示{画布名}` / `隐藏{画布名}`，通过 `send_to_all` 向所有 role 广播。

## 节点查询

`_query_node(name)` 通过 `UIManager.query_nodes_by_name` 按名称查找节点。名称先经过 `UIAliases.resolve` 解析别名。

### 别名映射（UIAliases.lua）

英文别名 → 实际节点名的映射用于代码中硬编码的常见引用：

| 别名 | 节点名 |
|------|--------|
| `btn_next` | `行动按钮` |
| `btn_auto` | `托管按钮` |
| `panel_turn` | `倒计时` |
| `choice_cancel` | `通用选择_取消` |
| `popup_confirm` | `弹窗确认` |
| `modal_popup` | `弹窗屏` |
| `market_panel` | `黑市屏` |
| `market_confirm_button` | `黑市购买按钮` |
| `market_cancel_button` | `关闭` |
| `market_price_label` | `售价：100` |
| `market_selected_card` | `选中卡牌` |
| `choice_option{i}` | `通用选择_选项_{0i}` |
| `item_slot_{i}` | `道具槽位{i}` |
| `panel_player_{i}_name` | `玩家{i}名字` |
| `panel_player_{i}_cash` | `玩家{i}现金` |
| `panel_player_{i}_land_count` | `玩家{i}地块数量` |
| `panel_player_{i}_detail` | `玩家{i}总资产` |
| `market_item_button{i}` | `黑市购买项{i}` |
| `market_item_label_{i}` | `道具名称{i}` |
| `market_item_frame_{i}` | `底框{i}` |

## UI 状态结构

`ui_view.build_ui_state()` 返回：

```lua
{
  -- 兼容保留，不再作为托管主状态
  auto_play = false,
  auto_interval = 0.1,
  input_blocked = false,
  debug_visible = false,
  item_slots = { "道具槽位1", ..., "道具槽位5" },
  base_hidden_nodes = { "行动按钮", "道具槽位1", ..., "道具槽位5" },
  base_hidden_labels = { "倒计时" },
  auto_control_nodes = { "托管按钮", "自动控制按钮" },
  market_active = false,
  choice = {
    root = "通用选择屏",
    title = "通用选择_标题",
    body = "通用选择_正文",
    cancel = "通用选择_取消",
    option_buttons = { "通用选择_选项_01", ..., "通用选择_选项_06" },
  },
  popup = {
    root = "弹窗屏",
    title = "弹窗标题",
    body = "弹窗正文",
    confirm = "弹窗确认",
  },
  popup_seq = 0,
  popup_return_canvas = nil,
  item_slot_item_ids_by_role = {},
}
```

运行时追加字段：`popup_active`、`choice_active`、`popup_payload`。

## 输入锁定

`ui_view.apply_input_lock(state)` 在 `input_blocked = true` 时会：

- 基础屏隐藏组进入隐藏（行动按钮、道具槽位、倒计时）
- 基础屏仍禁用 `行动按钮` 与道具槽位
- **例外**：不禁用 `托管按钮`、`自动控制按钮`
- 道具槽位 1~5
- 通用选择屏：全部选项按钮 + 取消按钮
- 黑市屏：全部购买项按钮 + 确认按钮 + 关闭按钮
- 弹窗屏：`弹窗确认`

## 模块职责一览

| 文件 | 职责 |
|------|------|
| `UIView.lua` | 画布切换、节点读写、弹窗/选择/黑市的打开与关闭 |
| `UIModel.lua` | 从 game state 构建 UI 数据模型 |
| `UIPanel.lua` | 构建回合标签、玩家状态行、自动标签的文本 |
| `UIChoice.lua` | 将 pending_choice 转为 `{ title, body, options, ... }` 视图结构 |
| `UIEventRouter.lua` | 为所有可交互节点注册 CLICK 监听，分发 intent |
| `UIEventHandlers.lua` | 注册游戏事件（移动、租金、黑市等）到日志和动画 |
| `UIEvents.lua` | 自动生成画布的显示/隐藏事件名 |
| `UIAliases.lua` | 英文别名 → 中文节点名映射 |
| `MarketLayout.lua` | 黑市节点名常量和就绪检查 |
| `MarketView.lua` | 黑市面板的刷新、选中和关闭 |

## 事件路由（UIEventRouter.lua）

所有点击通过 `_dispatch` 分发：

| 节点 | intent.type | intent 数据 |
|------|------------|-------------|
| `行动按钮` | `ui_button` | `id: "next"`, `actor_role_id` |
| `托管按钮` | `ui_button` | `id: "auto"`, `actor_role_id`（与当前回合无关） |
| `道具槽位{i}` | `ui_button` | `id: "item_slot_{i}"`, `actor_role_id`（仅 `item_phase_choice` 激活时） |
| `弹窗确认` | `popup_confirm` | — |
| `通用选择_取消` | `choice_cancel` | `choice_id`, `actor_role_id` |
| `通用选择_选项_{0i}` | `choice_select` | `choice_id`, `option_id`, `actor_role_id` |
| `黑市购买项{i}` | `market_select` | `option_id`, `actor_role_id` |
| `黑市购买按钮` | `market_confirm` | `choice_id`, `option_id`, `actor_role_id` |
| `关闭` | `choice_cancel` | `choice_id`, `actor_role_id` |
| 未适配的 EButton | — | 显示 tip `"UI 节点未适配: {name}"` |

事件权限约束：

- `next`、`item_slot_*`：`actor_role_id` 必须等于当前回合玩家。
- `auto`：不校验当前回合；仅要求 `actor_role_id` 能映射到玩家。
- 输入锁定期间，`auto` 不走拦截白名单外逻辑，可继续触发本地玩家托管切换。
