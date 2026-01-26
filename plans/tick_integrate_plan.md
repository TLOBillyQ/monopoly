# 实现 Gameplay Tickable Tick 流程

本 ExecPlan 是一个持续更新的文档。`Progress`、`Surprises & Discoveries`、`Decision Log`、`Outcomes & Retrospective` 必须在执行过程中保持最新。

本仓库存在 .agent/PLANS.md，本文档必须严格遵守其中的规范并持续维护。

## Purpose / Big Picture

目标是把大富翁的逐帧更新（tick）流程统一到 `src/core/` 的 tickables 管理器，并以 Eggy 示例工程里“tickables 列表 + update”的方式作为统一接口。完成后，游戏逻辑的逐帧驱动集中在 core，适配层只负责注册需要的 tickable。Eggy 层要落地成生存割草示例那种方案：全局 `G.tickables` + `LuaAPI.set_tick_handler` 逐帧调用 `update()`。这样可以让 Love2D / Eggy / Oasis 行为一致，新增逐帧系统时不再需要在多个适配层重复实现。

## Progress

- [x] (2026-01-26 08:00Z) 阅读现有 tick 相关实现与 Eggy 示例 tickables 方案。
- [x] (2026-01-26 09:10Z) 在 `src/core/` 增加 tickables 管理与对外接口，并在 `src/game.lua` 挂载。
- [x] (2026-01-26 09:20Z) 让各适配层改为注册 core tickables，并通过 `game:tick(dt)` 驱动。
- [x] (2026-01-26 09:35Z) Eggy 层入口改为 `G.tickables + LuaAPI.set_tick_handler` 驱动，并保留现有 UI/事件结构。
- [x] (2026-01-26 09:45Z) 通过回归测试与运行验证 tick 行为一致。

## Surprises & Discoveries

Love2D 有独立的 `LoveLayer:step_move_anim`（带 1 秒动画时长与路径插值），不能用 `AdapterLayer.step_move_anim` 替代，否则会改变动画节奏与回合推进时机。该逻辑被保留并作为 Love2D tickable 调度。

## Decision Log

- Decision: 采用 Eggy 示例的 tickables 约定，接口为 `update(dt)`，由 `game:add_tickable` / `game:remove_tickable` 管理。
  Rationale: 与 `knowledge/LuaSource_生存割草/main.lua` 保持一致，学习成本最低，也能兼容需要 dt 的系统。
  Date/Author: 2026-01-26 / Codex

- Decision: tickables 的调度入口放在 `src/core/`，适配层只负责注册自己需要的 tickable 并调用 `game:tick(dt)`。
  Rationale: `src/core/` 更符合跨平台核心逻辑的位置，且与 gameplay 解耦更清晰。
  Date/Author: 2026-01-26 / Codex

- Decision: Eggy 层采用生存割草方案：全局 `G.tickables` + `LuaAPI.set_tick_handler` 驱动 `update()`。
  Rationale: 与官方示例一致，Eggy 环境下更自然，减少适配层差异。
  Date/Author: 2026-01-26 / Codex

- Decision: Love2D 使用原有 `LoveLayer:step_move_anim` 作为 tickable，而不是 `AdapterLayer.step_move_anim`。
  Rationale: 保留 1 秒移动动画的节奏与 `move_anim_done` 触发时机，避免行为变化。
  Date/Author: 2026-01-26 / Codex

## Outcomes & Retrospective

已完成 core tickables 管理与三套适配层的统一调度，Eggy 入口改为 `G.tickables` 方案，Love2D 保留原移动动画节奏。回归与 All-AI 自测通过，未发现卡死与回合推进异常。

## Context and Orientation

- `knowledge/samples_report.md` 与 `knowledge/LuaSource_生存割草/main.lua` 提示：Eggy 示例使用全局 `G.tickables` 列表与 `LuaAPI.set_tick_handler` 驱动 `update()`，可作为统一 tick 接口。
- 当前适配层 tick 流程分散在：
  - `src/adapters/eggy/eggy_runtime.lua` 使用 `LuaAPI.set_tick_handler` 调用 `EggyLayer:tick(dt)`。
  - `src/adapters/oasis/oasis_runtime.lua` 调用 `OasisLayer:tick(dt)`。
  - `src/adapters/love2d/love_runtime.lua` 的 `love.update` 调用 `LoveLayer:update(dt)`。
  - `src/adapters/core/adapter_layer.lua` 实现了 `step_auto_runner`、`step_choice_timeout`、`step_move_anim`。
