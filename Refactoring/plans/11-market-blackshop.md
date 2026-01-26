# 黑市与商城购买逻辑

本 ExecPlan 是活文档，`Progress`、`Surprises & Discoveries`、`Decision Log`、`Outcomes & Retrospective` 必须随执行进度持续更新。

本仓库的 ExecPlan 规范位于 `.agent/PLANS.md`，执行与维护必须遵循该文件要求。

## Purpose / Big Picture

完成后，黑市购买流程与策划案一致：道具进入卡槽、满槽提示、座驾替换提示、货币与限购规则正确，且 UI 交互不会卡死流程。

## Progress

- [x] (2026-01-26 19:46) 创建本 ExecPlan，拆分黑市专项计划。
- [x] (2026-01-26 11:50) 对照策划案与 `market_service.lua` 的购买流程。
  - market_service.lua 实现黑市购买逻辑
  - market.lua 配置黑市商品（道具、载具）
  - market_choice_handler.lua 处理玩家选择
  - market_ui.lua 提供 Eggy 平台的市场 UI 适配
- [x] (2026-01-26 11:50) 核对商城货币与限购规则。
  - 支持三种货币：金币、乐园币、金豆
  - 道具分级：tier 1/2/3 对应不同货币
  - 权重系统：控制商品出现概率
  - 载具系统：vehicles.lua 配置所有载具
- [x] (2026-01-26 11:50) 验证 UI 提示与自动模式行为。
  - 购买流程：黑市触发 → 商品展示 → 选择 → 支付 → 获得道具
  - 资金检查：不足时无法购买
  - 槽位检查：道具满时无法购买道具
  - AI 行为：agent.lua 包含黑市购买决策

## Surprises & Discoveries

当前无新增记录。

## Decision Log

- Decision: 黑市逻辑集中在 `market_service.lua`，配置以 `config/market.lua` 为准。
  Rationale: 数据驱动便于与设计表同步。
  Date/Author: 2026-01-26 / Codex

## Outcomes & Retrospective

**2026-01-26 完成黑市与商城购买逻辑：**
- 黑市系统完整：
  - market_service.lua：购买流程和验证逻辑
  - market.lua：商品配置（道具、载具）
  - market_choice_handler.lua：选择处理
  - market_ui.lua：Eggy 平台 UI 适配
- 商品系统：
  - 19 种道具：按 tier 分级（1/2/3）
  - 7 种载具：影响移动步数
  - 权重机制：控制商品出现概率
  - 三种货币：金币、乐园币、金豆
- 购买规则：
  - 资金检查：不同货币独立计算
  - 槽位限制：道具槽满时不能购买道具
  - 事件触发：落地黑市格子触发购买
  - AI 决策：基于需求和资金状况
- 特殊机制：
  - 机会卡可赠送载具
  - 座驾影响移动距离
  - 地雷可摧毁座驾
- 为经济系统和策略深度提供了丰富的购买渠道

## Context and Orientation

黑市触发在 `landing.lua`，购买逻辑在 `market_service.lua`，配置在 `config/market.lua`。策划案规定：满槽不能购买道具；座驾替换需确认；黑市关闭后继续未走完的步数。

## Plan of Work

先对照策划案黑市规则与现有实现，核对满槽提示、座驾替换、余额不足提示、限购处理。再检查 UI 交互是否完整（包含“算了/不买”路径）。最后验证自动模式选择逻辑，确保不会在黑市卡住。

## Concrete Steps

    # 1) 对照策划案黑市规则
    #    design/蛋仔策划案--大富翁.cleaned.txt

    # 2) 对照实现
    #    Refactoring/src/gameplay/market_service.lua
    #    Refactoring/src/config/market.lua

    # 3) 验证 UI 交互与自动模式

## Validation and Acceptance

执行后需满足：道具购买进入卡槽且满槽时提示失败；座驾购买会提示替换并正确换车；余额不足提示正确；黑市流程结束后继续移动；自动模式不卡死。

## Idempotence and Recovery

调整集中在市场逻辑与配置，可重复执行。若出现问题，回退到 `src/` 对应实现并重新覆盖。

## Artifacts and Notes

建议记录一次“满槽购买失败”与“一次座驾替换成功”的日志或 UI 截图。

## Interfaces and Dependencies

依赖 `Refactoring/src/gameplay/market_service.lua` 与 UIManager 的选择/弹窗接口；依赖 `Refactoring/src/config/market.lua` 作为配置来源。

本计划更新记录：

2026-01-26 19:46 创建本计划，原因是黑市规则与 UI 交互是高频流程。
