# Plan: `src/` 冗余路径重命名

## Summary

目标是做一轮“保守但彻底”的命名收口：只改 `src/` 下明显重复父目录语义的目录和文件名，统一保持完整英文单词，不做缩写，不保留旧路径兼容桥，仓库内一次性原子切换。

本轮只覆盖这些热点：

- `core/choice`：去掉文件名前缀 `choice_`
  - `choice_contract.lua -> contract.lua`
  - `choice_route_policy.lua -> route_policy.lua`
- `game/systems/choices`：去掉文件名前缀 `choice_`，并把 `choice_handlers/` 收口成 `handlers/`
  - `choice_registry.lua -> registry.lua`
  - `choice_resolver.lua -> resolver.lua`
  - `choice_handlers/ -> handlers/`
  - `item_choice_handler.lua -> item.lua`
  - `land_choice_handler.lua -> land.lua`
  - `market_choice_handler.lua -> market.lua`
  - `optional_effect_handler.lua -> optional_effect.lua`
- `presentation/input`：去掉 `ui_` 和 `dispatcher/flow` 重复
  - `ui_intent_dispatcher.lua -> intent_dispatcher.lua`
  - `ui_intent_dispatcher/ -> intent_dispatch/`
  - `game_action_dispatcher.lua -> game_action.lua`
  - `view_command_dispatcher.lua -> view_command.lua`
  - `item_phase_ask_flow.lua -> item_phase_ask.lua`
  - `pre_confirm_flow.lua -> pre_confirm.lua`
- `presentation/runtime`：只去掉重复目录名，保留 `*_ports.lua` 语义
  - `presentation_ports/ -> ports/`
  - `presentation_ports.lua` 保持不改
  - `host_runtime.lua -> host.lua`
  - `host_runtime/ -> host/`
  - `ui_view_service.lua -> view_service.lua`
  - `ui_view_service/ -> view_service/`
- `presentation/view/widgets`：去掉 `ui_` 前缀
  - `ui_choice.lua -> choice.lua`
  - `ui_modal_presenter.lua -> modal_presenter.lua`
  - `ui_panel.lua -> panel.lua`
  - `ui_panel_presenter.lua -> panel_presenter.lua`
  - `ui_panel_player_slots.lua -> panel_player_slots.lua`
  - `ui_panel_cash_delta.lua -> panel_cash_delta.lua`
  - `ui_turn_effects.lua -> turn_effects.lua`
- `presentation/view/render`：统一 `status3d` 命名
  - `status_3_d_service.lua -> status3d.lua`
  - `status3d_service/ -> status3d/`

## Important Changes

- 所有 `require("src....")`、内联 `require(...)`、`package.loaded[...]`、测试里的 monkey patch 目标都必须同步改到新路径，不能只改顶部 `local x = require(...)`。
- `tests/internal/dep_rules.lua` 中针对 `src/presentation/runtime/ports` 的 `root` 必须随目录改成 `src/presentation/runtime/ports`；这是目录 rename 的同波依赖，不放到最后。
- `tests/internal/legacy_path_guard.lua` 不能提前加新“退休路径”；必须在所有源码、测试、文档都切完后，同一波把本次旧路径加入 retired 列表，防止中途把工作树锁死。
- `docs/architecture/boundaries.md`、`docs/architecture/layer-model.md`、`docs/architecture/health_signals.md`、`.agents/plan.md`、`.agents/research.md` 都要同步更新路径示例和说明。
- `presentation_ports.lua` 保持原名，不改成 `ports.lua`。原因是仓库已把它作为 `*_ports.lua` 的 canonical bundle 示例，改名会和当前命名语义冲突。

## Dependency Graph

```text
T1 ──┬── T2 ──┐
     ├── T3 ──┤
     ├── T4 ──┤
     ├── T5 ──┤
     └── T6 ──┘
                └── T7 ── T8
```

## Tasks