- gameplay 的回合流转由 `src/gameplay/turn_manager.lua` 驱动，`turn_move.lua` 会在需要移动动画时进入 `wait_move_anim` 状态，等待适配层通过 `move_anim_done` 回调继续。

## Plan of Work

第一步是在 `src/core/` 增加一个简单的 tickables 管理器，和 Eggy 示例一致，提供 `add_tickable`、`remove_tickable`、`tick` 三个能力，并约定 tickable 必须实现 `update(dt)`。该模块只负责列表管理与顺序调用，不引入额外层级或复杂抽象。

第二步在 `src/game.lua` 与 `src/gameplay/composition_root.lua` 中挂载 tickables 管理器，向外暴露 `game:add_tickable(obj)`、`game:remove_tickable(obj)`、`game:tick(dt)`。`CompositionRoot.assemble` 在创建 `game` 后立刻初始化 tickables 管理器，以确保所有平台都能使用。此处仅添加必要字段与方法，不改变现有回合/选择流程。

第三步在各适配层（`src/adapters/eggy/eggy_layer.lua`、`src/adapters/oasis/oasis_layer.lua`、`src/adapters/love2d/love_runtime.lua`）注册 tickables，复用 `AdapterLayer.step_auto_runner`、`AdapterLayer.step_choice_timeout`、`AdapterLayer.step_move_anim` 现有逻辑。做法是：在 `set_game` 或 `new_game` 完成后，创建三个轻量 tickable 对象（各自包一层 `update(dt)`），调用现有 `AdapterLayer.*`。之后 Love2D/Oasis 的 tick/update 函数改为调用 `game:tick(dt)`，并保留 UI 刷新/日志等纯视图逻辑。这样 tickables 仍旧按原顺序执行，但入口统一到 core。

第四步调整 Eggy 入口形态，使其在 Eggy 工程的 main 入口处“像生存割草那样”组织，但不要求完全一致：在 `src/adapters/eggy/eggy_runtime.lua` 中建立全局 `G.tickables`、`G.addTickable`、`G.removeTickable`，并在 `LuaAPI.set_tick_handler` 中遍历 `G.tickables` 调用 `update(dt)`。EggyLayer 只提供一个 tickable（内部调用 `game:tick(dt)` 与 UI 刷新/日志），并在 `EVENT.GAME_INIT` 内注册进 `G.tickables`。保持接口一致，但允许 Eggy 层保留当前 UI/事件注册结构。

第五步做小范围验证，确认移动动画等待、自动回合和选择超时仍然生效。必要时在 `AdapterLayer` 中补充最小化的辅助函数（例如清理或重建 tickables）以保证 `set_game` / `restart` 时不会残留旧 tickable。

## Concrete Steps

1) 在仓库根目录检查现有 tick 使用点并定位需要改动的文件：

   - `rg -n "tick|tickable|set_tick_handler|step_auto_runner|step_choice_timeout|step_move_anim" src knowledge -S`

2) 新增 core tickables 管理器：

   - 新建 `src/core/tick_flow.lua`，实现 `TickFlow.new()`、`add_tickable`、`remove_tickable`、`tick(dt)`。
   - 约定 tickable 对象必须提供 `update(dt)`，并在 `add_tickable` 中做断言。

3) 挂载到 Game：

   - 修改 `src/game.lua`，增加 `game:add_tickable` / `game:remove_tickable` / `game:tick(dt)` 方法。
   - 修改 `src/gameplay/composition_root.lua`，在创建 `game` 后实例化 `TickFlow` 并挂到 `game.tick_flow`。

