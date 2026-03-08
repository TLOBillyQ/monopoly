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

### T2: 收口 `presentation/runtime/ui_*` 与 `presentation/model/ui_*`
- **depends_on**: `[T1]`
- **location**: `src/presentation/runtime`, `src/presentation/model`, `src/presentation/view`, `tests/suites/presentation`, `tests/suites/runtime`
- **description**: 统一切换 runtime/model 的 `ui_*` 模块路径与引用，但不改 `state.ui_runtime`、`ui_model` 数据结构字段、`UIManager` 使用方式。这里只改模块名，不改模型 shape。
- **validation**: `rg 'src\.presentation\.(runtime\.ui_|model\.ui_)' src tests docs .agents` 仅允许历史计划记录；`presentation_ui`、`runtime_bootstrap` 能加载新路径。

### T3: 收口 `game/flow/turn/turn_*`
- **depends_on**: `[T1]`
- **location**: `src/game/flow/turn`, `src/app/bootstrap`, `tests/suites/gameplay`, `tests/suites/architecture`, `tests/suites/runtime`
- **description**: 只收口 `turn_*` 文件名，不动 `tick_*`、`auto_*`、`loop_*`、`state.gameplay_loop_ports` 等稳定词。同步所有 direct require、动态 require、测试 patch target。`turn_runtime.lua` 继续保留为稳定入口，只改路径，不删除 alias 行为。
- **validation**: `rg 'src\.game\.flow\.turn\.turn_' src tests docs .agents` 仅允许历史计划记录；`gameplay`、`runtime_bootstrap`、`architecture_guard_contract` 能走完整加载链。

### T4: 收口 `land/landing_*` 结构冗余
- **depends_on**: `[T1]`
- **location**: `src/game/systems/land`, `tests/suites/domain/land.lua`, `tests/suites/gameplay/gameplay.lua`, `docs/architecture`
- **description**: 把 `landing_effects/` 收口为 `effects/`，并把 `landing_effect_executors.lua`、`landing_presenter.lua`、`specs/landing_effects.lua` 与子模块文件名改为目录内自然命名。保留 `land_*` 家族不动，本轮只清 `landing_*`。
- **validation**: `rg 'src\.game\.systems\.land\.landing_' src tests docs .agents` 仅允许历史计划记录；`domain.land` 和相关 gameplay land 路径通过。

### T5: 收口 `items/item_*` 结构冗余
- **depends_on**: `[T1]`
- **location**: `src/game/systems/items`, `src/game/systems/choices/handlers/item.lua`, `tests/suites/domain/item.lua`, `tests/suites/gameplay/gameplay.lua`
- **description**: 批量去掉 `game/systems/items` 下文件名前缀 `item_`。保持目录名 `items/`、choice kind、日志文案、事件语义不变，只改模块路径和引用。
- **validation**: `rg 'src\.game\.systems\.items\.item_' src tests docs .agents` 仅允许历史计划记录；`domain.item`、`gameplay` 通过。

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
