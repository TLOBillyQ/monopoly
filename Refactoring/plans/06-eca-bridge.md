# ECA 触发器桥接

本 ExecPlan 是活文档，`Progress`、`Surprises & Discoveries`、`Decision Log`、`Outcomes & Retrospective` 必须随执行进度持续更新。

本仓库的 ExecPlan 规范位于 `.agent/PLANS.md`，执行与维护必须遵循该文件要求。

## Purpose / Big Picture

完成后，`Refactoring` 将具备与 Eggy 触发器系统对接的 ECA 转发层，使 Lua 运行时事件能够被 Eggy 编辑器中的触发器系统感知与响应，满足切屏、载具等需要触发器接口的需求。

## Progress

- [x] (2026-01-26 19:25) 创建本 ExecPlan，明确 ECA 接入目标。
- [ ] (2026-01-26 19:25) 迁移 `LuaSource_大富翁/eca.lua` 并梳理事件接口。
- [ ] (2026-01-26 19:25) 将 ECA 接入到 Refactoring 运行入口与关键事件点。
- [ ] (2026-01-26 19:25) 验证触发器事件可被发送与接收。

## Surprises & Discoveries

当前无新增记录。

## Decision Log

- Decision: 以 `LuaSource_大富翁/eca.lua` 为基准实现，不新增并行实现。
  Rationale: 遵循单一实现原则，减少兼容风险。
  Date/Author: 2026-01-26 / Codex

## Outcomes & Retrospective

尚未执行，暂无产出与回顾。

## Context and Orientation

`LuaSource_大富翁/eca.lua` 用于将 Lua 层事件转发到 Eggy 触发器系统。重构版本必须保留该能力，尤其是切屏、载具、进入/离开区域等需要触发器的事件。ECA 层应由入口初始化并在关键逻辑点触发。

## Plan of Work

先将 `LuaSource_大富翁/eca.lua` 复制到 `Refactoring/` 并确认其 API 结构。随后在 `Refactoring/main.lua` 或适配层初始化时加载 ECA 并注册到全局或 game 实例上。最后在需要触发器的逻辑点（如切屏、座驾变更、移动动画完成等）调用 ECA 的转发函数，并提供最小可验证的触发器事件示例。

## Concrete Steps

在仓库根目录执行以下步骤（命令示例）：

    # 1) 复制 ECA 文件
    robocopy LuaSource_大富翁 Refactoring /E /XF *.log

    # 2) 在入口加载 ECA
    #    - Refactoring/main.lua 或 Refactoring/src/adapters/eggy/*

    # 3) 选择至少两个事件点进行转发
    #    - 例如：切屏、座驾变更、移动动画完成

## Validation and Acceptance

执行后需满足：ECA 模块可被加载；触发器事件可通过日志或 Eggy 触发器确认收到；至少两个事件点能够稳定发送事件且不影响玩法流程。

## Idempotence and Recovery

ECA 接入可重复执行。若触发器异常，可临时关闭 ECA 注册而不影响核心玩法逻辑，确保基础玩法可继续运行。

## Artifacts and Notes

建议记录已接入事件清单与触发器名称，作为后续 UI/关卡制作的参考。

## Interfaces and Dependencies

ECA 对外需提供明确的 `emit/dispatch` 入口（以 `LuaSource_大富翁/eca.lua` 为准）。依赖 Eggy 触发器系统可用性，测试时可先用日志模拟接收。

本计划更新记录：

2026-01-26 19:25 创建本计划，原因是 Eggy 触发器转发是适配版本的关键能力。
