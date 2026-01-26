# 黑市与商城购买逻辑

本 ExecPlan 是活文档，`Progress`、`Surprises & Discoveries`、`Decision Log`、`Outcomes & Retrospective` 必须随执行进度持续更新。

本仓库的 ExecPlan 规范位于 `.agent/PLANS.md`，执行与维护必须遵循该文件要求。

## Purpose / Big Picture

完成后，黑市购买流程与策划案一致：道具进入卡槽、满槽提示、座驾替换提示、货币与限购规则正确，且 UI 交互不会卡死流程。

## Progress

- [x] (2026-01-26 19:46) 创建本 ExecPlan，拆分黑市专项计划。
- [ ] (2026-01-26 19:46) 对照策划案与 `market_service.lua` 的购买流程。
- [ ] (2026-01-26 19:46) 核对商城货币与限购规则。
- [ ] (2026-01-26 19:46) 验证 UI 提示与自动模式行为。

## Surprises & Discoveries

当前无新增记录。

## Decision Log

- Decision: 黑市逻辑集中在 `market_service.lua`，配置以 `config/market.lua` 为准。
  Rationale: 数据驱动便于与设计表同步。
  Date/Author: 2026-01-26 / Codex

## Outcomes & Retrospective

尚未执行，暂无产出与回顾。

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