4) 适配层注册 tickables 并改入口：

   - 在 `src/adapters/oasis/oasis_layer.lua`、`src/adapters/love2d/love_runtime.lua` 中，在 `set_game`/`load` 时注册 tickables，复用 `AdapterLayer.step_auto_runner`、`step_choice_timeout`、`step_move_anim`。
   - 在 `OasisLayer:tick` / `LoveLayer:update` 中用 `game:tick(dt)` 代替直接调用 `AdapterLayer.step_*`，并保留 UI 刷新与日志输出。

5) Eggy 层入口调整为“类似生存割草”的组织方式：

   - 修改 `src/adapters/eggy/eggy_runtime.lua`：初始化全局 `G`、`G.tickables`、`G.addTickable`、`G.removeTickable`，并在 `LuaAPI.set_tick_handler` 的 onPreTick 中遍历 `G.tickables` 调用 `update(dt)`；`GAME_INIT` 里调用注册逻辑，保持入口组织接近生存割草。
   - 调整 `src/adapters/eggy/eggy_layer.lua`：提供一个 tickable 对象（`update(dt)` 内部调用 `game:tick(dt)`、刷新 UI、输出日志），在 `GAME_INIT` 后注册到 `G.tickables`，但不强制改变现有 UI / 事件处理结构。

6) 自测与验证：

   - `lua tests/deps_check.lua`
   - `lua tests/regression.lua`
   - `lua main.lua --all-ai`（确认仍能完整结束并输出胜者）
   - 如有 Eggy 环境，进入 Eggy 场景后观察自动回合与移动动画是否正常继续。

## Validation and Acceptance

- 运行 `lua tests/deps_check.lua` 与 `lua tests/regression.lua` 均通过。
- `lua main.lua --all-ai` 在 10000 步内完成对局，输出回合数与胜者信息，不出现卡死。
- 在 Love2D 模式下（`lua main.lua` 或默认启动）：
  - 自动回合按钮仍能持续推进回合。
  - 触发移动动画等待时，动画完成后回合继续推进。
  - 选择超时仍能自动选择/取消。
- 在 Eggy/Oasis 环境中，行为与 Love2D 一致，且 Eggy 由 `G.tickables + LuaAPI.set_tick_handler` 驱动，不再需要在 EggyLayer 内自建 tick 循环。

## Idempotence and Recovery

新增的 tickables 管理器是纯 Lua 列表，重复执行注册只会新增条目，因此在 `set_game` 或 `restart` 时必须重新创建 game 或清理 tickables；方案中使用“新建 game = 新建 tick_flow”的方式保证可重复执行。若出现卡死或逻辑重复，可暂时回退为在适配层内直接调用 `AdapterLayer.step_*` 的方式，以确认问题来源。

## Artifacts and Notes

将保留以下关键位置的最小化代码片段供复查：

  - `src/core/tick_flow.lua` 中 tickables 结构与 `tick(dt)` 循环。
  - `src/game.lua` 中 `game:tick(dt)` 与 `game:add_tickable`/`remove_tickable` 方法。
  - Eggy 中 `G.tickables` 的注册与 `LuaAPI.set_tick_handler` 调用点。

关键验证输出（节选）：

  lua tests\\deps_check.lua
    Dependency self-check passed

  lua tests\\regression.lua
    All regression checks passed (27)

  lua main.lua --all-ai
    Turn count: 292
    Steps executed: 340
    Winner: AI2

## Interfaces and Dependencies

- 依赖：不新增外部库，仅使用现有 Lua 模块与 `AdapterLayer`。
- 新接口：
  - `game:add_tickable(obj)`：注册一个具有 `update(dt)` 方法的 tickable。
  - `game:remove_tickable(obj)`：从 tickables 列表中移除。
  - `game:tick(dt)`：逐个调用 tickables 的 `update(dt)`。
- Tickable 约定：对象必须提供 `update(dt)`，`dt` 为秒，可忽略不用。必要时可在 tickable 内部访问 `game.ui_port`、`game.store`、`game:dispatch_action`。

变更说明：2026-01-26 将 tickables 位置调整到 `src/core/`，并明确 Eggy 层采用生存割草式 `G.tickables + LuaAPI.set_tick_handler` 调度，原因是用户明确要求方案对齐 Eggy 示例并收敛核心位置。
变更说明：2026-01-26 完成实现并执行测试，原因是用户要求执行计划并验证行为一致。
