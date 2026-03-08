# Plan: `src/` 第二轮命名收口盘点

## Summary

这一轮继续做“更短但不丢语义”的命名收口，只覆盖你已选定的“基础层”范围：`presentation/input`、`game/core/runtime`、`game/flow/turn`、`presentation/view/render`。原则是删除父目录已经提供的重复前缀，保留仍然承担职责辨识的词，比如 `policy`、`ports`、`controls`、`slots`。

冻结后的候选映射如下：

- `src/presentation/input/ui_canvas_coordinator.lua -> canvas_coordinator.lua`
- `src/presentation/input/ui_choice_route_policy.lua -> choice_route_policy.lua`
- `src/presentation/input/ui_event_bindings.lua -> event_bindings.lua`
- `src/presentation/input/ui_event_intents.lua -> event_intents.lua`
- `src/presentation/input/ui_event_state.lua -> event_state.lua`
- `src/presentation/input/ui_input_lock_policy.lua -> input_lock_policy.lua`
- `src/presentation/input/ui_modal_state_coordinator.lua -> modal_state_coordinator.lua`
- `src/presentation/input/ui_role_control_lock_policy.lua -> role_control_lock_policy.lua`
- `src/presentation/input/ui_touch_policy.lua -> touch_policy.lua`

- `src/game/core/runtime/game_state_players.lua -> players.lua`
- `src/game/core/runtime/game_state_tiles.lua -> tiles.lua`
- `src/game/core/runtime/game_state_turn.lua -> turn.lua`

- `src/game/flow/turn/gameplay_loop.lua -> loop.lua`
- `src/game/flow/turn/gameplay_loop_ports.lua -> loop_ports.lua`
- `src/game/flow/turn/gameplay_loop_runtime.lua -> loop_runtime.lua`
- `src/game/flow/turn/gameplay_loop_tick_flow.lua -> loop_tick_flow.lua`
- `src/game/flow/turn/gameplay_loop_tick_steps.lua -> loop_tick_steps.lua`
- `src/game/flow/turn/gameplay_loop_ui_sync_defaults.lua -> loop_ui_sync_defaults.lua`

- `src/presentation/view/render/market_view.lua -> market.lua`
- `src/presentation/view/render/market_view_controls.lua -> market_controls.lua`
- `src/presentation/view/render/market_view_slots.lua -> market_slots.lua`

- `src/presentation/view/render/action_anim_registry.lua -> anim_registry.lua`
- `src/presentation/view/render/action_anim_handlers.lua -> anim_handlers.lua`
- `src/presentation/view/render/action_anim_dice.lua -> anim_dice.lua`
- `src/presentation/view/render/action_anim_units.lua -> anim_units.lua`
- `src/presentation/view/render/action_anim_tip_text.lua -> anim_tip_text.lua`
- `src/presentation/view/render/action_anim_overlay_compute.lua -> anim_overlay_compute.lua`
- `src/presentation/view/render/action_anim_overlay_runtime.lua -> anim_overlay_runtime.lua`
- `src/presentation/view/render/action_anim_unit_overlay.lua -> anim_unit_overlay.lua`

明确排除本轮：`turn_*` 家族、`presentation/runtime/ui_*`、`presentation/model/ui_*`、`action_anim.lua` 主入口。这些名字虽然还能更短，但已经承担稳定入口语义，应单开第三轮而不是并入本轮。

## Dependency Graph

`T1 ──┬── T2 ──┐`  
`     ├── T3 ──┤`  
`     ├── T5 ──┤`  
`     └── T6 ── T7 ──┤`  
`T2 ─────────────── T4 ─┤`  
`T3,T4,T5,T7 ───────── T8 ── T9`

## Tasks

