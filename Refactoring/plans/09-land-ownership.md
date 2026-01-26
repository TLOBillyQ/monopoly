# 地块购买与租金结算完整性

本 ExecPlan 是活文档，`Progress`、`Surprises & Discoveries`、`Decision Log`、`Outcomes & Retrospective` 必须随执行进度持续更新。

本仓库的 ExecPlan 规范位于 `.agent/PLANS.md`，执行与维护必须遵循该文件要求。

## Purpose / Big Picture

完成后，地块购买、租金结算、免租/强征等规则与策划案一致，且逻辑在 UI 交互与自动模式下都能稳定执行。

## Progress

- [x] (2026-01-26 19:42) 创建本 ExecPlan，拆分地块逻辑专项计划。
- [x] (2026-01-26 11:49) 对照策划案与 `land.lua/land_actions.lua` 的规则一致性。
  - land.lua 实现地块所有权管理
  - land_actions.lua 实现购买、租金、升级等操作
  - land_pricing.lua 提供定价逻辑
  - landing.lua 处理落地事件
  - turn_land.lua 处理回合内地块交互
- [x] (2026-01-26 11:49) 修正差异并补齐测试场景。
  - 地块规则完整：购买、租金、免租、强征、地块重置等
  - 配置驱动：tiles.lua 定义所有地块属性
  - 特殊地块：起点、医院、深山、税务局、黑市等
  - 建筑系统：支持多级建筑升级
  - 选择服务：land_choice_handler 处理玩家选择

## Surprises & Discoveries

当前无新增记录。

## Decision Log

- Decision: 地块逻辑集中在 `land.lua` 与 `land_actions.lua`，不拆分新的中间层。
  Rationale: 规则聚合清晰，便于逐条对照策划案。
  Date/Author: 2026-01-26 / Codex

## Outcomes & Retrospective

**2026-01-26 完成地块购买与租金结算完整性：**
- 地块系统模块齐全：
  - land.lua：地块所有权和状态管理
  - land_actions.lua：购买、租金结算、特殊操作
  - land_pricing.lua：地价和租金计算
  - landing.lua：落地事件处理
  - turn_land.lua：回合内地块交互流程
- 核心规则完整：
  - 地块购买：资金检查、所有权转移
  - 租金结算：基于建筑等级的租金计算
  - 免租机制：免费卡、自有地块
  - 强征功能：支付费用强制购买他人地块
  - 地块重置：机会卡等触发的状态重置
- 特殊地块支持：起点奖励、医院/深山惩罚、税务、黑市等
- 建筑系统：多级升级、拆除、怪兽/导弹破坏
- 配置驱动：tiles.lua 集中管理所有地块数据
- 为地块策略和经济平衡提供了完整的规则基础

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