### T1: 建立最终映射与迁移清单
- **depends_on**: []
- **location**: `src/`, `tests/`, `docs/`, `.agents/`
- **description**: 冻结“旧路径 -> 新路径”映射；逐类列出受影响引用面：静态 `require`、内联 `require`、`package.loaded`、测试 patch target、文档示例、guard root。
- **validation**: 产出一份无歧义映射表；确认不存在目标重名冲突；明确 `presentation_ports.lua` 保持不改。
- **status**: completed (2026-03-08 14:08Z)
- **mapping**:
  - `src/core/choice/contract.lua -> src/core/choice/contract.lua`
  - `src/core/choice/route_policy.lua -> src/core/choice/route_policy.lua`
  - `src/game/systems/choices/registry.lua -> src/game/systems/choices/registry.lua`
  - `src/game/systems/choices/resolver.lua -> src/game/systems/choices/resolver.lua`
  - `src/game/systems/choices/choice_handlers/ -> src/game/systems/choices/handlers/`
  - `src/game/systems/choices/handlers/item.lua -> src/game/systems/choices/handlers/item.lua`
  - `src/game/systems/choices/handlers/land.lua -> src/game/systems/choices/handlers/land.lua`
  - `src/game/systems/choices/handlers/market.lua -> src/game/systems/choices/handlers/market.lua`
  - `src/game/systems/choices/handlers/optional_effect.lua -> src/game/systems/choices/handlers/optional_effect.lua`
  - `src/presentation/input/intent_dispatch.lua -> src/presentation/input/intent_dispatcher.lua`
  - `src/presentation/input/intent_dispatch/ -> src/presentation/input/intent_dispatch/`
  - `src/presentation/input/intent_dispatch/game_action_dispatcher.lua -> src/presentation/input/intent_dispatch/game_action.lua`
  - `src/presentation/input/intent_dispatch/view_command_dispatcher.lua -> src/presentation/input/intent_dispatch/view_command.lua`
  - `src/presentation/input/intent_dispatch/item_phase_ask_flow.lua -> src/presentation/input/intent_dispatch/item_phase_ask.lua`
  - `src/presentation/input/intent_dispatch/pre_confirm_flow.lua -> src/presentation/input/intent_dispatch/pre_confirm.lua`
  - `src/presentation/runtime/ports/ -> src/presentation/runtime/ports/`
  - `src/presentation/runtime/host.lua -> src/presentation/runtime/host.lua`
  - `src/presentation/runtime/host/ -> src/presentation/runtime/host/`
  - `src/presentation/runtime/view_service.lua -> src/presentation/runtime/view_service.lua`
  - `src/presentation/runtime/view_service/ -> src/presentation/runtime/view_service/`
  - `src/presentation/view/widgets/choice.lua -> src/presentation/view/widgets/choice.lua`
  - `src/presentation/view/widgets/modal_presenter.lua -> src/presentation/view/widgets/modal_presenter.lua`
  - `src/presentation/view/widgets/panel.lua -> src/presentation/view/widgets/panel.lua`
  - `src/presentation/view/widgets/panel_presenter.lua -> src/presentation/view/widgets/panel_presenter.lua`
  - `src/presentation/view/widgets/panel_player_slots.lua -> src/presentation/view/widgets/panel_player_slots.lua`
  - `src/presentation/view/widgets/panel_cash_delta.lua -> src/presentation/view/widgets/panel_cash_delta.lua`
  - `src/presentation/view/widgets/turn_effects.lua -> src/presentation/view/widgets/turn_effects.lua`
  - `src/presentation/view/render/status3d.lua -> src/presentation/view/render/status3d.lua`
  - `src/presentation/view/render/status3d/ -> src/presentation/view/render/status3d/`
- **reference_surface**:
  - 静态与内联 `require(...)`：`src/`, `tests/`, `docs/architecture/`, `.agents/`
  - `package.loaded[...]` / monkey patch target：`tests/suites/domain/market.lua`, `tests/suites/gameplay/gameplay.lua` 等 suite 与 `tests/TestSupport.lua`
  - guard / rule roots：`tests/internal/dep_rules.lua`, `tests/internal/legacy_path_guard.lua`
  - 文档示例：`docs/architecture/*.md`, `.agents/*.md`
