# Plan: `src/` 第三轮清理

## Summary

建议把这轮计划落盘为 `src-third-cleanup-plan.md`。本轮只做边界内收口，不做跨层重构，目标分成三类：

- 命名收口：继续去掉父目录已经提供语义的前缀，覆盖 `game/flow/turn/turn_*`、`presentation/runtime/ui_*`、`presentation/model/ui_*`
- 结构冗余：收口 `game/systems/land/landing_*` 与 `game/systems/items/item_*`
- 代码层清理：只清理薄包装、重复 merge、重复 context copy、rename 后失去意义的 alias；不改协议、不改 Port 语义、不跨 layer 搬模块

本轮对外变化只有模块路径变化，没有状态字段、事件名、Port 名、choice/output payload 形状变化。明确保持不动：`state.gameplay_loop_ports`、`*_port.lua` / `*_ports.lua` / `*_port_adapter.lua` 语义、`output_adapters/` 目录归属、`presentation/model/gameplay_read_port.lua`、`action_anim.lua` 主入口。

## Dependency Graph

`T1 ──┬── T2 ──┐`  
`     ├── T3 ──┤`  
`     ├── T4 ──┼── T6 ──┐`  
`     └── T5 ──┘        ├── T7 ── T8`  
`T2,T3 ─────────────────┘`

## Tasks

### T1: 冻结映射、排除项与验证口径
- **depends_on**: `[]`
- **location**: `src/`, `tests/`, `docs/`, `.agents/`
- **description**: 冻结本轮唯一合法映射，并写死排除项。命名收口映射如下：
  - `turn_action_gate -> action_gate`
  - `turn_anim -> anim`
  - `turn_camera_policy -> camera_policy`
  - `turn_choice_auto_policy -> choice_auto_policy`
  - `turn_decision -> decision`
  - `turn_dispatch -> dispatch`
  - `turn_dispatch_validator -> dispatch_validator`
  - `turn_land -> land`
  - `turn_logger -> logger`
  - `turn_phase_registry -> phase_registry`
  - `turn_role_control_policy -> role_control_policy`
  - `turn_runtime -> runtime`
  - `turn_start -> start`
  - `turn_timer_policy -> timer_policy`
  - `ui_event_handlers -> event_handlers`
  - `ui_events -> events`
  - `ui_runtime -> runtime`
  - `ui_model -> model`
  - `ui_role_avatar -> role_avatar`
  - `ui_role_context -> role_context`
  - `landing_effects/ -> effects/`
  - `landing_effect_executors -> executors`
  - `landing_presenter -> presenter`
  - `specs/landing_effects -> specs/effects`
  - `base_land_effects -> base`
  - `chance_effects -> chance`
  - `market_effects -> market`
  - `special_tile_effects -> special`
  - `transit_effects -> transit`
  - `item_demolish -> demolish`
  - `item_executor -> executor`
  - `item_handlers -> handlers`
  - `item_inventory -> inventory`
  - `item_phase -> phase`
  - `item_post_effects -> post_effects`
  - `item_registry -> registry`
  - `item_remote_dice -> remote_dice`
  - `item_roadblock -> roadblock`
  - `item_steal -> steal`
  - `item_strategy -> strategy`
  - `item_use_broadcast -> use_broadcast`
- **validation**: 所有目标路径当前不存在；映射表完整；排除项明确写入计划。
- **status**: completed (2026-03-08 16:00Z)
- **work_log**:
  - 核对全部目标路径当前均不存在，可直接做原子 rename，不需要兼容桥。
  - 确认旧路径命中仍集中在四簇：`presentation/runtime.ui_*` 与 `presentation/model.ui_*`、`game/flow/turn/turn_*`、`game/systems/land/landing_*`、`game/systems/items/item_*`。
  - 冻结排除项：不改 `state.ui_runtime`、`ui_model` 数据结构字段、`state.gameplay_loop_ports`、`action_anim.lua` 主入口、`*_port.lua` / `*_ports.lua` / `*_port_adapter.lua` 语义。
- **files_touched**:
  - `.agents/swarm_plan.md`
- **gotchas**:
  - `presentation_ui.lua` 与 `gameplay.lua` 都是多簇共用的大测试文件，Wave 2 需要按写集保守拆分，避免并行覆盖同一文件。
  - `turn_runtime.lua` 当前是稳定入口别名，本轮只能改路径命名与引用，不把它当成删除目标。

