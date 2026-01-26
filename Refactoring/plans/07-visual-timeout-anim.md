# 表现层等待、动画与超时补齐

本 ExecPlan 是活文档，`Progress`、`Surprises & Discoveries`、`Decision Log`、`Outcomes & Retrospective` 必须随执行进度持续更新。

本仓库的 ExecPlan 规范位于 `.agent/PLANS.md`，执行与维护必须遵循该文件要求。

## Purpose / Big Picture

完成后，重构版本的视觉层将能够与回合流程正确同步：移动动画完成后再继续结算，弹窗/选择具备统一超时自动确认机制，视角跟随与停留提示具备占位实现。整体流程不会因 UI 交互缺失而卡死，满足策划案中对“行动中表现与等待”的要求。

## Progress

- [x] (2026-01-26 19:30) 创建本 ExecPlan，明确表现层补齐范围。
- [ ] (2026-01-26 19:30) 接入移动动画与等待恢复机制（move.lua）。
- [ ] (2026-01-26 19:30) 扩展超时自动确认覆盖所有可能卡死的 UI 交互。
- [ ] (2026-01-26 19:30) 追加视角跟随/停留提示的占位实现。

## Surprises & Discoveries

当前无新增记录。

## Decision Log

- Decision: 表现层采用“等待状态 + 完成事件”模型与回合逻辑解耦。
  Rationale: 避免在 gameplay 中插入 UI 细节，同时保证动画完成后才继续结算。
  Date/Author: 2026-01-26 / Codex

## Outcomes & Retrospective

尚未执行，暂无产出与回顾。

## Context and Orientation

原版存在 `LuaSource_大富翁/move.lua` 用于移动动画。当前逻辑侧已有等待框架（如 `turn_manager` 的等待状态与 `AdapterLayer.step_choice_timeout`），但超时仅覆盖选择类交互，未覆盖所有 UI 场景。设计要求行动中有表现与等待，且 10 秒无操作应自动确认。

## Plan of Work

首先把 `LuaSource_大富翁/move.lua` 迁移到 `Refactoring` 并接入适配层，保证移动动画的起止事件可被捕获。随后扩展 `AdapterLayer` 或 UI 管理器的超时处理，让所有可能卡住流程的弹窗/选择都能在 10 秒内自动确认。最后补齐视角跟随与停留提示的占位实现，暂时可通过日志或简单 UI 提示完成，占位逻辑需可替换为正式动画。

## Concrete Steps

在仓库根目录执行以下步骤（命令示例）：

    # 1) 迁移移动动画脚本
    robocopy LuaSource_大富翁 Refactoring /E /XF *.log

    # 2) 在适配层接入 move.lua 并在动画完成时发出完成事件
    #    - Refactoring/src/adapters/* 中调用 move.lua

    # 3) 扩展超时自动确认覆盖范围
    #    - AdapterLayer.step_choice_timeout 或 UI 管理器层

    # 4) 添加视角跟随/停留提示占位逻辑

## Validation and Acceptance

执行后需满足：玩家移动时回合流程会等待动画完成再继续；任意弹窗或选择在 10 秒无操作时自动确认或取消且不会卡死；视角跟随与停留提示至少有可见的占位表现（日志或 UI 提示）。

## Idempotence and Recovery

动画与超时逻辑可重复接入。若出现卡死，可暂时关闭等待机制并回退至“立即完成”策略，保证基础玩法可运行。

## Artifacts and Notes

建议记录“等待点清单”（例如移动动画、选择弹窗、黑市购买、偷窃选择等）作为验证依据。

## Interfaces and Dependencies

依赖 `Refactoring/src/adapters/core/adapter_layer.lua` 的等待与超时机制；依赖 `move.lua` 对外提供“开始/完成”事件或可查询状态；与 `turn_manager` 的等待状态保持一致，不允许在 gameplay 层新增 UI 细节。

本计划更新记录：

2026-01-26 19:30 创建本计划，原因是表现层等待与超时直接决定流程是否卡死。