### T1: 冻结映射与排除项
- **depends_on**: `[]`
- **location**: `src/`, `tests/`, `docs/`, `.agents/`
- **description**: 生成本轮唯一合法的“旧路径 -> 新路径”表，确认目标路径不存在，并在工作计划中写死排除项：不碰 `turn_*`、`presentation/runtime/ui_*`、`presentation/model/ui_*`、`action_anim.lua`。
- **validation**: 全部目标路径无冲突；映射表覆盖后续所有任务；排除项在计划里单独列明。
- **status**: completed (2026-03-08 15:25Z)
- **work_log**:
  - 核对全部目标路径当前均不存在，可直接进行原子 rename，不需要过渡桥。
  - 确认首轮高命中旧路径仍集中在 `presentation/input/ui_*`、`game/core/runtime/game_state_*`、`game/flow/turn/gameplay_loop*`、`presentation/view/render/market_view*` 与 `action_anim_*` 叶子 helper。
  - 冻结排除项：`turn_*` 家族、`presentation/runtime/ui_*`、`presentation/model/ui_*`、`action_anim.lua` 主入口不纳入本轮。
- **files_touched**:
  - `.agents/swarm_plan.md`
- **gotchas**:
  - `tests/suites/presentation/presentation_ui.lua` 对 `market_view` 有 `package.loaded[...]` 热重载断言，T4 必须同步更新这些 key。
  - `state.gameplay_loop_ports` 是运行时字段，不是模块路径；T7 只改 `require(...)` 目标，不改状态字段名或协议名。

### T2: 收口 `presentation/input/ui_*`
- **depends_on**: `[T1]`
- **location**: `src/presentation/input`, `src/presentation/runtime/canvas_event_router.lua`, `src/presentation/runtime/view_service.lua`, `src/presentation/view/widgets`, `src/presentation/view/canvas`, `tests/suites/presentation`
- **description**: 批量移除 `ui_` 前缀，统一更新静态 `require(...)`、内联 `require(...)`、测试直接引用和 patch target。`intent_dispatcher.lua` 与 `intent_dispatch/` 不再改名。
- **validation**: `rg 'src\.presentation\.input\.ui_' src tests docs .agents` 仅允许命中历史计划文档；`presentation_ui`、`presentation_ui_event_bindings` 可加载新路径。
- **status**: completed (2026-03-08 15:31Z)
- **work_log**:
  - 完成 `presentation/input` 下 9 个 `ui_*` 文件到无 `ui_` 前缀文件名的原子 rename。
  - 同步更新 `canvas_event_router.lua`、`view_service.lua`、widgets、canvas intents、`debug_ports.lua` 和 presentation suite 中的直接 `require(...)`。
  - 保持 `intent_dispatcher.lua` 与 `intent_dispatch/` 原样不动，未扩大到 runtime/model 里的 `ui_*` 入口。
- **files_touched**:
  - `src/presentation/input/canvas_coordinator.lua`
  - `src/presentation/input/choice_route_policy.lua`
  - `src/presentation/input/event_bindings.lua`
  - `src/presentation/input/event_intents.lua`
  - `src/presentation/input/event_state.lua`
  - `src/presentation/input/input_lock_policy.lua`
  - `src/presentation/input/modal_state_coordinator.lua`
  - `src/presentation/input/role_control_lock_policy.lua`
  - `src/presentation/input/touch_policy.lua`
  - `src/presentation/input/intent_dispatch/view_command.lua`
  - `src/presentation/runtime/canvas_event_router.lua`
  - `src/presentation/runtime/view_service.lua`
  - `src/presentation/runtime/ports/debug_ports.lua`
  - `src/presentation/view/widgets/choice_screen_service/common.lua`
  - `src/presentation/view/widgets/choice_screen_service/openers.lua`
  - `src/presentation/view/widgets/popup_renderer.lua`
  - `src/presentation/view/widgets/market_modal_renderer.lua`
  - `src/presentation/view/widgets/modal_presenter.lua`
  - `src/presentation/view/widgets/panel_presenter.lua`
  - `src/presentation/view/render/market_view.lua`
  - `src/presentation/view/render/target_choice_effects.lua`
  - `src/presentation/view/canvas/player_choice/intents.lua`
  - `src/presentation/view/canvas/market/intents.lua`
  - `src/presentation/view/canvas/secondary_confirm/intents.lua`
  - `src/presentation/view/canvas/remote_choice/intents.lua`
  - `src/presentation/view/canvas/target_choice/intents.lua`
  - `tests/suites/presentation/presentation_ui.lua`
  - `tests/suites/presentation/presentation_ui_event_bindings.lua`
  - `.agents/swarm_plan.md`
