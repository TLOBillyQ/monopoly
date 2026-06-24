---
kind: adr
status: stable
owner: architecture
last_verified: 2026-06-24
---
# ADR 0018 — 可选行动阶段完成归属 turn seam

## 背景

`CONTEXT.md` 已裁定：`结束按钮` 表示当前玩家完成 `可选行动阶段`，不是结束整个回合；倒计时到期等价于结束按钮。当前实现和验收面容易让 UI 点击、timer 超时、acceptance step 分别接触 action id、`choice_cancel`、pending choice、按钮可用性和等待态细节，导致同一个领域意图分散在多个入口。

## 决策

在 `turn` 层引入一个深 module 表达领域意图：**完成可选行动阶段**。它的外部 seam 是 turn-flow interface，而不是 UI、timer 或 acceptance。

该 module 至少承担两类入口：

- 查询：当前玩家是否可以完成可选行动阶段，并返回稳定 reason。
- 命令：当前玩家完成可选行动阶段，并返回结构化结果。

具体函数名和参数形状由实现阶段决定，但 interface 必须保持领域语言，不能要求 caller 传 UI 控件 id、acceptance 文案、`choice_cancel` 等低层细节。推荐形状为 `can_complete_optional_action_phase(game, actor_id)` 与 `complete_optional_action_phase(game, actor_id)`。

## 规则归属

该 module 内部拥有以下规则和状态推进细节：

- 当前 actor 是否为当前玩家。
- 当前是否处于可选行动阶段。
- modal、动画、detached、inter-turn wait 等状态是否阻止完成。
- pending choice 的清理与后续 turn-flow 推进。
- 倒计时到期等价于完成可选行动阶段。
- 非法调用返回稳定 reason，而不是静默 no-op。

UI 点击 `结束按钮`、timer 超时、acceptance step 都降为 adapter：只把外部事件翻译为“完成可选行动阶段”这个领域意图，然后调用同一个 turn module。它们不得平行实现 pending choice、当前玩家、按钮可用性或等待态规则。

## 影响

这个决定提高 locality：`结束按钮`、超时、验收步骤的规则变动集中在一个 turn module。它也提高 leverage：UI、timer、acceptance 和行为测试穿过同一个小 interface，避免为每个入口维护一套相近但会漂移的规则。

测试应把这个 interface 当作主要 test surface。行为测试覆盖 `can_*` 和 `complete_*` 的 reason、成功推进和阻塞条件；验收测试继续描述玩家可观察行为，但 step handler 不再复制 turn-flow 规则。

## 取舍

不把 seam 放在 UI 层：UI 只能知道按钮事件和可用性表达，不能成为 turn-flow 规则真源。

不把 seam 放在 acceptance step：acceptance 是外显行为规格，不应为了测试便利平行实现业务规则；这延续 ADR 0012 与 ADR 0017 的方向。

不让旧入口继续各自判断：删除旧判断时复杂度不会消失，而是集中进一个更深的 turn module；这通过 deletion test。
