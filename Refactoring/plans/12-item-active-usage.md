# 主动使用类道具卡

本 ExecPlan 是活文档，`Progress`、`Surprises & Discoveries`、`Decision Log`、`Outcomes & Retrospective` 必须随执行进度持续更新。

本仓库的 ExecPlan 规范位于 `.agent/PLANS.md`，执行与维护必须遵循该文件要求。

## Purpose / Big Picture

完成后，所有“主动使用”的道具卡在 UI/逻辑层的触发时机与效果一致，且用户选择、目标选择与取消路径完整可用。

## Progress

- [x] (2026-01-26 19:48) 创建本 ExecPlan，拆分主动道具专项计划。
- [ ] (2026-01-26 19:48) 列出主动类道具清单并对照实现路径。
- [ ] (2026-01-26 19:48) 验证 UI 选择与效果触发。

## Surprises & Discoveries

当前无新增记录。

## Decision Log

- Decision: 主动道具仍通过 `item_executor.lua` + `choice_handlers/*` 的现有结构实现。
  Rationale: 保持现有流程与 choice 机制一致，避免新增分支。
  Date/Author: 2026-01-26 / Codex

## Outcomes & Retrospective

尚未执行，暂无产出与回顾。

## Context and Orientation

主动道具主要包括：路障、地雷、怪兽、导弹、均富、流放、查税、请神、送神、穷神、财神、天使等（以 `config/items.lua` 的 `timing` 与 `usage` 字段为准）。实际执行路径由 `item_executor.lua`、`item_post_effects.lua` 与 `choice_handlers/item_choice_handler.lua` 负责，部分道具需目标选择或区域选择。

## Plan of Work

先从 `config/items.lua` 提取所有 `timing = "manual"`（以及需要用户确认的其它主动时机）清单，逐一对照其在 `item_executor.lua` 与 `item_post_effects.lua` 中的实现路径。然后验证每种道具有可用的 choice 弹窗或直接效果入口，并覆盖“取消/放弃”路径。最后确认 AI 使用主动道具时不会卡死。

## Concrete Steps

    # 1) 列出主动类道具
    #    Refactoring/src/config/items.lua

    # 2) 对照执行路径
    #    Refactoring/src/gameplay/item_executor.lua
    #    Refactoring/src/gameplay/item_post_effects.lua
    #    Refactoring/src/gameplay/choice_handlers/item_choice_handler.lua

    # 3) 验证 UI 选择与取消路径

## Validation and Acceptance

执行后需满足：所有主动道具均可在 UI 中触发；需要目标选择的道具会弹出选择界面；取消/放弃路径能回到正确流程；AI 使用主动道具不阻塞回合。

## Idempotence and Recovery

调整集中在道具执行与 choice 处理，可重复执行。若出现异常，回退到 `src/` 对应实现并重新覆盖。

## Artifacts and Notes

建议输出“主动道具清单 + 执行路径”对照表作为证据。

## Interfaces and Dependencies

依赖 `Refactoring/src/gameplay/item_executor.lua`、`Refactoring/src/gameplay/item_post_effects.lua`、`Refactoring/src/gameplay/choice_handlers/item_choice_handler.lua` 与 UIManager 的 choice 弹窗接口。

本计划更新记录：

2026-01-26 19:48 创建本计划，原因是主动道具涉及大量交互与选择流程。