### T2: 收口 `presentation/runtime/ui_*` 与 `presentation/model/ui_*`
- **depends_on**: `[T1]`
- **location**: `src/presentation/runtime`, `src/presentation/model`, `src/presentation/view`, `tests/suites/presentation`, `tests/suites/runtime`
- **description**: 统一切换 runtime/model 的 `ui_*` 模块路径与引用，但不改 `state.ui_runtime`、`ui_model` 数据结构字段、`UIManager` 使用方式。这里只改模块名，不改模型 shape。
- **validation**: `rg 'src\.presentation\.(runtime\.ui_|model\.ui_)' src tests docs .agents` 仅允许历史计划记录；`presentation_ui`、`runtime_bootstrap` 能加载新路径。
- **status**: completed_with_gotchas (2026-03-08 16:05Z)
- **work_log**:
  - 原子重命名 `src/presentation/runtime/ui_event_handlers.lua`、`ui_events.lua`、`ui_runtime.lua` 为 `event_handlers.lua`、`events.lua`、`runtime.lua`。
  - 原子重命名 `src/presentation/model/ui_model.lua`、`ui_role_avatar.lua`、`ui_role_context.lua` 为 `model.lua`、`role_avatar.lua`、`role_context.lua`，并同步将 `src/presentation/model/ui_model/` 目录收口为 `src/presentation/model/model/`，以清掉 `ui_model.*` 子模块旧路径。
  - 更新 `src/presentation/input/**`、`src/presentation/runtime/**`、`src/presentation/view/**`、`src/app/bootstrap/**` 中直接 require 与动态 require，未改 `state.ui_runtime`、`ui_model` 数据结构字段或 `UIManager` 用法。
  - 以最小写集修正了 `tests/suites/presentation/presentation_ui_event_handlers.lua`、`presentation_ui_event_bindings.lua`、`presentation_ui_action_anim.lua`、`presentation_player_colors.lua`，并对共享大文件 `presentation_ui.lua` 只做旧模块路径替换。
  - 完成 T2 自有验证：`rg 'src\.presentation\.(runtime\.ui_|model\.ui_)' src tests docs .agents` 已清零；内联脚本验证 `event_handlers.install(...)` 可注册事件；新旧受影响文件均通过 `loadfile(...)` 语法编译。
- **files_touched**:
  - `.agents/swarm_plan.md`
  - `src/app/bootstrap/game_startup_event_bridge.lua`
  - `src/app/bootstrap/ui_bootstrap.lua`
  - `src/presentation/input/canvas_coordinator.lua`
  - `src/presentation/input/event_bindings.lua`
  - `src/presentation/input/event_state.lua`
  - `src/presentation/input/intent_dispatch/role_context.lua`
  - `src/presentation/input/intent_dispatch/view_command.lua`
  - `src/presentation/model/model.lua`
  - `src/presentation/model/model/board_slice.lua`
  - `src/presentation/model/model/choice_slice.lua`
  - `src/presentation/model/model/item_slice.lua`
  - `src/presentation/model/model/panel_slice.lua`
  - `src/presentation/model/role_avatar.lua`
  - `src/presentation/model/role_context.lua`
  - `src/presentation/runtime/canvas_render_pipeline.lua`
  - `src/presentation/runtime/event_handlers.lua`
  - `src/presentation/runtime/events.lua`
  - `src/presentation/runtime/local_actor_resolver.lua`
  - `src/presentation/runtime/ports/debug_ports.lua`
  - `src/presentation/runtime/ports/state_ports.lua`
  - `src/presentation/runtime/ports/ui_sync/ui_model_sync.lua`
  - `src/presentation/runtime/runtime.lua`
  - `src/presentation/runtime/view_service.lua`
  - `src/presentation/runtime/view_service/assets.lua`
  - `src/presentation/runtime/view_service/core.lua`
  - `src/presentation/runtime/view_service/debug.lua`
  - `src/presentation/runtime/view_service/item_slots.lua`
  - `src/presentation/view/render/action_anim.lua`
  - `src/presentation/view/render/anim_dice.lua`
  - `src/presentation/view/render/market.lua`
  - `src/presentation/view/render/market_controls.lua`
  - `src/presentation/view/render/market_slots.lua`
  - `src/presentation/view/widgets/choice_screen_service/common.lua`
  - `src/presentation/view/widgets/market_modal_renderer.lua`
  - `src/presentation/view/widgets/panel.lua`
  - `src/presentation/view/widgets/panel_presenter.lua`
  - `src/presentation/view/widgets/popup_renderer.lua`
  - `src/presentation/view/widgets/turn_effects.lua`
  - `tests/suites/presentation/presentation_player_colors.lua`
  - `tests/suites/presentation/presentation_ui.lua`
  - `tests/suites/presentation/presentation_ui_action_anim.lua`
  - `tests/suites/presentation/presentation_ui_event_bindings.lua`
  - `tests/suites/presentation/presentation_ui_event_handlers.lua`