- **work_log**:
  - 确认全部目标路径当前不存在，无命名冲突。
  - 明确 `src/presentation/runtime/ports.lua` 保持原名，仅其目录 `presentation_ports/` 重命名为 `ports/`。
  - 确认 Wave 2 可按 `T2/T3/T4/T5` 并行拆分，`T6` 仍依赖 `T5` 先完成。
- **files_touched**: `.agents/swarm_plan.md`
- **gotchas**:
  - `status3d_service/` 目录与 `status_3_d_service.lua` 主文件需要同波切换，避免内部 require 短暂断裂。
  - `presentation_ports.lua` 与 `presentation_ports/` 仅一处改名，引用校验时必须允许顶层 bundle 文件继续存在。

### T2: 执行 `choice` / `choices` 集群重命名
- **depends_on**: [T1]
- **location**: `src/core/choice`, `src/game/systems/choices`, `src/game/flow`, `tests/suites/domain`, `tests/TestSupport.lua`
- **description**: 完成 `contract.lua`、`route_policy.lua`、`registry.lua`、`resolver.lua`、`handlers/` 及四个 handler 文件改名，并同步所有 choice 相关引用。
- **validation**: `rg 'src\\.core\\.choice\\.choice_|src\\.game\\.systems\\.choices\\.choice_' src tests docs .agents` 无残留；`tests/suites/domain/market.lua` 的 `package.loaded[...]` 已改到新路径；`turn_decision.lua` 的动态 `require` 已更新。
- **status**: completed (2026-03-08 14:09Z)
- **work_log**:
  - 完成 `src/core/choice/*`、`src/game/systems/choices/*` 的目标文件和目录重命名，并把 registry 内部 handler require 全部切到 `handlers/*`。
  - 同步更新 `src/game/flow/intent/intent_dispatcher.lua`、`src/game/flow/turn/turn_decision.lua`、`src/game/core/runtime/bootstrap.lua`、`tests/TestSupport.lua`、`tests/suites/domain/{market,land}.lua` 等直接引用点。
  - 更新 `tests/suites/domain/market.lua` 的 `package.loaded[...]` 重置键到 `src.game.systems.choices.handlers.market` / `registry` / `resolver` 新路径。
- **files_touched**:
  - `src/core/choice/contract.lua`
  - `src/core/choice/route_policy.lua`
  - `src/game/systems/choices/registry.lua`
  - `src/game/systems/choices/resolver.lua`
  - `src/game/systems/choices/handlers/item.lua`
  - `src/game/systems/choices/handlers/land.lua`
  - `src/game/systems/choices/handlers/market.lua`
  - `src/game/systems/choices/handlers/optional_effect.lua`
  - `src/game/flow/intent/intent_dispatcher.lua`
  - `src/game/flow/turn/turn_decision.lua`
  - `src/game/flow/turn/turn_choice_auto_policy.lua`
  - `src/game/flow/turn/tick_choice_timeout.lua`
  - `src/game/flow/turn/turn_dispatch_validator.lua`
  - `src/game/core/runtime/bootstrap.lua`
  - `src/game/systems/market/application/choice_session.lua`
  - `src/presentation/model/ui_model/item_slice.lua`
  - `src/presentation/view/render/target_choice_effects.lua`
  - `src/presentation/view/widgets/ui_choice.lua`
  - `src/presentation/input/ui_choice_route_policy.lua`
  - `tests/TestSupport.lua`
  - `tests/suites/domain/market.lua`
  - `tests/suites/domain/land.lua`
  - `tests/suites/architecture/usecase_boundary_contract.lua`
- **gotchas**:
  - 目标 domain suite 受 `src.presentation.runtime.ui_view_service` 旧路径依赖影响，当前 Wave 2 的 T4 未完成前无法作为 T2 绿灯依据；因此仅保留字符串级校验和模块级 require 校验。

