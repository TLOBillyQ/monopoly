# 重构总控执行计划（长期运行）

本 ExecPlan 是活文档，`Progress`、`Surprises & Discoveries`、`Decision Log`、`Outcomes & Retrospective` 必须随执行进度持续更新。

本仓库的 ExecPlan 规范位于 `.agent/PLANS.md`，执行与维护必须遵循该文件要求。

## Purpose / Big Picture

该计划用于把所有子计划串联起来，形成一条可长期推进的执行主线。完成后，重构版本 `./Refactoring` 将具备完整、可运行、可验证的 Eggy 适配版本，满足 `design/` 的需求基线与 `plans/prepare_plan.md` 的完整性对照。

## Progress

- [x] (2026-01-26 19:55) 创建总控计划，定义长期执行节奏与子计划依赖。
- [x] (2026-01-26 11:42) 完成 01-structure-bootstrap.md - 重构目录与基线骨架。
- [ ] (2026-01-26 11:42) 执行 02-data-config-port.md - 设计数据与配置同步。
- [ ] 继续执行剩余子计划（03-12）。
- [ ] 汇总关键差异、验证结果与最终回顾。

## Surprises & Discoveries

当前无新增记录。

## Decision Log

- Decision: 总控计划只负责串联与验收节奏，不重复子计划的细节。
  Rationale: 保持单一来源，避免计划内容分叉。
  Date/Author: 2026-01-26 / Codex

## Outcomes & Retrospective

尚未执行，暂无产出与回顾。

## Context and Orientation

需求基线与差异清单位于 `plans/prepare_plan.md`。子计划位于 `Refactoring/plans/`，每个计划遵循 `.agent/PLANS.md` 的 ExecPlan 规范。该总控计划作为唯一长期入口，负责引用并安排子计划执行顺序，并在关键阶段进行验收汇总。

## Plan of Work

按以下顺序逐个执行子计划。每完成一个子计划，必须在该子计划的 `Progress`、`Decision Log`、`Surprises & Discoveries` 中更新记录，同时在本总控计划中同步更新进度与阶段性结论。

执行顺序与依赖：

1. `Refactoring/plans/01-structure-bootstrap.md`：重构目录与基线骨架。
2. `Refactoring/plans/02-data-config-port.md`：设计数据与配置同步。
3. `Refactoring/plans/03-entry-flow.md`：主入口与回合流程接线。
4. `Refactoring/plans/04-ui-nodes-manager.md`：UIManager 接入与 UI 数据统一。
5. `Refactoring/plans/05-gameplay-items-chance.md`：玩法与道具/机会系统接入。
6. `Refactoring/plans/06-eca-bridge.md`：ECA 触发器桥接。
7. `Refactoring/plans/07-visual-timeout-anim.md`：表现层等待、动画与超时补齐。
8. `Refactoring/plans/08-ai-behavior.md`：AI 行为与自动操作完整性。
9. `Refactoring/plans/09-land-ownership.md`：地块购买与租金结算完整性。
10. `Refactoring/plans/10-land-upgrade.md`：地块加盖与建筑表现。
11. `Refactoring/plans/11-market-blackshop.md`：黑市与商城购买逻辑。
12. `Refactoring/plans/12-item-active-usage.md`：主动使用类道具卡。

若在执行过程中发现新缺口，优先补充子计划并加入本计划的执行顺序；避免在未记录的情况下临时修改实现。

## Concrete Steps

执行流程示例（每个子计划独立完成后回到本计划更新）：

    1) 打开并执行 Refactoring/plans/01-structure-bootstrap.md
    2) 更新 01 的 Progress 与本计划 Progress
    3) 继续执行 Refactoring/plans/02-data-config-port.md
    ...
    12) 执行 Refactoring/plans/12-item-active-usage.md

## Validation and Acceptance

最终验收应满足：

- `Refactoring` 可独立运行且回合流程完整。
- UIManager 管理的核心面板可打开/关闭，交互不阻塞。
- 道具、机会卡、地块、黑市、AI 行为与策划案一致。
- 超时自动确认覆盖所有可能卡死的交互场景。
- 触发器（ECA）事件可正常转发。

验收记录需写入本计划的 `Outcomes & Retrospective`，并引用各子计划的验证结果。

## Idempotence and Recovery

本计划仅用于串联执行，不直接修改代码。若出现执行偏差，按子计划回滚或重新执行，并在本计划记录原因与影响。

## Artifacts and Notes

建议在每个子计划完成后，在本计划追加简短的“阶段性验收记录”，包括：执行日期、通过的验证点、剩余风险。

## 执行节奏建议

建议采用“2~3 个子计划 + 一次阶段验收”的节奏推进：

1) 每完成 2~3 个子计划，回到 `plans/prepare_plan.md` 逐条对照需求完整性，确认是否出现新缺口。  
2) 在本计划 `Progress` 中记录阶段进度，并在 `Outcomes & Retrospective` 写一条阶段性总结。  
3) 优先先做“结构/配置/入口”三件套，再进入 UI/玩法/表现，避免边做边拆。  
4) 若某子计划阻塞超过 1 天，先拆分成更小的子计划并补进本计划顺序，保证持续推进。  
5) 每完成一轮阶段验收，执行一次最小可运行验证（启动入口、跑 1 个回合、触发 1 个 UI 弹窗）。  

## Interfaces and Dependencies

依赖 `plans/prepare_plan.md` 的需求基线。依赖 `Refactoring/plans/*` 子计划的执行结果。任何设计或需求变更需先更新 `plans/prepare_plan.md` 再调整本计划与子计划。

本计划更新记录：

2026-01-26 19:55 创建总控执行计划，原因是需要长期串联各子计划并统一验收。