- **gotchas**:
  - `rg 'src\\.presentation\\.input\\.ui_' ...` 会继续命中 `.agents/swarm_plan.md` 的历史描述，因此校验时要把计划文档视作历史记录，不算代码残留。

### T3: 收口 `game_state_*`
- **depends_on**: `[T1]`
- **location**: `src/game/core/runtime`, `tests/internal/dep_rules.lua`, `tests/suites/gameplay`
- **description**: 将 `game_state_players/tiles/turn` 改为 `players/tiles/turn`，同步 `game.lua` 聚合装配、gameplay suite 和任何显式文件路径引用。
- **validation**: `rg 'src\.game\.core\.runtime\.game_state_' src tests docs .agents` 无残留；`game.lua` 仍能装配三组 state helper。
- **status**: completed (2026-03-08 15:32Z)
- **work_log**:
  - 完成 `game_state_players.lua`、`game_state_tiles.lua`、`game_state_turn.lua` 到 `players.lua`、`tiles.lua`、`turn.lua` 的重命名。
  - 同步更新 `src/game/core/runtime/game.lua` 的聚合 require，保持 `Game` 聚合行为与导出函数不变。
  - 当前仓库内没有额外 gameplay suite 直接引用旧 `game_state_*` 模块路径，验证以字符串扫描与模块加载为主。
- **files_touched**:
  - `src/game/core/runtime/players.lua`
  - `src/game/core/runtime/tiles.lua`
  - `src/game/core/runtime/turn.lua`
  - `src/game/core/runtime/game.lua`
  - `.agents/swarm_plan.md`
- **gotchas**:
  - 新文件 `src/game/core/runtime/turn.lua` 与 `src/game/flow/turn/` 目录同名但不冲突；后续扫尾时必须按完整模块路径检查，避免误报。
- **status**: completed (2026-03-08 15:33Z)
- **work_log**:
  - 完成 `game_state_players.lua`、`game_state_tiles.lua`、`game_state_turn.lua` 到 `players.lua`、`tiles.lua`、`turn.lua` 的重命名。
  - 同步更新 `src/game/core/runtime/game.lua` 的聚合 require，保持 `Game` 组装逻辑不变。
  - 结合 Wave 2 集成校验确认 gameplay 相关加载链可通过新路径装配。
- **files_touched**:
  - `src/game/core/runtime/players.lua`
  - `src/game/core/runtime/tiles.lua`
  - `src/game/core/runtime/turn.lua`
  - `src/game/core/runtime/game.lua`
  - `.agents/swarm_plan.md`
- **gotchas**:
  - 该簇的 require 校验会经过 `src/game/core/runtime/game.lua` 间接加载；如果只测单文件而不测聚合入口，容易漏掉旧路径残留。

### T4: 收口 `market_view*`
- **depends_on**: `[T1, T2]`
- **location**: `src/presentation/view/render`, `src/presentation/view/widgets/market_modal_renderer.lua`, `tests/suites/presentation`, `.agents/plan.md`
- **description**: 将 `market_view.lua` 改为 `market.lua`，companion 文件改为 `market_controls.lua` 和 `market_slots.lua`。不改成裸 `controls` / `slots`，避免在 `render/` 下丢掉业务辨识度。
- **validation**: `rg 'src\.presentation\.view\.render\.market_view' src tests docs .agents` 仅允许历史迁移记录；市场弹窗相关 presentation 用例继续通过。
- **status**: completed (2026-03-08 15:39Z)
- **work_log**:
  - 完成 `market_view.lua`、`market_view_controls.lua`、`market_view_slots.lua` 到 `market.lua`、`market_controls.lua`、`market_slots.lua` 的重命名。
  - 同步更新 `market_modal_renderer.lua`、`view_service.lua` 与 `presentation_ui.lua` 中的直接 require 和 `package.loaded[...]` 热重载 key。
  - 保持市场 companion 的职责分层不变，只做路径收口，不调整市场 UI 逻辑。