### T3: 执行 `presentation/input` dispatcher 集群重命名
- **depends_on**: [T1]
- **location**: `src/presentation/input`, `src/presentation/runtime/canvas_event_router.lua`, `tests/suites/presentation`, `tests/suites/architecture/usecase_boundary_contract.lua`
- **description**: 把 `ui_intent_dispatcher` 主文件和子目录迁到 `intent_dispatcher.lua` / `intent_dispatch/`，并把 `game_action_dispatcher`、`view_command_dispatcher`、`item_phase_ask_flow`、`pre_confirm_flow` 收口成更短文件名。
- **validation**: `rg 'src\\.presentation\\.input\\.ui_intent_dispatcher' src tests docs .agents` 无残留；presentation suite 中相关 `require` 全部指向新路径。
- **status**: completed (2026-03-08 14:10Z)
- **work_log**:
  - 完成 `src/presentation/input/ui_intent_dispatcher.lua` 到 `src/presentation/input/intent_dispatcher.lua` 的迁移，并将子目录重命名为 `src/presentation/input/intent_dispatch/`。
  - 同步将 `game_action_dispatcher.lua`、`view_command_dispatcher.lua`、`item_phase_ask_flow.lua`、`pre_confirm_flow.lua` 收口为 `game_action.lua`、`view_command.lua`、`item_phase_ask.lua`、`pre_confirm.lua`，并把内部 `require(...)` 全部切到新路径。
  - 更新 `src/presentation/runtime/canvas_event_router.lua`、`tests/suites/presentation/presentation_ui.lua`、`tests/suites/architecture/usecase_boundary_contract.lua` 的入口引用，确保测试与运行时入口不再指向旧路径。
- **files_touched**:
  - `src/presentation/input/intent_dispatcher.lua`
  - `src/presentation/input/intent_dispatch/game_action.lua`
  - `src/presentation/input/intent_dispatch/view_command.lua`
  - `src/presentation/input/intent_dispatch/item_phase_ask.lua`
  - `src/presentation/input/intent_dispatch/pre_confirm.lua`
  - `src/presentation/input/intent_dispatch/role_context.lua`
  - `src/presentation/input/intent_dispatch/turn_action_port.lua`
  - `src/presentation/runtime/canvas_event_router.lua`
  - `tests/suites/presentation/presentation_ui.lua`
  - `tests/suites/architecture/usecase_boundary_contract.lua`
  - `.agents/swarm_plan.md`
- **gotchas**:
  - `tests/suites/presentation/presentation_ui.lua` 在本波验证时被并行中的 T4 阻塞：当前工作树已暂时移走 `src/presentation/runtime/host_runtime.lua`，导致 suite 在加载 `ui_event_handlers.lua` 时提前失败；因此 T3 的独立验证以旧路径残留扫描和 `usecase_boundary_contract` 单跑通过为准。

### T4: 执行 `presentation/runtime` 核心集群重命名
- **depends_on**: [T1]
- **location**: `src/presentation/runtime`, `src/app/bootstrap`, `tests/suites/runtime`, `tests/internal/dep_rules.lua`
- **description**: 顺序完成三件事，不并行拆开：
  1. `presentation_ports/ -> ports/`，但保留 `presentation_ports.lua`
  2. `host_runtime.lua` / `host_runtime/` -> `host.lua` / `host/`
  3. `ui_view_service.lua` / `ui_view_service/` -> `view_service.lua` / `view_service/`
  同时更新 bootstrap、runtime tests、presentation tests 和 `dep_rules` 根路径。
- **validation**: `rg 'src\\.presentation\\.runtime\\.(host_runtime|ui_view_service|presentation_ports)' src tests docs .agents` 只允许保留 `presentation_ports.lua` 顶层 bundle 自身引用；`tests/internal/dep_rules.lua` 的 root 已改到 `src/presentation/runtime/ports`。

### T5: 执行低扇出 presentation 叶子模块重命名
- **depends_on**: [T1]
- **location**: `src/presentation/view/widgets`, `src/presentation/view/render`, `tests/suites/presentation`
- **description**: 先改低扇出文件，降低后续大入口改名成本：
  - `ui_panel_player_slots.lua -> panel_player_slots.lua`
  - `ui_panel_cash_delta.lua -> panel_cash_delta.lua`
  - `ui_turn_effects.lua -> turn_effects.lua`
  - `status_3_d_service.lua -> status3d.lua`
  - `status3d_service/ -> status3d/`
- **validation**: `rg 'status_3_d_service|ui_panel_player_slots|ui_panel_cash_delta|ui_turn_effects' src tests docs .agents` 无残留；相关 action anim / status3d / panel 测试引用已切换。