- **gotchas**:
  - 任务说明里提到的 `tests/suites/runtime/ui_runtime_state_contract.lua` 在仓库中不存在，已改用 `runtime_bootstrap` 加载链与内联模块加载脚本替代验证。
  - `presentation_ui_event_handlers` 与 `runtime_bootstrap` 当前都被并行中的 items 收口中间态阻塞，错误源是 `src.game.systems.items.item_inventory` 旧路径已失效，而不是 T2 的 runtime/model 路径。
  - 为满足仓库级旧路径清零校验，额外最小改动了 `src/app/bootstrap/game_startup_event_bridge.lua` 与 `tests/suites/presentation/presentation_ui.lua` 的直接 require；未扩展到字段名或行为调整。

### T3: 收口 `game/flow/turn/turn_*`
- **depends_on**: `[T1]`
- **location**: `src/game/flow/turn`, `src/app/bootstrap`, `tests/suites/gameplay`, `tests/suites/architecture`, `tests/suites/runtime`
- **description**: 只收口 `turn_*` 文件名，不动 `tick_*`、`auto_*`、`loop_*`、`state.gameplay_loop_ports` 等稳定词。同步所有 direct require、动态 require、测试 patch target。`turn_runtime.lua` 继续保留为稳定入口，只改路径，不删除 alias 行为。
- **validation**: `rg 'src\.game\.flow\.turn\.turn_' src tests docs .agents` 仅允许历史计划记录；`gameplay`、`runtime_bootstrap`、`architecture_guard_contract` 能走完整加载链。
- **status**: completed_with_gotchas (2026-03-08 16:06Z)
- **work_log**:
  - 原子重命名 14 个冻结映射文件：`turn_action_gate`、`turn_anim`、`turn_camera_policy`、`turn_choice_auto_policy`、`turn_decision`、`turn_dispatch`、`turn_dispatch_validator`、`turn_land`、`turn_logger`、`turn_phase_registry`、`turn_role_control_policy`、`turn_runtime`、`turn_start`、`turn_timer_policy`。
  - 同步更新 `src/game/flow/turn/**`、`src/app/bootstrap/game_runtime_bootstrap.lua`、`src/game/scheduler/**`、`src/game/core/runtime/composition_root.lua` 与 `tests/TestSupport.lua`、`tests/suites/gameplay/**`、`tests/suites/architecture/architecture_guard_contract.lua` 中的直接 require。
  - 为适配并行中的 T4/T5 已落地文件名，在 `src/game/flow/turn/**` 和 `tests/TestSupport.lua`、`tests/suites/gameplay/gameplay.lua` 内补做最小依赖切换：`items.item_* -> items.*`、`land.specs.landing_effects -> land.specs.effects`、`landing_effect_executors -> executors`，未改任何状态字段或 phase 协议。
  - 运行最小组合回归：`gameplay`、`runtime_bootstrap`、`architecture_guard_contract` 全部通过。
