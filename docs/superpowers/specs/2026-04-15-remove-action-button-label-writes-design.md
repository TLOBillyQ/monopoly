# 彻底删除基础_行动按钮文本写入设计文档

## 目标

彻底移除代码中对 `基础_行动按钮`（`base_nodes.action_button`）的任何动态文本写入，按钮文本完全由 prefab 初始值接管。

## 影响面分析

### 生产代码（写入点）

| 文件 | 行号 | 内容 |
|------|------|------|
| `src/ui/ctl/item_slots.lua` | 264 | `item_phase_passive` 阶段写入 `"继续"` |
| `src/ui/ctl/item_slots.lua` | 268 | 非 `item_phase_passive` 阶段写入 `""` |

### 现有测试（需移除的断言）

| 文件 | 函数名 | 说明 |
|------|--------|------|
| `tests/suites/presentation/_presentation_action_status_item_slots.lua` | `_test_passive_action_button_shows_continue_label` | 断言 passive 阶段 label 为 `"继续"` |
| `tests/suites/presentation/_presentation_action_status_item_slots.lua` | `_test_non_passive_action_button_label_restored` | 断言非 passive 阶段 label 被清空为 `""` |

### 无影响的只读/控制点

以下代码只负责路由、可见性或触摸控制，不涉及 label 写入，保持不变：

- `src/ui/input/canvas_route/base.lua` — intent 路由
- `src/ui/wid/panel_presenter.lua:113` — `set_touch_enabled`
- `src/ui/input/lock_policy.lua:46` — 输入锁定的 `touch_enabled`
- 各 interaction / event binding 测试（只验证点击事件与状态机）

## 变更方案

### 1. 删除生产代码写入

在 `src/ui/ctl/item_slots.lua` 的 `refresh_item_slots` 函数中，删除以下两个 `set_label` 分支：

```lua
-- 删除开始
if ctx.ui.set_label then
  ctx.ui:set_label(base_nodes.action_button, "继续")
end
-- 删除结束

-- 删除开始
if ctx.ui.set_label then
  ctx.ui:set_label(base_nodes.action_button, "")
end
-- 删除结束
```

### 2. 移除旧测试

在 `tests/suites/presentation/_presentation_action_status_item_slots.lua` 中：

- 删除 `_test_passive_action_button_shows_continue_label` 函数
- 删除 `_test_non_passive_action_button_label_restored` 函数
- 从 `tests` 数组中移除对应的两个注册项

### 3. 新增 guard 测试

在同一测试文件中新增一个 guard 测试，覆盖 passive 和非 passive 两种场景，断言 `refresh_item_slots` 执行后 `label_state["基础_行动按钮"]` 始终为 `nil`（即未收到任何写入），防止后续回归。

## 验证计划

| 命令 | 说明 |
|------|------|
| `lua tools/quality/lint.lua` | luacheck 静态检查 |
| `lua tests/behavior.lua` | 游戏逻辑 / 运行时 / UI 行为回归 |
| `lua tests/guard.lua` | guardrail 与禁止模式检查 |

## 设计决策

- **为什么不保留 `""` 清空逻辑？** 既然目标是让 prefab 全权负责文本，代码侧不应做任何兜底。若出现残留文本，应在 prefab 或编辑器流程中解决，而非在运行时代码中打补丁。
- **为什么加 guard 测试？** 明确立下"不再写入"的契约，防止未来重构或新需求再次向 action button 写入文本。
