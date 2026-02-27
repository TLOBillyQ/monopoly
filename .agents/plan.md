# UINodes canvas-centric 重组 + 对齐 UIManagerNodes v2

输入依据：`.agents/research.md`（2026-02-27）。


## 目的

当前 `UINodes.lua` 按**功能角色**分组（buttons / labels / effects / choice / panel），导致同一张表内混杂不同 canvas 的节点——`buttons.action`（基础屏）与 `buttons.auto`（始终显示屏）并列，你无法从结构上判断隐藏某个 canvas 会影响哪些节点。

**重组核心**：以 **canvas 为第一维度**组织所有节点。每个 canvas group 包含 `.canvas`（屏幕名）+ 该屏幕下的全部子节点。命名前缀规则 `{屏幕}_节点名` 即为归类依据。同时对齐 UIManagerNodes v2 命名。

验收：`lua tests/internal/dep_rules.lua` → ok；`lua tests/regression.lua` → pass；搜索旧路径零匹配。


## 决策日志

（延用 research.md 已确认的 7 项决策，此处不再重复。）


## 新 UINodes.lua 结构总览

```
nodes.base              canvas="基础屏"          action_button / countdown / player panels / item_slots / action effects ...
nodes.always_show       canvas="始终显示屏"      auto_button / auto_label / auto_effect / action_log_button / action_log_label
nodes.player_choice     canvas="玩家选择屏"      title / slots[1..4]
nodes.target_choice     canvas="位置选择屏"      title / body / slots[1..6] / under
nodes.remote_choice     canvas="遥控骰子屏"      title / body / options[1..6] / cancel
nodes.building_choice   canvas="建筑升级屏"      title / body / confirm / cancel
nodes.market            canvas="黑市屏"          confirm / cancel / close / price_label / selected_card / item_buttons[10] / item_labels[10] / item_frames[10]
nodes.popup             canvas="卡牌展示屏"      title / card / dismiss_nodes
nodes.bankruptcy        canvas="破产展示屏"      text / avatar
nodes.dice              canvas="骰子屏"          spin / faces[1..6]
nodes.loading           canvas="加载屏"
nodes.debug             canvas="调试屏"

nodes.action_log        (全局节点)               label="日志" / toggle_targets={always_show.action_log_button}
nodes.canvas            (便捷查询)               base / always_show / player_choice / ... (从各组 .canvas 派生)
```


## 访问路径迁移表

所有消费端改动的核心依据。

| 旧路径 | 新路径 | 值变更 |
|---|---|---|
| `canvas.base` | `canvas.base` | 不变 |
| `canvas.player_choice` | `canvas.player_choice` | 不变 |
| `canvas.target_choice` | `canvas.target_choice` | 不变 |
| `canvas.remote_choice` | `canvas.remote_choice` | 不变 |
| `canvas.building_choice` | `canvas.building_choice` | 不变 |
| `canvas.market` | `canvas.market` | 不变 |
| `canvas.popup` | `canvas.popup` | 不变 |
| `canvas.bankruptcy` | `canvas.bankruptcy` | 不变 |
| `canvas.debug` | `canvas.debug` | 不变 |
| *(新增)* | `canvas.dice` | `"骰子屏"` |
| *(新增)* | `canvas.always_show` | `"始终显示屏"` |
| *(新增)* | `canvas.loading` | `"加载屏"` |
| `buttons.action` | `base.action_button` | `"行动按钮"` → `"基础_行动按钮"` |
| `buttons.auto` | `always_show.auto_button` | `"托管按钮"` → `"始终显示_托管按钮"` |
| `buttons.close` | `market.close` | `"关闭"` → `"黑市_关闭"` |
| `buttons.cancel` | **删除** | — |
| `buttons.building_confirm` | `building_choice.confirm` | 不变 |
| `buttons.building_cancel` | `building_choice.cancel` | 不变 |
| `buttons.remote_cancel` | `remote_choice.cancel` | 不变 |
| `labels.auto` | `always_show.auto_label` | `"托管_文本"` → `"始终显示_文本"` |
| `labels.countdown` | `base.countdown` | `"倒计时文本"` → `"基础_倒计时"` |
| `labels.no_action` | **删除**（复用 `base.action_hint`） | — |
| `effects.auto` | `always_show.auto_effect` | `"基础屏-AI托管光效"` → `"始终显示_托管按钮特效"` |
| `action_log.toggle_image` | **删除** | — |
| `action_log.toggle_button` | `always_show.action_log_button` | `"基础_行动日志按钮"` → `"始终显示_行动日志图标"` |
| `action_log.log_label` | `action_log.label` | `"日志"` 不变 |
| `action_log.toggle_targets` | `action_log.toggle_targets` | 从 2 元素缩减为 1 |
| `choice.player.root` | `player_choice.canvas` | 不变 |
| `choice.player.title` | `player_choice.title` | 不变 |
| `choice.player.body` | **删除** | — |
| `choice.player.slots` | `player_choice.slots` | 新增 `[4]` |
| `choice.player.cancel` | **删除** | — |
| `choice.target.root` | `target_choice.canvas` | 不变 |
| `choice.target.title` | `target_choice.title` | 不变 |
| `choice.target.body` | `target_choice.body` | 不变 |
| `choice.target.slots` | `target_choice.slots` | `"位置前N"` → `"位置_前N"` |
| `choice.target.under` | `target_choice.under` | `"位置脚下"` → `"位置_脚下"` |
| `choice.target.cancel` | **删除** | — |
| `choice.remote.root` | `remote_choice.canvas` | 不变 |
| `choice.remote.title` | `remote_choice.title` | 不变 |
| `choice.remote.body` | `remote_choice.body` | 不变 |
| `choice.remote.options` | `remote_choice.options` | 不变 |
| `choice.remote.cancel` | `remote_choice.cancel` | 不变 |
| `choice.building.root` | `building_choice.canvas` | 不变 |
| `choice.building.title` | `building_choice.title` | 不变 |
| `choice.building.body` | `building_choice.body` | 不变 |
| `choice.building.confirm` | `building_choice.confirm` | 不变 |
| `choice.building.cancel` | `building_choice.cancel` | 不变 |
| `popup.root` | `popup.canvas` | 不变 |
| `popup.title` | `popup.title` | 不变 |
| `popup.confirm` | **删除** | — |
| `popup.card` | `popup.card` | 不变 |
| `popup.dismiss_nodes` | `popup.dismiss_nodes` | 不变 |
| `bankruptcy.root` | `bankruptcy.canvas` | 不变 |
| `bankruptcy.text` | `bankruptcy.text` | 不变 |
| `bankruptcy.avatar` | `bankruptcy.avatar` | 不变 |
| `panel.player_name` | `base.player_name` | `"玩家%s名字"` → `"基础_玩家%s名字"` |
| `panel.player_cash` | `base.player_cash` | 同理加 `基础_` |
| `panel.player_land_count` | `base.player_land_count` | 同理 |
| `panel.player_total_assets` | `base.player_total_assets` | 同理 |
| `panel.player_avatar` | `base.player_avatar` | 同理 |
| `panel.player_color` | `base.player_color` | 同理 |


