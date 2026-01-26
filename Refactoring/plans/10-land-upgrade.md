# 地块加盖与建筑表现

本 ExecPlan 是活文档，`Progress`、`Surprises & Discoveries`、`Decision Log`、`Outcomes & Retrospective` 必须随执行进度持续更新。

本仓库的 ExecPlan 规范位于 `.agent/PLANS.md`，执行与维护必须遵循该文件要求。

## Purpose / Big Picture

完成后，地块加盖次数、费用、租金与建筑表现规则完整一致，且加盖动作能触发对应的 UI/表现占位或动画入口。

## Progress

- [x] (2026-01-26 19:44) 创建本 ExecPlan，拆分地块加盖专项计划。
- [ ] (2026-01-26 19:44) 核对加盖费用与租金公式是否与策划案一致。
- [ ] (2026-01-26 19:44) 验证加盖 3 次的上限与建筑表现触发。

## Surprises & Discoveries

当前无新增记录。

## Decision Log

- Decision: 加盖费用与租金规则以 `tiles.lua` 的配置为准，并保持 `land_pricing.lua` 作为唯一计算入口。
  Rationale: 数据驱动，便于未来从设计表直接更新。
  Date/Author: 2026-01-26 / Codex

## Outcomes & Retrospective

尚未执行，暂无产出与回顾。

## Context and Orientation

加盖逻辑由 `land.lua` 调用 `land_pricing.lua` 计算升级费用与租金。策划案要求最多加盖 3 次（房屋、别墅、高楼），并给出了费用/租金公式。建筑表现需在 UI/表现层显示。

## Plan of Work

先对照策划案中的公式与 `Refactoring/src/config/tiles.lua` 的 `upgrade_costs` / `rents`，确认数据一致。再验证 `land.lua` 的加盖上限逻辑与提示行为。最后为加盖结果提供 UI/表现触发点（可以先用日志或 intent 占位）。

## Concrete Steps

    # 1) 对照策划案与 tiles 配置
    #    design/蛋仔策划案--大富翁.cleaned.txt
    #    Refactoring/src/config/tiles.lua

    # 2) 检查加盖逻辑
    #    Refactoring/src/gameplay/land.lua
    #    Refactoring/src/gameplay/land_pricing.lua

    # 3) 增加加盖表现触发点（intent/日志占位）

## Validation and Acceptance

执行后需满足：加盖最多 3 次；费用与租金与配置一致；加盖动作能触发可观察的表现入口。

## Idempotence and Recovery

修改集中在配置与加盖逻辑，重复执行不应引入副作用。若出现异常，回退至 `src/` 对应版本。

## Artifacts and Notes

建议输出一条示例地块的“加盖费用/租金阶梯”验证记录。

## Interfaces and Dependencies

依赖 `Refactoring/src/config/tiles.lua` 与 `Refactoring/src/gameplay/land_pricing.lua`；表现层触发通过 intent 或 UIManager 接口实现。

本计划更新记录：

2026-01-26 19:44 创建本计划，原因是加盖规则与表现需要单独验证。