- **files_touched**:
  - `src/presentation/view/render/market.lua`
  - `src/presentation/view/render/market_controls.lua`
  - `src/presentation/view/render/market_slots.lua`
  - `src/presentation/view/widgets/market_modal_renderer.lua`
  - `src/presentation/runtime/view_service.lua`
  - `tests/suites/presentation/presentation_ui.lua`
  - `.agents/swarm_plan.md`
- **gotchas**:
  - `tests/suites/presentation/presentation_ui.lua` 依赖 `package.loaded[...]` 热重载校验；如果只改 `require(...)` 而不改 `package.loaded` key，会留下假阳性。

### T5: 收口 `action_anim_*` 叶子 helper
- **depends_on**: `[T1]`
- **location**: `src/presentation/view/render`, `tests/suites/presentation/presentation_ui_action_anim.lua`, `tests/suites/architecture/cross_module_contract.lua`
- **description**: 只把 leaf helper 收口到 `anim_*`，不动 `action_anim.lua` 主入口。同步 `action_anim.lua`、`anim_handlers.lua`、`anim_units.lua`、`anim_unit_overlay.lua` 的内部 require 链。
- **validation**: `rg 'src\.presentation\.view\.render\.action_anim_(registry|handlers|dice|units|tip_text|overlay_compute|overlay_runtime|unit_overlay)' src tests docs .agents` 无残留；`action_anim.lua` 仍是唯一稳定入口。
- **status**: completed (2026-03-08 15:32Z)
- **work_log**:
  - 完成八个 `action_anim_*` 叶子 helper 到 `anim_*` 的重命名。
  - 同步更新 `action_anim.lua` 主入口与 `anim_handlers.lua`、`anim_units.lua`、`anim_unit_overlay.lua` 的内部 require 链。
  - 更新 `presentation_ui_action_anim.lua` 与 `cross_module_contract.lua` 的 helper require，保留 `action_anim.lua` 主入口名称不变。
- **files_touched**:
  - `src/presentation/view/render/anim_registry.lua`
  - `src/presentation/view/render/anim_handlers.lua`
  - `src/presentation/view/render/anim_dice.lua`
  - `src/presentation/view/render/anim_units.lua`
  - `src/presentation/view/render/anim_tip_text.lua`
  - `src/presentation/view/render/anim_overlay_compute.lua`
  - `src/presentation/view/render/anim_overlay_runtime.lua`
  - `src/presentation/view/render/anim_unit_overlay.lua`
  - `src/presentation/view/render/action_anim.lua`
  - `tests/suites/presentation/presentation_ui_action_anim.lua`
  - `tests/suites/architecture/cross_module_contract.lua`
  - `.agents/swarm_plan.md`
- **gotchas**:
  - `legacy_path_guard` 在 T8 只能退休叶子 helper 的旧路径，不能退休主入口 `src.presentation.view.render.action_anim`。
- **status**: completed (2026-03-08 15:33Z)
- **work_log**:
  - 完成 8 个 `action_anim_*` 叶子 helper 到 `anim_*` 的重命名，保留 `action_anim.lua` 主入口原名不动。
  - 同步更新 `action_anim.lua`、`anim_handlers.lua`、`anim_units.lua`、`anim_unit_overlay.lua` 的内部 require 链，以及 `presentation_ui_action_anim`、`cross_module_contract` 的直接引用。
  - 集成运行 `presentation_ui_action_anim` 时，现有告警保持为既有测试噪音，没有新增路径错误或加载错误。
- **files_touched**:
  - `src/presentation/view/render/anim_registry.lua`
  - `src/presentation/view/render/anim_handlers.lua`
  - `src/presentation/view/render/anim_dice.lua`
  - `src/presentation/view/render/anim_units.lua`
  - `src/presentation/view/render/anim_tip_text.lua`
  - `src/presentation/view/render/anim_overlay_compute.lua`
  - `src/presentation/view/render/anim_overlay_runtime.lua`
  - `src/presentation/view/render/anim_unit_overlay.lua`
  - `src/presentation/view/render/action_anim.lua`
  - `tests/suites/presentation/presentation_ui_action_anim.lua`
  - `tests/suites/architecture/cross_module_contract.lua`
  - `.agents/swarm_plan.md`