- **files_touched**:
  - `.agents/swarm_plan.md`
  - `src/app/bootstrap/game_runtime_bootstrap.lua`
  - `src/game/core/runtime/composition_root.lua`
  - `src/game/flow/turn/action_gate.lua`
  - `src/game/flow/turn/anim.lua`
  - `src/game/flow/turn/camera_policy.lua`
  - `src/game/flow/turn/choice_auto_policy.lua`
  - `src/game/flow/turn/decision.lua`
  - `src/game/flow/turn/dispatch.lua`
  - `src/game/flow/turn/dispatch_validator.lua`
  - `src/game/flow/turn/land.lua`
  - `src/game/flow/turn/logger.lua`
  - `src/game/flow/turn/loop.lua`
  - `src/game/flow/turn/loop_tick_flow.lua`
  - `src/game/flow/turn/loop_tick_steps.lua`
  - `src/game/flow/turn/phase_registry.lua`
  - `src/game/flow/turn/role_control_policy.lua`
  - `src/game/flow/turn/runtime.lua`
  - `src/game/flow/turn/start.lua`
  - `src/game/flow/turn/tick_timeout.lua`
  - `src/game/flow/turn/timer_policy.lua`
  - `src/game/flow/turn/turn_move.lua`
  - `src/game/flow/turn/turn_roll.lua`
  - `src/game/scheduler/await.lua`
  - `src/game/scheduler/turn_script.lua`
  - `tests/TestSupport.lua`
  - `tests/suites/architecture/architecture_guard_contract.lua`
  - `tests/suites/gameplay/gameplay.lua`
  - `tests/suites/gameplay/gameplay_coroutine.lua`
- **gotchas**:
  - 冻结映射未包含 `turn_move.lua` 与 `turn_roll.lua`，因此它们及其测试引用仍保留 `turn_` 前缀；仓库级 `rg 'src\.game\.flow\.turn\.turn_' src tests docs .agents` 仍会命中这些稳定模块。
  - 任务写集外仍有旧路径引用：`tests/internal/dep_rules.lua`、`tests/suites/presentation/**`、`tests/suites/domain/landing.lua` 还指向本轮已改名模块，需由对应 worker 或后续 guard/doc 波统一收口。
  - `turn_runtime.lua` 的稳定入口语义已保留到 `runtime.lua`，但没有新增兼容桥；所有调用方必须切到新模块路径。

### T4: 收口 `land/landing_*` 结构冗余
- **depends_on**: `[T1]`
- **location**: `src/game/systems/land`, `tests/suites/domain/land.lua`, `tests/suites/gameplay/gameplay.lua`, `docs/architecture`
- **description**: 把 `landing_effects/` 收口为 `effects/`，并把 `landing_effect_executors.lua`、`landing_presenter.lua`、`specs/landing_effects.lua` 与子模块文件名改为目录内自然命名。保留 `land_*` 家族不动，本轮只清 `landing_*`。
- **validation**: `rg 'src\.game\.systems\.land\.landing_' src tests docs .agents` 仅允许历史计划记录；`domain.land` 和相关 gameplay land 路径通过。
- **status**: completed_with_gotchas (2026-03-09 08:23Z)
- **work_log**:
  - 将 `src/game/systems/land/landing_effects/` 原子收口为 `src/game/systems/land/effects/`，并完成 `base/chance/market/special/transit` 子模块重命名。
  - 将 `landing_effect_executors.lua -> executors.lua`、`landing_presenter.lua -> presenter.lua`、`specs/landing_effects.lua -> specs/effects.lua`，同步更新 land 内部 require 链。
  - 在 land 自有文件内顺手适配并行中的 items 收口：`land_rules.lua`、`effects/base.lua`、`effects/transit.lua` 已对齐新的 items 模块路径。
  - 只更新了允许范围内的直接引用：`src/game/core/runtime/bootstrap.lua` 和 `tests/suites/domain/land.lua` 已切到新路径。
  - 清理了空的 `src/game/systems/land/landing_effects/` 目录；未触碰 `land_*` 家族。
- **files_touched**:
  - `.agents/swarm_plan.md`
  - `src/game/core/runtime/bootstrap.lua`
  - `src/game/systems/land/effects/base.lua`
  - `src/game/systems/land/effects/chance.lua`
  - `src/game/systems/land/effects/market.lua`
  - `src/game/systems/land/effects/special.lua`
  - `src/game/systems/land/effects/transit.lua`
  - `src/game/systems/land/executors.lua`
  - `src/game/systems/land/land_rules.lua`
  - `src/game/systems/land/presenter.lua`
  - `src/game/systems/land/specs/effects.lua`
  - `tests/suites/domain/land.lua`