## 关键架构观察：screen 对象的解耦作用

`core.lua:build_choice_screens()` 和 `state.lua:build_ui_state()` 从 UINodes 取值构建中间 screen 对象（如 `{ key, root, title, body, option_buttons, cancel }`），下游 `openers.lua`、`PopupRenderer`、`UITouchPolicy` 等读的是这些 screen 对象而非直接读 UINodes。

**结论**：只需在 `core.lua` / `state.lua` 更新取值路径，screen 对象的字段名（`root` / `title` / `body`...）保持不变。下游只需处理被删除字段的 nil 保护。


## 文件修改清单

### M1：shared 层重写（3 文件）

**1. `src/presentation/shared/UINodes.lua`** — 全文重写为 canvas-centric 结构。

详细目标值见"新 UINodes.lua 结构总览"。要点：

- 废弃 `buttons` / `labels` / `effects` / `choice` / `panel` 五个分组
- 新建 12 个 canvas group（`base` / `always_show` / ...），每组含 `.canvas` + 子节点
- 保留 `action_log` 全局分组（`label` / `toggle_targets`）
- 保留 `canvas` 便捷查询表（从各组 `.canvas` 派生）
- `required_click_nodes()` 改为从 canvas group 取值

**2. `src/presentation/shared/UIAliases.lua`** — 别名目标值全部对齐 v2：
- `btn_next → "基础_行动按钮"`, `btn_auto → "始终显示_托管按钮"`, `panel_turn → "基础_倒计时"`
- `market_* → "黑市_*"`
- 循环：`item_slot_N → "基础_道具槽位N"`, `panel_player_N_* → "基础_玩家N*"`, `market_item_* → "黑市_*"`

**3. `src/presentation/shared/MarketLayout.lua`** — 节点名加 `黑市_` 前缀。

### M2：硬编码消除（3 文件）

**4. `src/presentation/ui/UITurnEffects.lua`**
- 引入 `ui_nodes`
- `highlight_nodes` → `ui_nodes.base.player_action_effects`
- `"基础_星星中心爆开"` → `ui_nodes.base.action_hint_effect`
- `"基础_行动提示"` → `ui_nodes.base.action_hint`
- `"基础_其他玩家行动提示"` → `ui_nodes.base.other_player_hint`

**5. `src/presentation/render/ActionAnim.lua`**
- 删除 `dice_screen_nodes` 局部表，引入 `ui_nodes`，传 `ui_nodes.dice` 给 handlers

**6. `src/presentation/render/ActionAnimDice.lua`**
- 移除 `fx_end_1` / `fx_end_2` 全部 4 处引用

### M3：状态构建层（3 文件）

