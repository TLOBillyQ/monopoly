# Passive 道具阶段：去除虚构节点，复用已有槽位/外框

## 背景

06724cc 引入了 `item_bubbles`（基础_道具气泡1~5）和 `item_continue_button`（基础_道具继续按钮）两组新节点定义，用于 `item_phase_passive` 阶段的气泡提醒和继续按钮。但这些节点从未在 Eggy 编辑器中创建（`Data/UIManagerNodes.lua` 中不存在），运行时实际无效。

## 目标

- 删除虚构节点引用，passive 阶段的 UI 表现全部复用已有的 `基础_道具槽位`、`基础_可出牌外框`、`基础_行动按钮`
- 保留 `item_phase_passive` kind 及其 rules/turn/AI 层逻辑不动
- 保留 `prompt_style` 和 `effect_group` 配置字段不动

## 不动的部分

- `src/config/content/items.lua` — `prompt_style`、`effect_group` 字段保留
- `src/turn/phases/registry.lua` — `used_effect_groups` 清空逻辑保留
- `src/rules/items/phase.lua` — `build_passive_choice_spec`、`_run_player_phase` 保留（仅微调 spec 字段）
- `src/rules/items/availability.lua` — `effect_group` 检查保留
- `src/rules/choice_handlers/item.lua` — `item_phase_passive` handler 保留
- `src/turn/actions/validator.lua` — passive 适配保留
- `src/computer/agent/decision_engine.lua` — AI passive 分支保留

## 改动清单

### 1. `src/ui/schema/base_nodes.lua` — 删除虚构节点

删除 `item_bubbles` 和 `item_continue_button` 两个字段。

### 2. `src/ui/ctl/item_slots.lua` — 统一渲染路径

- 删除 `_hide_passive_ui` 函数（引用 `base_nodes.item_bubbles` 和 `base_nodes.item_continue_button`）
- 删除 `_refresh_passive_slots` 函数（气泡+继续按钮渲染）
- `refresh_item_slots` 中 `item_phase_passive` 分支改为走 `_refresh_highlight_state`（与其他 choice kind 相同的 outline 高亮路径）
- 新增：passive 阶段设置行动按钮可见、可点击、文案改为"继续"
- 非 passive 阶段恢复行动按钮为原始状态

### 3. `src/ui/input/canvas_route_base.lua` — 行动按钮 intent 分流

`build_intent` 增加判断：当前 choice kind 为 `item_phase_passive` 时，返回 `{ type = "choice_cancel" }` 而非 `{ type = "ui_button", id = "next" }`。需要读取 `runtime_state.get_ui_model(state)` 来获取当前 choice。

### 4. `src/ui/input/canvas_route_item_slots.lua` — 删除继续按钮 intent

删除 `nodes.item_continue_button` 相关的 intent 注册块（约 42~49 行）。

### 5. `src/rules/items/phase.lua` — choice spec 精简

`build_passive_choice_spec` 返回值中：
- 删除 `show_continue_button` 字段
- 删除 `continue_label` 字段
- `slot_states` 中保留 `available` 字段，`alert` 和 `alert_text` 保留（`prompt_style` 配置仍在，将来可能消费）

### 6. 测试更新

`tests/suites/presentation/_presentation_action_status_item_slots.lua`：
- 删除 `_test_passive_slot_bubbles_shown_for_alert_slots` 用例
- 删除 `_test_non_passive_choice_hides_bubbles_and_continue_button` 用例
- 新增：验证 passive 阶段 outlines 按 `slot_states.available` 高亮
- 新增：验证 passive 阶段行动按钮文案为"继续"且可点击
- 新增：验证非 passive 阶段行动按钮文案恢复

## 槽位视觉状态（改后）

| 状态 | 视觉 | 交互 |
|------|------|------|
| 可用 | outline 高亮 | 可点击 |
| 不可用 | 无 outline | 不响应 |

alert 和 passive 不做视觉区分，统一用 outline 高亮表示可用。

## 阶段流程（改后）

```
阶段开始 → rules 计算 slot_states → 下发 kind="item_phase_passive"
  ├─ UI 高亮可用槽位 outline + 行动按钮显示"继续"
  ├─ 玩家点槽位 → 直接执行 → 刷新 slot_states → 继续等待
  ├─ 玩家点行动按钮（"继续"） → choice_cancel → 结束阶段
  └─ 无可用卡 → 跳过整个阶段
```

## 涉及文件汇总

| 文件 | 操作 |
|------|------|
| `src/ui/schema/base_nodes.lua` | 删除 2 个字段 |
| `src/ui/ctl/item_slots.lua` | 删除 2 个函数，改 1 个函数 |
| `src/ui/input/canvas_route_base.lua` | 改 intent 分流 |
| `src/ui/input/canvas_route_item_slots.lua` | 删除继续按钮 intent 块 |
| `src/rules/items/phase.lua` | 删除 2 个 spec 字段 |
| `tests/suites/presentation/_presentation_action_status_item_slots.lua` | 替换测试用例 |
