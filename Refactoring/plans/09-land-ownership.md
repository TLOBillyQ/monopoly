# 地块购买与租金结算完整性

本 ExecPlan 是活文档，`Progress`、`Surprises & Discoveries`、`Decision Log`、`Outcomes & Retrospective` 必须随执行进度持续更新。

本仓库的 ExecPlan 规范位于 `.agent/PLANS.md`，执行与维护必须遵循该文件要求。

## Purpose / Big Picture

完成后，地块购买、租金结算、免租/强征等规则与策划案一致，且逻辑在 UI 交互与自动模式下都能稳定执行。

## Progress

- [x] (2026-01-26 19:42) 创建本 ExecPlan，拆分地块逻辑专项计划。
- [ ] (2026-01-26 19:42) 对照策划案与 `land.lua/land_actions.lua` 的规则一致性。
- [ ] (2026-01-26 19:42) 修正差异并补齐测试场景。

## Surprises & Discoveries

当前无新增记录。

## Decision Log

- Decision: 地块逻辑集中在 `land.lua` 与 `land_actions.lua`，不拆分新的中间层。
  Rationale: 规则聚合清晰，便于逐条对照策划案。
  Date/Author: 2026-01-26 / Codex

## Outcomes & Retrospective

尚未执行，暂无产出与回顾。

## Context and Orientation

地块购买、租金结算与强征/免租逻辑位于 `src/gameplay/land.lua` 与 `src/gameplay/land_actions.lua`。策划案规定了空地购买、自有加盖、他人地块租金或强征/免费卡处理流程，以及连片租金累计规则。

## Plan of Work

先逐条对照策划案地块流程与现有逻辑，确认关键判断顺序与资金变化一致。再检查“连片租金累计”与“破产触发”是否符合预期。若有差异，按最小改动调整并记录。最后在 UI 与自动模式下验证至少三种场景：空地购买、他人租金、强征/免租分支。

## Concrete Steps

    # 1) 对照策划案地块规则
    #    design/蛋仔策划案--大富翁.cleaned.txt

    # 2) 对照实现文件
    #    Refactoring/src/gameplay/land.lua
    #    Refactoring/src/gameplay/land_actions.lua

    # 3) 构造验证场景并执行

## Validation and Acceptance

执行后需满足：地块购买与租金流程与策划案一致；强征/免租分支触发正确；破产流程可被触发且清空地块。

## Idempotence and Recovery

调整集中在地块逻辑文件，可重复执行。若出现问题，回退到 `src/` 对应版本并重新覆盖。

## Artifacts and Notes

建议记录三类验证场景的日志输出，作为规则一致性的证据。

## Interfaces and Dependencies

依赖 `Refactoring/src/gameplay/land.lua`、`Refactoring/src/gameplay/land_actions.lua`，以及 `Refactoring/src/gameplay/bankruptcy_service.lua` 的破产处理。

本计划更新记录：

2026-01-26 19:42 创建本计划，原因是地块规则复杂且是胜负核心之一。
