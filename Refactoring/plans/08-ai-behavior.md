# AI 行为与自动操作完整性

本 ExecPlan 是活文档，`Progress`、`Surprises & Discoveries`、`Decision Log`、`Outcomes & Retrospective` 必须随执行进度持续更新。

本仓库的 ExecPlan 规范位于 `.agent/PLANS.md`，执行与维护必须遵循该文件要求。

## Purpose / Big Picture

完成后，AI 行为将与策划案的优先级一致，自动模式不会卡死流程，且在道具选择、目标选择、黑市购买等环节表现可控、可复现。

## Progress

- [x] (2026-01-26 19:40) 创建本 ExecPlan，拆分 AI 行为专项计划。
- [ ] (2026-01-26 19:40) 对照策划案逐条核对 AI 优先级与触发条件。
- [ ] (2026-01-26 19:40) 补齐或调整 AI 选择逻辑并验证无死锁。

## Surprises & Discoveries

当前无新增记录。

## Decision Log

- Decision: AI 行为仅在 `src/gameplay/agent.lua` 与 `src/gameplay/item_strategy.lua` 中维护，不新增外层策略管理器。
  Rationale: 保持单一实现，避免多处逻辑漂移。
  Date/Author: 2026-01-26 / Codex

## Outcomes & Retrospective

尚未执行，暂无产出与回顾。

## Context and Orientation

AI 行为主要由 `src/gameplay/agent.lua` 与 `src/gameplay/item_strategy.lua` 负责，涉及遥控骰子、路障、偷窃、怪兽/导弹、均富/流放/查税/请神/送神/穷神等道具的目标选择与触发条件。策划案在“AI”章节明确了各道具的优先级与使用条件，需逐条对照。

## Plan of Work

先列出策划案 AI 规则与现有实现的对照表，标记缺失与差异。然后在 `Refactoring/src/gameplay/agent.lua` 与 `Refactoring/src/gameplay/item_strategy.lua` 中做最小调整，确保顺序与条件一致。最后运行一次自动模式流程，验证不会卡死或反复等待。

## Concrete Steps

在仓库根目录执行以下步骤（命令示例）：

    # 1) 读取策划案 AI 章节
    #    design/蛋仔策划案--大富翁.cleaned.txt

    # 2) 对照 AI 逻辑
    #    Refactoring/src/gameplay/agent.lua
    #    Refactoring/src/gameplay/item_strategy.lua

    # 3) 补齐差异并验证自动模式

## Validation and Acceptance

执行后需满足：AI 道具使用顺序与策划案一致；AI 不会在选择/弹窗处卡住；自动模式可连续完成多回合。

## Idempotence and Recovery

调整仅限 AI 相关文件，可重复执行。若出现异常，回退到 `src/` 对应版本并重新覆盖。

## Artifacts and Notes

建议产出“AI 行为对照表”作为证据：列出每个道具的优先级与目标选择逻辑。

## Interfaces and Dependencies

依赖 `Refactoring/src/gameplay/agent.lua`、`Refactoring/src/gameplay/item_strategy.lua`；与 UI 层通过 choice/intent 交互，不直接操作 UI 组件。

本计划更新记录：

2026-01-26 19:40 创建本计划，原因是 AI 需求在策划案中独立且较复杂，需要单独验证。