- **gotchas**:
  - `tests/suites/gameplay/gameplay.lua:1137` 仍引用旧 `src.game.systems.land.landing_effect_executors`；按任务约束未改，留给后续共享集成波统一收口。
  - `tests/suites/architecture/intent_output_contract.lua:10` 仍引用旧 `src.game.systems.land.landing_presenter`；该文件不在本任务所有权内，需后续集成波改为 `src.game.systems.land.presenter`。
  - `domain.land` 定向执行被并行中的 items 收口中间态阻塞，错误来自 `src.game.systems.items.item_inventory` 缺失，不是 land require 链问题。

### T5: 收口 `items/item_*` 结构冗余
- **depends_on**: `[T1]`
- **location**: `src/game/systems/items`, `src/game/systems/choices/handlers/item.lua`, `tests/suites/domain/item.lua`, `tests/suites/gameplay/gameplay.lua`
- **description**: 批量去掉 `game/systems/items` 下文件名前缀 `item_`。保持目录名 `items/`、choice kind、日志文案、事件语义不变，只改模块路径和引用。
- **validation**: `rg 'src\.game\.systems\.items\.item_' src tests docs .agents` 仅允许历史计划记录；`domain.item`、`gameplay` 通过。
- **status**: completed_with_gotchas (2026-03-08 16:06Z)
- **work_log**:
  - 将 `src/game/systems/items/` 下 12 个 `item_*` 文件原子改名为 `demolish/executor/handlers/inventory/phase/post_effects/registry/remote_dice/roadblock/steal/strategy/use_broadcast`，未保留兼容桥。
  - 同步 items 目录内部 require 链，以及 `src/game/systems/choices/handlers/item.lua`、`tests/suites/domain/item.lua`、`src/game/core/runtime/bootstrap.lua` 的直接模块路径。
  - 为了让 `domain.item` 加载链闭合，补齐了直接引用这些 item 模块的小型共享文件顶部 require，包括 `tests/TestSupport.lua`、`src/game/systems/choices/resolver.lua`、`src/game/flow/turn/*` 中的 item 入口引用，以及少量 market/chance/movement/land 文件。
  - 在并行中的 land 收口之后，`src/game/systems/choices/resolver.lua` 额外把 `src.game.systems.land.specs.landing_effects` 切到当前有效的 `src.game.systems.land.specs.effects`，否则 `domain.item` 无法启动。
  - 验证结果：`lua -e 'package.path=package.path..";./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua"; require("TestHarness").run_all({require("suites.domain.item")})'` 通过，输出 `All regression checks passed (27)`。
- **files_touched**:
  - `.agents/swarm_plan.md`
  - `src/app/testing/test_profile_bootstrap.lua`
  - `src/game/core/ai/agent.lua`
  - `src/game/core/runtime/bootstrap.lua`
  - `src/game/flow/turn/decision.lua`
  - `src/game/flow/turn/phase_registry.lua`
  - `src/game/flow/turn/start.lua`
  - `src/game/flow/turn/turn_move.lua`
  - `src/game/flow/turn/turn_roll.lua`
  - `src/game/systems/chance/handlers/common.lua`
  - `src/game/systems/choices/handlers/item.lua`
  - `src/game/systems/choices/handlers/land.lua`
  - `src/game/systems/choices/resolver.lua`
  - `src/game/systems/endgame/bankruptcy.lua`
  - `src/game/systems/items/demolish.lua`
  - `src/game/systems/items/executor.lua`
  - `src/game/systems/items/handlers.lua`
  - `src/game/systems/items/inventory.lua`
  - `src/game/systems/items/phase.lua`
  - `src/game/systems/items/post_effects.lua`
  - `src/game/systems/items/registry.lua`
  - `src/game/systems/items/remote_dice.lua`
  - `src/game/systems/items/roadblock.lua`
  - `src/game/systems/items/steal.lua`
  - `src/game/systems/items/strategy.lua`
  - `src/game/systems/items/use_broadcast.lua`
  - `src/game/systems/land/effects/base.lua`
  - `src/game/systems/land/effects/transit.lua`
  - `src/game/systems/land/land_rules.lua`
  - `src/game/systems/market/application/eligibility.lua`
  - `src/game/systems/market/application/fulfillment.lua`
  - `src/game/systems/movement/movement.lua`
  - `tests/TestSupport.lua`
  - `tests/suites/domain/item.lua`
  - `tests/suites/domain/landing.lua`
