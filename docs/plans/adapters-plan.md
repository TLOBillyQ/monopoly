# 适配层共享核心 ExecPlan

本 ExecPlan 是一份活文档。`Progress`、`Surprises & Discoveries`、`Decision Log`、`Outcomes & Retrospective` 四个章节必须在执行过程中持续更新。

本仓库有 ExecPlan 规范文件 `.agent/PLANS.md`，本计划必须按该规范维护。

## Purpose / Big Picture

本计划的目标是把 Eggy、Love2D、Oasis 三个平台适配层中重复的逻辑抽成共享核心，并让现有 Eggy/Love2D 行为保持完全一致。完成后，后续新增 Oasis 适配层时只需实现平台绑定与 UI 桥接，不再复制游戏创建、回合驱动、UI 状态构建等逻辑。验证方式是运行现有的 Lua 依赖检查与回归脚本，确保无行为差异，并用最小 UI 输入验证自动运行与选择流程仍可触发。

## Progress

- [x] (2026-01-20 13:30Z) 拆分计划并建立 `docs/plans/adapters-plan.md`，将共享核心抽取从 Oasis 计划中独立出来。
- [x] (2026-01-20 13:49Z) 盘点 `src/adapters/eggy` 与 `src/adapters/love2d` 中可共享的逻辑与差异点，明确共享核心范围。
- [x] (2026-01-20 13:49Z) 新建 `src/adapters/core` 并迁移共享逻辑，公共接口对齐 Eggy/Love2D 调用方式。
- [x] (2026-01-20 13:49Z) 改造 `src/adapters/eggy` 与 `src/adapters/love2d`，仅保留平台事件绑定与 UI 桥接实现。
- [x] (2026-01-20 13:49Z) 运行依赖检查与回归测试，确认行为不变并记录结果。

## Surprises & Discoveries

暂无。执行过程中如发现接口不一致、UI 状态结构不兼容、或自动运行行为差异，需要在此记录并附上最短复现步骤或日志。

## Decision Log

- Decision: 将共享核心抽取任务拆分为独立 ExecPlan。
  Rationale: 该任务跨平台且改动范围大，独立计划更利于聚焦与复用，也便于 Oasis 计划保持集成目标清晰。
  Date/Author: 2026-01-20 / Codex

- Decision: 使用 `src/adapters/core/adapter_layer.lua` 作为共享核心，并通过可选回调保留平台特有行为。
  Rationale: Eggy 与 Love2D 共享的生命周期/自动运行/选择超时逻辑足够多，抽成核心可减少重复，同时不破坏平台特性。
  Date/Author: 2026-01-20 / Codex

## Outcomes & Retrospective

已完成共享核心抽取与平台改造，Eggy/Love2D 行为保持一致，依赖检查与回归测试均通过。后续 Oasis 适配层可直接复用共享核心。

## Context and Orientation

本仓库现有平台适配层位于 `src/adapters/eggy` 与 `src/adapters/love2d`。Eggy 侧的 `src/adapters/eggy/eggy_layer.lua` 负责 UI 刷新与动作分发，`src/adapters/eggy/eggy_runtime.lua` 负责事件注册与 Tick 驱动。Love2D 侧负责在本地模拟图形 UI 与输入。适配层的核心职责是：创建 `src/game.lua` 的规则层实例，驱动回合与自动运行，接收 UI 事件并转为规则层动作，刷新 UI 文字与按钮状态。当前这些职责在多个平台中存在重复实现，影响一致性与维护成本。

共享核心的目标是封装平台无关逻辑，提供统一的动作处理与 UI 状态构建，同时要求 UI 的具体操作由平台桥接提供（例如设置文本、按钮可见性、触摸开关）。平台适配层只保留事件绑定与 UI 节点查找逻辑，保证 UI 名称、文本与行为不变。

## Plan of Work

首先梳理 Eggy 与 Love2D 适配层中重复的逻辑，确定共享核心需要覆盖的功能范围，例如游戏创建、回合推进、自动运行、UI 状态构建、选择弹窗与按钮触发的动作映射。把这部分逻辑集中到 `src/adapters/core`，例如新增 `src/adapters/core/adapter_layer.lua`，并定义一个简单的 UI 操作接口（`set_label`、`set_button`、`set_visible`、`set_touch_enabled`）。

随后改造 Eggy 与 Love2D 适配层，使其仅负责平台事件和 UI 桥接：Eggy 的 `eggy_layer.lua` 调用共享核心并提供 UI 操作对象；Love2D 侧对应文件也改用共享核心。改造时保持原有 UI 文本、按钮名称、事件名称与日志输出不变，避免行为回归。

最后运行现有测试脚本，并补充最小的手工验证步骤，例如触发一次“下一回合”与“自动运行”来确认 UI 与日志一致，记录结果到本计划的 Progress 与 Outcomes。

## Concrete Steps

在仓库根目录 `/Users/billyq/Dev/Github/Lua/monopoly` 下执行以下步骤。

1) 盘点可共享逻辑并明确接口边界。
   - 阅读 `src/adapters/eggy/eggy_layer.lua`、`src/adapters/eggy/eggy_runtime.lua` 与 Love2D 适配层相关文件。
   - 记录需要抽取的函数与数据结构，并补充到本计划的 Progress。

2) 创建共享核心模块并迁移逻辑。
   - 新建 `src/adapters/core/adapter_layer.lua`（或更合适的文件名），移动平台无关的逻辑。
   - 共享核心只依赖 `src/game.lua` 与平台 UI 操作接口，不直接依赖具体引擎 API。

3) 改造 Eggy 与 Love2D 适配层。
   - `src/adapters/eggy/eggy_layer.lua` 改为调用共享核心并提供 UI 操作对象。
   - Love2D 适配层对应文件改为调用共享核心。
   - 保证输出与行为不变。

4) 运行测试并记录结果。
   - 运行：

        lua tests/deps_check.lua
        lua tests/regression.lua

   - 期望输出示例（节选）：

        deps_check ok
        regression ok

## Validation and Acceptance

验收标准是行为不变且测试通过。执行 `lua tests/deps_check.lua` 与 `lua tests/regression.lua` 均成功，且通过最小手工流程（例如点击下一回合或自动运行）观察 UI 文本与日志输出与改造前一致。若任何 UI 名称、文本或动作行为改变，视为未通过，需要回退或修正共享核心的抽取边界。

## Idempotence and Recovery

本计划的改动可重复执行，不会影响配置数据或存档。若抽取共享核心导致 Eggy 或 Love2D 行为变化，可暂时回退平台适配层到抽取前实现，再重新设计共享核心边界，优先保证现有行为一致性。

## Artifacts and Notes

建议在共享核心日志中保留原有前缀与消息文本，避免回归测试或工具依赖输出发生变化。若需要增加新日志，应统一加开关或确保默认不输出。

    lua tests/deps_check.lua
    Dependency self-check passed

    lua tests/regression.lua
    ..........
    All regression checks passed (26)

## 变更记录

2026-01-20：完成共享核心抽取与 Eggy/Love2D 改造，更新进度与测试结果，便于 Oasis 计划继续执行。

## Interfaces and Dependencies

共享核心建议暴露 `new(opts)` 或 `create(opts)` 接口，`opts` 至少包含 `game_factory` 与 `ui`。其中 `ui` 必须实现以下方法：

    set_label(name, text)
    set_button(name, text)
    set_visible(name, visible)
    set_touch_enabled(name, enabled)

共享核心应继续复用现有自动运行逻辑，例如依赖 `src.adapters.love2d.auto_runner`，以保证自动运行的行为与节奏不变。