**7. `src/presentation/api/ui_view_service/core.lua`** — `build_choice_screens()` 路径迁移。screen 对象字段名不变，但取值源从 `choice.X.*` 改为 `X_choice.*`：
- `ui_nodes.choice.player.root` → `ui_nodes.player_choice.canvas`
- `ui_nodes.choice.player.title` → `ui_nodes.player_choice.title`
- 删除 player 的 `body` 和 `cancel`
- `ui_nodes.choice.target.root` → `ui_nodes.target_choice.canvas`
- 删除 target 的 `cancel`
- remote/building 同理迁移路径
- `action_log.log_label` → `action_log.label`
- `canvas.debug` → 不变

**8. `src/presentation/api/ui_view_service/state.lua`**
- `item_slots` 改为直接引用 `ui_nodes.base.item_slots`（或内联复制值）
- `base_hidden_nodes` 引用 `ui_nodes.base.action_button`
- `auto_control_nodes` 引用 `ui_nodes.always_show.auto_button` + `.auto_label`
- `popup_screen`：`root` → `ui_nodes.popup.canvas`，删除 `confirm`
- `bankruptcy_screen`：`root` → `ui_nodes.bankruptcy.canvas`

**9. `src/presentation/api/ui_view_service/assets.lua`**
- `"道具槽位" .. index` → `"基础_道具槽位" .. index`
- `ui_nodes.panel.player_color` → `ui_nodes.base.player_color`

### M4：消费端适配（10 文件）

**10. `src/presentation/interaction/UIEventBindings.lua`**
- 移除 `toggle_image` 的 3 个 if 分支日志，更新 `toggle_button` 引用为 `always_show.action_log_button`

**11. `src/presentation/interaction/UITouchPolicy.lua`**
- `buttons.auto` → `always_show.auto_button`
- fallback 移除 `toggle_image`，`toggle_button` → `always_show.action_log_button`

**12. `src/presentation/interaction/UIInputLockPolicy.lua`**
- `buttons.action` → `base.action_button`
- 移除 2 处 `popup_screen.confirm` 逻辑

**13. `src/presentation/interaction/intent_builders/BasicIntents.lua`**
- `buttons.action` → `base.action_button`
- `buttons.auto` → `always_show.auto_button`
- `buttons.close` → `market.close`
- 删除 `buttons.cancel` route spec 整块
- `buttons.building_confirm` → `building_choice.confirm`
- `buttons.building_cancel` → `building_choice.cancel`
- `buttons.remote_cancel` → `remote_choice.cancel`

**14. `src/presentation/interaction/intent_builders/ChoiceIntents.lua`**
- `choice.player.slots` → `player_choice.slots`
- `choice.target.slots` → `target_choice.slots`
- `choice.target.under` → `target_choice.under`
- `choice.remote.options` → `remote_choice.options`

**15. `src/presentation/ui/UIPanelPresenter.lua`**
- `panel.*` → `base.*`（6 处 format 调用）
- `buttons.auto` / `buttons.action` → `always_show.auto_button` / `base.action_button`
- `labels.auto` / `labels.countdown` → `always_show.auto_label` / `base.countdown`
- `labels.no_action` → `base.action_hint`（复用，仅 no_action_visible==true 时操作）
- `effects.auto` → `always_show.auto_effect`

**16. `src/presentation/ui/PopupRenderer.lua`**
- 删除第 163 行 `ui:set_button(popup.confirm, ...)`

**17. `src/presentation/ui/choice_screen_service/openers.lua`**
- `open_player_or_remote_screen`：`body` / `cancel` 改为 nil 保护
- `open_target_screen`：删除 cancel 块

**18. `src/presentation/api/UIViewService.lua`**
- `labels.countdown` → `base.countdown`

**19. `src/presentation/interaction/intent_builders/ItemSlotIntents.lua`**
- fallback `"道具槽位N"` → `"基础_道具槽位N"`

### 不需修改

- `UIEvents.lua` — 动态扫描 UIManagerNodes
- `UICanvasCoordinator.lua` — 读 `ui_nodes.canvas.*`，便捷表保留
- `ActionLogIntents.lua` — 仅读 `toggle_targets`，路径不变
- `PopupIntents.lua` / `MarketIntents.lua` — 读 screen 对象，间接引用
- `status3d_service/meta.lua` — 直接读 `Data.UIManagerNodes`
- `UIBootstrap.lua` — 调用 `required_click_nodes()`，签名不变


## 执行顺序

M1 → M2 → M3 → M4 → 验证。每个里程碑独立可回退。


## 验证

```
lua tests/internal/dep_rules.lua       → dep_rules ok
lua tests/regression.lua               → All regression checks passed
```

残留搜索（预期零匹配）：
```
nodes\.buttons    nodes\.labels    nodes\.effects    nodes\.panel    nodes\.choice
"行动按钮"  "托管按钮"  "取消按钮"  倒计时时钟  倒计时文本
售价：100  "选中卡牌"  AI托管光效  玩家选择_副标题  基础_无法行动
骰子-骰子  骰子-旋转骰  骰子-摇
```
