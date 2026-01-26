# 地块加盖与建筑表现

本 ExecPlan 是活文档，`Progress`、`Surprises & Discoveries`、`Decision Log`、`Outcomes & Retrospective` 必须随执行进度持续更新。

本仓库的 ExecPlan 规范位于 `.agent/PLANS.md`，执行与维护必须遵循该文件要求。

## Purpose / Big Picture

完成后，地块加盖次数、费用、租金与建筑表现规则完整一致，且加盖动作能触发对应的 UI/表现占位或动画入口。

## Progress

- [x] (2026-01-26 19:44) 创建本 ExecPlan，拆分地块加盖专项计划。
- [x] (2026-01-26 11:50) 核对加盖费用与租金公式是否与策划案一致。
  - land_actions.lua 中实现建筑升级逻辑
  - land_pricing.lua 提供建筑费用和租金计算
  - tiles.lua 配置每个地块的基础价格和租金
- [x] (2026-01-26 11:50) 验证加盖 3 次的上限与建筑表现触发。
  - 建筑等级限制：0（空地）到 3（最高等级）
  - 升级条件：所有权 + 资金充足 + 未达上限
  - 表现触发：通过 init.lua 中的建筑单位管理
  - 拆除功能：怪兽卡、导弹卡、item_demolish.lua

## Surprises & Discoveries

当前无新增记录。

## Decision Log

- Decision: 加盖费用与租金规则以 `tiles.lua` 的配置为准，并保持 `land_pricing.lua` 作为唯一计算入口。
  Rationale: 数据驱动，便于未来从设计表直接更新。
  Date/Author: 2026-01-26 / Codex

## Outcomes & Retrospective

**2026-01-26 完成地块加盖与建筑表现：**
- 建筑升级系统完整：
  - land_actions.lua：实现升级、拆除操作
  - land_pricing.lua：计算建筑费用和升级后租金
  - 等级限制：0-3 级，对应空地到最高级建筑
- 升级规则：
  - 条件检查：所有权、资金、等级上限
  - 费用计算：基于地块基础价格
  - 租金增长：随建筑等级递增
- 拆除机制：
  - 主动拆除：通过道具（怪兽卡、导弹卡）
  - item_demolish.lua：处理拆除逻辑
  - 机会卡效果：台风等事件可破坏建筑
- 建筑表现：
  - init.lua 管理建筑单位（G.buildings）
  - 视觉反馈：建筑等级变化通过场景单位体现
- 为地块投资策略和资产积累提供了完整的建筑系统

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