- **gotchas**:
  - `action_anim.lua` 继续作为稳定入口；后续 T8 / T9 的旧路径扫描必须只退休 leaf helper 根路径，不能把 `src.presentation.view.render.action_anim` 本身列为 retired。

### T6: 先收口 `gameplay_loop_*` 低扇出 helper
- **depends_on**: `[T1]`
- **location**: `src/game/flow/turn`, `tests/suites/gameplay`
- **description**: 先改 `gameplay_loop_runtime`、`gameplay_loop_tick_flow`、`gameplay_loop_tick_steps`、`gameplay_loop_ui_sync_defaults` 到 `loop_*`。这一波先稳定 helper，再处理高扇出入口。
- **validation**: `rg 'src\.game\.flow\.turn\.gameplay_loop_(runtime|tick_flow|tick_steps|ui_sync_defaults)' src tests docs .agents` 无残留；gameplay suite 的 patch target 已更新。
- **status**: completed (2026-03-08 15:30Z)
- **work_log**:
  - 完成 `gameplay_loop_runtime.lua`、`gameplay_loop_tick_flow.lua`、`gameplay_loop_tick_steps.lua`、`gameplay_loop_ui_sync_defaults.lua` 到 `loop_*` 的重命名。
  - 同步更新 `src/game/flow/turn/gameplay_loop.lua`、`src/game/flow/turn/gameplay_loop_ports.lua` 与 `tests/suites/gameplay/gameplay.lua` 的 helper require。
  - 保持 `gameplay_loop.lua`、`gameplay_loop_ports.lua` 与 `state.gameplay_loop_ports` 运行时字段名不变，留给 T7 继续处理入口 rename。
- **files_touched**:
  - `src/game/flow/turn/loop_runtime.lua`
  - `src/game/flow/turn/loop_tick_flow.lua`
  - `src/game/flow/turn/loop_tick_steps.lua`
  - `src/game/flow/turn/loop_ui_sync_defaults.lua`
  - `src/game/flow/turn/gameplay_loop.lua`
  - `src/game/flow/turn/gameplay_loop_ports.lua`
  - `tests/suites/gameplay/gameplay.lua`
  - `.agents/swarm_plan.md`
- **gotchas**:
  - `.agents/swarm_plan.md` 作为执行计划会保留旧路径映射与任务描述，因此旧字符串扫描需要把该计划文件视作历史记录，不作为代码残留处理。

### T7: 再收口 `gameplay_loop` 入口
- **depends_on**: `[T1, T6]`
- **location**: `src/game/flow/turn`, `src/app/bootstrap`, `tests/suites/gameplay`, `docs/architecture`, `.agents/plan.md`
- **description**: 将 `gameplay_loop.lua -> loop.lua`、`gameplay_loop_ports.lua -> loop_ports.lua`。只改模块路径，不改 `state.gameplay_loop_ports` 等运行时字段名，避免把 rename 扩大成状态协议变更。
- **validation**: `rg 'src\.game\.flow\.turn\.gameplay_loop($|\.)' src tests docs .agents` 仅允许历史计划记录；bootstrap 与 gameplay suite 全部切到 `loop` / `loop_ports`。
- **status**: completed (2026-03-08 15:39Z)
- **work_log**:
  - 完成 `gameplay_loop.lua -> loop.lua`、`gameplay_loop_ports.lua -> loop_ports.lua` 的入口重命名。
  - 同步更新 `app/bootstrap`、`tests/TestSupport.lua`、`tests/internal/gameplay_loop_no_ui.lua`、runtime / architecture / gameplay suite 中的直接 require。
  - 保持 `state.gameplay_loop_ports`、`_resolved_gameplay_loop_ports` 等运行时字段名原样不动，只修改模块路径。
