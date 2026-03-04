# UIManagerNodes 改版接入研究（黑市与位置选择）

本文件记录对 `Data/UIManagerNodes.lua` 新版节点的接入分析与落地建议，不包含代码修改。

## 1. 研究范围

- 输入：`Data/UIManagerNodes.lua`（你新改版）
- 现有接入层：
  - `src/presentation/shared/MarketLayout.lua`
  - `src/presentation/canvas/market/nodes.lua`
  - `src/presentation/canvas/market/intents.lua`
  - `src/presentation/render/MarketView.lua`
  - `src/presentation/ui/MarketModalRenderer.lua`
  - `src/presentation/canvas/target_choice/nodes.lua`
  - `src/presentation/ui/choice_screen_service/openers.lua`
  - `src/presentation/interaction/UIEventBindings.lua`
- 业务约束层：
  - `src/game/systems/market/service/Choice.lua`
  - `src/game/systems/choices/ChoiceResolver.lua`
  - `src/game/systems/choices/ChoiceHandlers/MarketChoiceHandler.lua`

## 2. 节点变更快照（与旧版对比）

`UIManagerNodes.lua` 从 `171` 增至 `197`（新增 26 个节点）。

新增节点分两组：

- 黑市新增交互（5 个）
  - `黑市-上一页箭头`
  - `黑市-下一页箭头`
  - `黑市-道具商店按钮`
  - `黑市-皮肤商店按钮`
  - `黑市-坐骑商店按钮`

- 位置选择新增槽位节点（21 个，7 槽位 x 按钮/文本/投影）
  - `位置-槽位1..7按钮`
  - `位置-槽位1..7文本`
  - `位置-槽位1..7投影`

## 3. 当前接入现状

### 3.1 黑市已接入的节点

当前黑市主链路已接入以下节点并可工作：

- 面板：`黑市屏`
- 商品槽：`黑市_购买项1..10`、`黑市_道具名称1..10`、`黑市_底框1..10`
- 主操作：`黑市_购买按钮`、`黑市_关闭`
- 展示：`黑市_售价`、`黑市_选中卡牌`

对应实现位置：`MarketLayout.lua`、`canvas/market/nodes.lua`、`MarketView.lua`、`market/intents.lua`。

### 3.2 黑市未接入的新增节点

以下新增按钮目前没有业务路由：

- `黑市-上一页箭头`
- `黑市-下一页箭头`
- `黑市-道具商店按钮`
- `黑市-皮肤商店按钮`
- `黑市-坐骑商店按钮`

说明：

- 代码里没有任何 `黑市-` 前缀节点引用。
- `UIEventBindings.register_missing_button_tip` 会给“未路由的 EButton”挂兜底提示（点击后显示“UI 节点未适配”）。

### 3.3 位置选择未接入的新增槽位节点

当前 `target_choice` 仍是“标题 + 文本 + 确认/取消”的旧接入模型：

- `src/presentation/canvas/target_choice/nodes.lua` 仅定义
  - `位置选择屏`
  - `位置_副标题`
  - `位置_放置文本`
  - `位置_确认按钮`
  - `位置_取消按钮`

新增的 `位置-槽位*` 三类节点未被读取，事件也未绑定。

## 4. 关键架构约束（为什么不能只改前端）

黑市确认流程走 `choice_select`，而 `ChoiceResolver._option_exists` 会严格校验 `option_id` 必须在 `pending_choice.options` 中。

现状 `market/service/Choice.lua` 只构造最多 10 条可见项（`build_visible_entries(..., 10)`）。

这意味着：

- 如果要让“分页/分类按钮”切到更多商品，不能只在 presentation 做假分页。
- 后端 `market choice` 结构必须同步扩展（提供全量可翻页数据，或分页状态驱动的重建 choice）。

## 5. 接入方案建议（按现架构最稳妥）

### 5.1 黑市分页/分类按钮接入

建议采用“后端驱动分页/分类，前端只渲染状态”的方案：

1. 扩展 market 节点定义
- 在 `src/presentation/canvas/market/nodes.lua` 与 `src/presentation/shared/MarketLayout.lua` 增加：
  - `page_prev` / `page_next`
  - `tab_item` / `tab_skin` / `tab_vehicle`

2. 扩展事件意图
- 在 `src/presentation/canvas/market/intents.lua` 新增意图：
  - `market_page_prev`
  - `market_page_next`
  - `market_tab_select`（参数：tab）

3. 扩展 UI->游戏分发
- 在 `UIIntentDispatcher` / Turn action 路由增加上述 intent 的处理。
- 处理策略建议为“更新 choice 状态并重建 market choice”，而非前端本地拼接。

4. 扩展 game 侧 choice 结构
- `market/service/Choice.lua` 输出应包含：
  - `active_tab`
  - `page_index`
  - `page_count`
  - 当前页 `options`
- 所有可确认 `option_id` 必须来自当前 `pending_choice.options`，保持 `ChoiceResolver` 契约不变。

5. 兼容保底
- 若新字段缺失，前端回退当前行为（仅 10 项列表 + 关闭按钮可用）。

### 5.2 位置选择槽位接入

如果你的新 UI 目标是“直接点槽位完成目标选择”，建议如下：

1. 扩展 `target_choice` 节点模型
- 在 `src/presentation/canvas/target_choice/nodes.lua` 增加：
  - `slot_buttons[1..7]`
  - `slot_labels[1..7]`
  - `slot_projections[1..7]`

2. 扩展 `choice_screens.target`
- 在 `ui_view_service/core.lua` 的 `build_choice_screens()` 把槽位按钮纳入 `option_buttons`。

3. 扩展 open_target_screen 渲染
- `choice_screen_service/openers.lua` 把 option 映射到 7 槽位节点。
- 保持 confirm/cancel 锁定语义（可复用现有 `target_lock/target_unlock`）。

4. 保留双路径
- 继续兼容原有场景点击选目标（3D 交互），避免硬切导致回归。

## 6. 风险与注意项

- `黑市-坐骑商店按钮` 文案是“坐骑”，而业务内部枚举是 `kind="vehicle"` / “座驾商店”；建议只做显示映射，不改业务枚举。
- `黑市_取消按钮` 与 `黑市_关闭` 同时存在：目前逻辑只接了 `黑市_关闭`。如果设计稿要求两者行为不同，需要在 `market/intents.lua` 明确区分。
- 新按钮未接入前，点击会触发“UI 节点未适配”提示，这是当前机制预期，不是引擎异常。

## 7. 最小验收建议

- 黑市：
  - 点击分类/翻页按钮能触发明确意图并切换列表。
  - 任何可购买项点击确认都能通过 `ChoiceResolver._option_exists`。
- 位置选择：
  - 点槽位可进入锁定态，确认后产生正确 `choice_select`。
  - cancel 解锁行为与现有路径一致。
- 回归：
  - `lua tests/regression.lua`
  - `presentation_ui`、`market` 定向 suite 全绿。