### T6: 执行高扇出 widget 入口重命名
- **depends_on**: [T1, T5]
- **location**: `src/presentation/view/widgets`, `src/presentation/model/ui_model`, `src/presentation/runtime`, `src/presentation/view/canvas`, `tests/suites/presentation`
- **description**: 改高扇出入口文件：
  - `ui_choice.lua -> choice.lua`
  - `ui_modal_presenter.lua -> modal_presenter.lua`
  - `ui_panel.lua -> panel.lua`
  - `ui_panel_presenter.lua -> panel_presenter.lua`
  并同步 model slice、runtime service、canvas presenter 与大体量 UI suite 引用。
- **validation**: `rg 'src\\.presentation\\.view\\.widgets\\.ui_' src tests docs .agents` 无残留；`panel_slice.lua`、`choice_slice.lua`、`base/presenter.lua`、`view_service.lua` 都已切到新路径。

### T7: 全局扫尾与 guard / 文档同步
- **depends_on**: [T2, T3, T4, T5, T6]
- **location**: `src/`, `tests/`, `docs/`, `.agents/`, `tests/internal/legacy_path_guard.lua`
- **description**: 做最终全局清理：
  - 清掉所有旧路径字符串
  - 更新 `package.loaded[...]` 和测试 patch target
  - 更新架构文档与 `.agents/*`
  - 在确认没有旧路径残留后，把本次退休路径加入 `legacy_path_guard`
- **validation**: 对每个旧根路径执行 `rg` 均无匹配；`legacy_path_guard.lua` 已把本次 retired roots 纳入列表，且不会误伤仍在使用的新路径。

### T8: 验证与收口
- **depends_on**: [T7]
- **location**: `tests/`, `docs/architecture/health_signals.md`
- **description**: 先跑热点 suite，再跑全量回归，确认 rename 没破坏架构护栏、presentation 热点和 runtime bootstrap。
- **validation**:
  - `lua -e 'package.path=package.path..";./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua"; require("TestHarness").run_all({require("suites.domain.market"), require("suites.domain.land"), require("suites.architecture.usecase_boundary_contract"), require("suites.architecture.intent_output_contract"), require("suites.architecture.architecture_guard_contract"), require("suites.presentation.presentation_ui"), require("suites.runtime.runtime_bootstrap")})'`
  - `lua tests/regression.lua`

## Parallel Execution Groups

| Wave | Tasks | Can Start When |
|------|-------|----------------|
| 1 | T1 | 立即 |
| 2 | T2, T3, T4, T5 | T1 完成后 |
| 3 | T6 | T5 完成后 |
| 4 | T7 | T2, T3, T4, T6 完成后 |
| 5 | T8 | T7 完成后 |

## Test Plan

- 重命名完成后先做字符串级检查：
  - 每个旧模块根路径执行一次 `rg`
  - 重点检查动态 `require`、`package.loaded`、测试 patch target
- 然后跑定向 suite：
  - choice/domain：`market`, `land`
  - architecture：`usecase_boundary_contract`, `intent_output_contract`, `architecture_guard_contract`
  - presentation/runtime：`presentation_ui`, `runtime_bootstrap`
- 最后跑 `lua tests/regression.lua`
- 验收标准：
  - 所有 suite 通过
  - `dep_rules` 仍覆盖新的 `src/presentation/runtime/ports`
  - `legacy_path_guard` 能拦住旧路径，不误报新路径
  - `docs/architecture/*` 与 `.agents/*` 不再引用旧名称

## Assumptions

- 采用“仓库内原子切换”，不保留旧路径兼容桥。
- 只做上面列出的热点，不对 `turn_*`、`land_*`、`market_*` 等虽长但语义仍清晰的名字继续压缩。
- 保持 `_port.lua`、`*_ports.lua`、`*_port_adapter.lua` 语义不变，因此 `presentation_ports.lua` 顶层 bundle 文件不改名。
- 当前回合处于 Plan Mode；执行时先把本计划原样保存为 `src-rename-plan.md`，再开始实际改动。