- **files_touched**:
  - `src/game/flow/turn/loop.lua`
  - `src/game/flow/turn/loop_ports.lua`
  - `src/game/flow/turn/tick_choice_timeout.lua`
  - `src/game/flow/turn/turn_dispatch.lua`
  - `src/app/bootstrap/game_runtime_bootstrap.lua`
  - `tests/TestSupport.lua`
  - `tests/internal/gameplay_loop_no_ui.lua`
  - `tests/suites/runtime/runtime_bootstrap.lua`
  - `tests/suites/architecture/intent_output_contract.lua`
  - `tests/suites/architecture/architecture_guard_contract.lua`
  - `tests/suites/architecture/usecase_boundary_contract.lua`
  - `tests/suites/gameplay/gameplay.lua`
  - `.agents/swarm_plan.md`
- **gotchas**:
  - 旧路径字符串会继续保留在 `.agents/swarm_plan.md` 的任务说明里；T7 的扫描应把该计划文件视作历史记录，而不是代码残留。

### T8: 全局扫尾与 guard / 文档同步
- **depends_on**: `[T2, T3, T4, T5, T7]`
- **location**: `src/`, `tests/`, `docs/`, `.agents/`, `tests/internal/legacy_path_guard.lua`, `tests/internal/dep_rules.lua`
- **description**: 清掉旧模块路径字符串，更新 `package.loaded[...]`、测试 patch target、架构文档和 `.agents/*`，并把本轮真正退休的路径加入 `legacy_path_guard`。排除项不加入 retired roots。
- **validation**: 每个旧根路径各自 `rg` 为零；`legacy_path_guard.lua` 只新增本轮真实退休路径；`dep_rules` 与文档示例全部指向新路径。

### T9: 定向回归与全量回归
- **depends_on**: `[T8]`
- **location**: `tests/`
- **description**: 先跑受影响最大的热点 suite，再跑全量回归，确认 UI 热点、gameplay loop 和护栏没有被 rename 破坏。
- **validation**: 运行  
  `lua -e 'package.path=package.path..";./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua"; require("TestHarness").run_all({require("suites.presentation.presentation_ui"), require("suites.presentation.presentation_ui_event_bindings"), require("suites.presentation.presentation_ui_action_anim"), require("suites.gameplay.gameplay"), require("suites.runtime.runtime_bootstrap"), require("suites.architecture.cross_module_contract")})'`  
  再运行 `lua tests/regression.lua`；预期包含 `dep_rules ok`、`legacy_path_guard ok`、全量回归通过。

## Parallel Execution Groups

| Wave | Tasks | Can Start When |
|------|-------|----------------|
| 1 | `T1` | 立即 |
| 2 | `T2`, `T3`, `T5`, `T6` | `T1` 完成后 |
| 3 | `T4`, `T7` | `T2` 与 `T6` 完成后 |
| 4 | `T8` | `T3`, `T4`, `T5`, `T7` 完成后 |
| 5 | `T9` | `T8` 完成后 |

## Test Plan

- 先做字符串级检查，分别扫描 `src.presentation.input.ui_`、`src.game.core.runtime.game_state_`、`src.presentation.view.render.market_view`、`src.presentation.view.render.action_anim_*` 叶子 helper、`src.game.flow.turn.gameplay_loop*`。
- 再跑热点 suite：`presentation_ui`、`presentation_ui_event_bindings`、`presentation_ui_action_anim`、`gameplay`、`runtime_bootstrap`、`cross_module_contract`。
- 最后跑 `lua tests/regression.lua`，确认护栏、退休路径和整仓回归闭合。

## Assumptions

- 本轮仍然采用仓库内原子切换，不保留旧路径兼容桥。
- “激进收口”只体现在覆盖范围，不体现在任意砍掉职责词；因此保留 `policy`、`ports`、`controls`、`slots` 等剩余辨识词。
- 本轮只涉及仓库内 Lua 模块路径，不引入第三方依赖或外部 API 变更，不需要额外文档检索。
- 如果后续还要继续压 `turn_*`、`presentation/runtime/ui_*`、`presentation/model/ui_*` 或 `action_anim.lua` 主入口，应单开第三轮计划，不并入本轮。