- **gotchas**:
  - `rg 'src\.game\.systems\.items\.item_' src tests docs .agents` 现在只剩历史计划记录和 `tests/suites/gameplay/gameplay.lua` 的 3 处旧路径；该文件按任务约束未改，需后续共享集成波统一切到 `inventory/post_effects/strategy`。
  - 本任务没有运行 `gameplay` 全链路；因为共享大测试文件仍保留旧 items 路径，现阶段只验证了 `domain.item`。

### T6: 代码层清理，只做边界内安全项
- **depends_on**: `[T2, T3, T4, T5]`
- **location**: `src/game/systems/land`, `src/game/systems/items`, `src/presentation/runtime`, `src/presentation/model`
- **description**: 只做四类安全清理：
  - 把 renamed 模块里的局部表名、require 别名改成最终名字，消除旧前缀遗留
  - 把 `land/executors.lua` 的手工 merge 改成小型有序聚合 helper，保持导出不变
  - 把 `items/registry.lua` 中重复 context copy / target resolver 注入提成局部 helper，保持行为不变
  - 清掉 rename 后已经失去意义的重复 require 路径与临时 alias
- **validation**: 受影响模块的 require 链保持闭合；没有新增跨层依赖；architecture suites 通过。

### T7: guard / 文档 / 活文档同步
- **depends_on**: `[T2, T3, T4, T5, T6]`
- **location**: `tests/internal/legacy_path_guard.lua`, `tests/internal/dep_rules.lua`, `docs/architecture/*.md`, `.agents/*.md`
- **description**: 更新 retired paths、dep_rules 根路径与架构文档示例；把这轮新旧路径写入执行计划和研究文档。只同步命名，不改边界规则本身。若实施时涉及 `.agents/plan.md`，必须按 `.agents/harness/PLANS.md` 维护。
- **validation**: 新退休路径可被 `legacy_path_guard` 拦住；文档示例不再引用本轮旧路径；`dep_rules` 不扫描失效位置。

### T8: 定向回归与全量回归
- **depends_on**: `[T7]`
- **location**: `tests/`
- **description**: 先跑本轮强相关 suite，再跑全量回归，确认命名收口、结构收口和代码清理没有破坏架构与行为。
- **validation**: 依次运行：
  - `lua -e 'package.path=package.path..";./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua"; require("TestHarness").run_all({require("suites.presentation.presentation_ui"), require("suites.runtime.runtime_bootstrap"), require("suites.domain.land"), require("suites.domain.item"), require("suites.gameplay.gameplay"), require("suites.architecture.cross_module_contract"), require("suites.architecture.architecture_guard_contract"), require("suites.architecture.intent_output_contract"), require("suites.architecture.usecase_boundary_contract")})'`
  - `lua tests/regression.lua`
  预期包含 `dep_rules ok`、`legacy_path_guard ok`、全量回归通过。

## Parallel Execution Groups

| Wave | Tasks | Can Start When |
|------|-------|----------------|
| 1 | `T1` | 立即 |
| 2 | `T2`, `T3`, `T4`, `T5` | `T1` 完成后 |
| 3 | `T6` | `T2`, `T3`, `T4`, `T5` 完成后 |
| 4 | `T7` | `T6` 完成后 |
| 5 | `T8` | `T7` 完成后 |

## Test Plan

- 字符串级检查先分簇执行：`presentation.runtime.ui_`、`presentation.model.ui_`、`game.flow.turn.turn_`、`game.systems.land.landing_`、`game.systems.items.item_`
- 定向 suite 至少覆盖：presentation、runtime bootstrap、land、item、gameplay、architecture guard / boundary / output contract
- 最后跑 `lua tests/regression.lua`
- 验收标准：
  - 没有旧路径残留在源码、测试、护栏或文档
  - 没有新增跨层依赖
  - 没有状态字段、事件名、Port 名的行为变化
  - 全量回归通过

## Assumptions

- 本轮仍采用仓库内原子切换，不保留旧路径兼容桥。
- “清理结构冗余”在本轮等同于目录内前缀收口加小型聚合整理，不等同于跨目录迁位或职责重划。
- 代码层清理只做边界内安全项；任何涉及业务规则、输出协议、Port 边界的清理都明确延后。
- 本轮不引入外部依赖或新 API，不需要额外外部文档核对。
