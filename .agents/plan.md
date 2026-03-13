# Plan: `src/` 命名与层级重构（Swarm 版）

## Summary

- 目标是一次性完成模块重命名与归位，不保留旧路径兼容壳，不改导出函数名或 table 形状，不跨 `app/core/game/infrastructure/presentation` 顶层根目录。
- 重构分三条可并行主线：`presentation`、`turn`、`market`。每条主线先完成“源文件搬迁/内部引用修正”，再进入跨子系统整合、测试字符串替换、文档收尾。
- 关键整合点只有少数几个：`src/game/flow/turn/loop.lua`、`src/app/bootstrap/game_startup.lua`、`src/game/core/runtime/composition_root.lua`、`src/app/bootstrap/payment/eggy_paid_purchase_gateway.lua`。这些文件单独放到集成任务里，避免多 agent 冲突。
- 不引入新外部依赖，因此无需额外拉取外部文档；所有验证依赖仓库现有测试/护栏脚本。

## Public Module Path Changes

- `src.presentation.runtime.canvas_specs.*` 全部切到 `src.presentation.input.canvas_routes.*`，其中 `base/intents.lua -> base.lua`，`base/item_slot_intents.lua -> item_slots.lua`，其余 `*/intents.lua -> *.lua`。
- `src.presentation.runtime.canvas_registry` 改为 `src.presentation.input.canvas_route_registry`。
- `src.presentation.runtime.view*` 改为 `src.presentation.runtime.ui_runtime*`。
- `src.presentation.runtime.controllers.choice_screen_service.common` 改为 `src.presentation.runtime.controllers.choice_screens.helpers`；`...openers` 改为 `...choice_screens.openers`。
- `src.game.flow.turn.*` 按目录重组到 `dispatch/`、`phases/`、`runtime/`、`waits/`、`auto/`、`policies/`；`script.lua -> session_script.lua`，`engine.lua -> scheduler_runtime.lua`。
- `src.game.systems.market.application.*` 改为 `src.game.systems.market.query.*`、`choice.*`、`purchase.*` 或 `src.game.systems.market.auto`；`src/game/systems/market/init.lua` 的 façade 形状保持不变。

## T0 Baseline Mapping

### Presentation mapping

| old module | new module |
|---|---|
| `src.presentation.runtime.canvas_specs.always_show.intents` | `src.presentation.input.canvas_routes.always_show` |
| `src.presentation.runtime.canvas_specs.base.intents` | `src.presentation.input.canvas_routes.base` |
| `src.presentation.runtime.canvas_specs.base.item_slot_intents` | `src.presentation.input.canvas_routes.item_slots` |
| `src.presentation.runtime.canvas_specs.market.intents` | `src.presentation.input.canvas_routes.market` |
| `src.presentation.runtime.canvas_specs.player_choice.intents` | `src.presentation.input.canvas_routes.player_choice` |
| `src.presentation.runtime.canvas_specs.popup.intents` | `src.presentation.input.canvas_routes.popup` |
| `src.presentation.runtime.canvas_specs.remote_choice.intents` | `src.presentation.input.canvas_routes.remote_choice` |
| `src.presentation.runtime.canvas_specs.secondary_confirm.intents` | `src.presentation.input.canvas_routes.secondary_confirm` |
| `src.presentation.runtime.canvas_specs.target_choice.intents` | `src.presentation.input.canvas_routes.target_choice` |
| `src.presentation.runtime.canvas_registry` | `src.presentation.input.canvas_route_registry` |
| `src.presentation.runtime.view` | `src.presentation.runtime.ui_runtime` |
| `src.presentation.runtime.view.assets` | `src.presentation.runtime.ui_runtime.assets` |
| `src.presentation.runtime.view.debug` | `src.presentation.runtime.ui_runtime.debug` |
| `src.presentation.runtime.view.item_slots` | `src.presentation.runtime.ui_runtime.item_slots` |
| `src.presentation.runtime.view.state` | `src.presentation.runtime.ui_runtime.state` |
| `src.presentation.runtime.controllers.choice_screen_service.common` | `src.presentation.runtime.controllers.choice_screens.helpers` |
| `src.presentation.runtime.controllers.choice_screen_service.openers` | `src.presentation.runtime.controllers.choice_screens.openers` |

### Turn mapping

| old module | new module |
|---|---|
| `src.game.flow.turn.action_gate` | `src.game.flow.turn.policies.action_gate` |
| `src.game.flow.turn.anim` | `src.game.flow.turn.runtime.anim` |
| `src.game.flow.turn.auto_context` | `src.game.flow.turn.auto.context` |
| `src.game.flow.turn.auto_runner` | `src.game.flow.turn.auto.runner` |
| `src.game.flow.turn.await` | `src.game.flow.turn.waits.await` |
| `src.game.flow.turn.camera_policy` | `src.game.flow.turn.policies.camera_policy` |
| `src.game.flow.turn.choice_auto_policy` | `src.game.flow.turn.auto.choice_auto_policy` |
| `src.game.flow.turn.decision` | `src.game.flow.turn.runtime.decision` |
| `src.game.flow.turn.dispatch` | `src.game.flow.turn.dispatch.action_dispatcher` |
| `src.game.flow.turn.dispatch_validator` | `src.game.flow.turn.dispatch.validator` |
| `src.game.flow.turn.engine` | `src.game.flow.turn.runtime.scheduler_runtime` |
| `src.game.flow.turn.item_auto_play_context` | `src.game.flow.turn.auto.item_play_context` |
| `src.game.flow.turn.item_slot_data` | `src.game.flow.turn.dispatch.item_slot_data` |
| `src.game.flow.turn.land` | `src.game.flow.turn.phases.land` |
| `src.game.flow.turn.logger` | `src.game.flow.turn.runtime.logger` |
| `src.game.flow.turn.loop_ports` | `src.game.flow.turn.runtime.ports` |
| `src.game.flow.turn.loop_runtime` | `src.game.flow.turn.runtime.loop_runtime` |
| `src.game.flow.turn.loop_tick_flow` | `src.game.flow.turn.runtime.tick_flow` |
| `src.game.flow.turn.loop_tick_steps` | `src.game.flow.turn.runtime.tick_steps` |
| `src.game.flow.turn.loop_ui_sync_defaults` | `src.game.flow.turn.runtime.ui_sync_defaults` |
| `src.game.flow.turn.move` | `src.game.flow.turn.phases.move` |
| `src.game.flow.turn.move_followup` | `src.game.flow.turn.phases.move_followup` |
| `src.game.flow.turn.phase_registry` | `src.game.flow.turn.phases.registry` |
| `src.game.flow.turn.role_control_policy` | `src.game.flow.turn.policies.role_control_policy` |
| `src.game.flow.turn.roll` | `src.game.flow.turn.phases.roll` |
| `src.game.flow.turn.script` | `src.game.flow.turn.runtime.session_script` |
| `src.game.flow.turn.start` | `src.game.flow.turn.phases.start` |
| `src.game.flow.turn.tick_choice_timeout` | `src.game.flow.turn.waits.choice_timeout` |
| `src.game.flow.turn.tick_timeout` | `src.game.flow.turn.waits.timeout` |
| `src.game.flow.turn.tick_ui_gate` | `src.game.flow.turn.waits.ui_gate` |
| `src.game.flow.turn.tick_ui_sync` | `src.game.flow.turn.waits.ui_sync` |
| `src.game.flow.turn.timer_policy` | `src.game.flow.turn.policies.timer_policy` |

`src/game/flow/turn/loop.lua` 保持原位，但其内部引用统一切到上表新路径；它是 T5 唯一允许保留旧物理位置的 turn 文件。

### Market mapping

| old module | new module |
|---|---|
| `src.game.systems.market.application.auto` | `src.game.systems.market.auto` |
| `src.game.systems.market.application.context` | `src.game.systems.market.query.context` |
| `src.game.systems.market.application.eligibility` | `src.game.systems.market.query.eligibility` |
| `src.game.systems.market.application.choice` | `src.game.systems.market.choice.builder` |
| `src.game.systems.market.application.choice_outcome` | `src.game.systems.market.choice.outcome` |
| `src.game.systems.market.application.choice_session` | `src.game.systems.market.choice.session` |
| `src.game.systems.market.application.feedback` | `src.game.systems.market.choice.feedback` |
| `src.game.systems.market.application.fulfillment` | `src.game.systems.market.purchase.fulfillment` |
| `src.game.systems.market.application.local_purchase` | `src.game.systems.market.purchase.local_purchase` |
| `src.game.systems.market.application.paid_fulfillment` | `src.game.systems.market.purchase.paid_fulfillment` |
| `src.game.systems.market.application.paid_purchase_callback` | `src.game.systems.market.purchase.paid_purchase_callback` |
| `src.game.systems.market.application.purchase` | `src.game.systems.market.purchase.core` |
| `src.game.systems.market.application.purchase_policy` | `src.game.systems.market.purchase.policy` |

### Residual scan commands

- presentation:
  - `rg -n "src\.presentation\.runtime\.(canvas_specs|canvas_registry|view|controllers\.choice_screen_service)" src tests docs`
- turn:
  - `rg -n "src\.game\.flow\.turn\.(action_gate|anim|auto_context|auto_runner|await|camera_policy|choice_auto_policy|decision|dispatch|dispatch_validator|engine|item_auto_play_context|item_slot_data|land|logger|loop_ports|loop_runtime|loop_tick_flow|loop_tick_steps|loop_ui_sync_defaults|move|move_followup|phase_registry|role_control_policy|roll|script|start|tick_choice_timeout|tick_timeout|tick_ui_gate|tick_ui_sync|timer_policy)" src tests docs`
- market:
  - `rg -n "src\.game\.systems\.market\.application(\.|$)" src tests docs`

### Bridge files reserved for T5

- `src/game/flow/turn/loop.lua`
- `src/app/bootstrap/game_startup.lua`
- `src/game/core/runtime/composition_root.lua`
- `src/app/bootstrap/payment/eggy_paid_purchase_gateway.lua`

## Dependency Graph

```text
T0
├── T1 ── T2 ──┐
├── T3 ────────┼── T5 ── T6 ── T7 ── T8
└── T4 ────────┘
```

## Tasks

### T0: 建立映射表与残留检查基线
- **depends_on**: []
- **location**: repo root；`src/**`；`tests/**`；`docs/**`
- **description**: 先生成完整 old->new 模块映射表，并用 `rg` 盘点三大家族的 `require(...)`、`package.loaded[...]`、`_reload_module(...)`、`_load_fresh(...)`、文档字符串引用。把会跨任务冲突的桥接文件单独标记：`src/game/flow/turn/loop.lua`、`src/app/bootstrap/game_startup.lua`、`src/game/core/runtime/composition_root.lua`、`src/app/bootstrap/payment/eggy_paid_purchase_gateway.lua`。
- **validation**: 映射表覆盖所有将被删除的旧模块路径；三组残留检查命令可直接复用到最终验收。
- **status**: Completed
- **log**:
  - `2026-03-13 23:23 +0800` 建立三大家族 old->new 映射表，补齐 turn/market 的精确目标模块名，并把四个跨任务桥接文件单独保留给 T5。
  - `2026-03-13 23:23 +0800` 固化三组 `rg` 残留检查命令，后续 T5/T8 直接复用同一批模式复扫 `src tests docs`。
- **files edited/created**: `.agents/plan.md`

### T1: `presentation` 源文件搬迁与内部归位
- **depends_on**: [T0]
- **location**: `src/presentation/runtime/canvas_specs/**`；`src/presentation/runtime/canvas_registry.lua`；`src/presentation/runtime/view/**`；`src/presentation/runtime/controllers/choice_screen_service/**`
- **description**: 搬迁并重命名 `canvas_specs`、`canvas_registry`、`view`、`choice_screen_service`，只修正这些被搬迁家族内部的相互引用；不要碰 `src/app/**` 与测试。
- **validation**: 新路径全部存在；旧路径文件全部消失；被搬迁家族内部不再引用旧模块路径。
- **status**: Completed
- **log**:
  - `2026-03-13 23:27 +0800` 完成 presentation 家族搬迁：`canvas_specs -> input/canvas_routes`、`canvas_registry -> input/canvas_route_registry`、`view -> runtime/ui_runtime`、`choice_screen_service -> controllers/choice_screens`，并同步修正搬迁家族内部 require。
  - `2026-03-13 23:27 +0800` 验证 `src/presentation` 中旧路径残留只在待后续任务处理的外部调用点，搬迁家族内部旧引用为零；`lua -e 'require(...)'` 最小加载冒烟通过。
- **files edited/created**: `.agents/plan.md`, `src/presentation/input/canvas_route_registry.lua`, `src/presentation/input/canvas_routes/*.lua`, `src/presentation/runtime/ui_runtime/*.lua`, `src/presentation/runtime/controllers/choice_screens/*.lua`

### T2: `presentation` 非测试调用点改写
- **depends_on**: [T1]
- **location**: `src/presentation/runtime/**`；`src/presentation/input/**`；`src/app/bootstrap/ui_bootstrap.lua`
- **description**: 改写 `presentation` 侧剩余生产代码调用点到新路径；`src/app/bootstrap/game_startup.lua` 先不动，留给集成任务统一处理，避免和 turn 重构冲突。
- **validation**: `src/presentation/**` 与 `src/app/bootstrap/ui_bootstrap.lua` 不再出现旧 presentation 路径；`src/presentation/input/canvas_routes/**` 不新增对 `src.presentation.runtime.*` 的依赖。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T3: `turn` 源文件搬迁与内部归位
- **depends_on**: [T0]
- **location**: `src/game/flow/turn/**`（排除 `src/game/flow/turn/loop.lua`）
- **description**: 完成 `dispatch/`、`phases/`、`runtime/`、`waits/`、`auto/`、`policies/` 重组，以及 `session_script.lua`、`scheduler_runtime.lua` 等改名；只修正 turn 家族内部引用，`loop.lua` 留给集成任务统一收口。
- **validation**: 新目录结构与命名全部落位；除 `loop.lua` 外，turn 家族内部不再引用旧 turn 路径。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T4: `market` 源文件搬迁与内部归位
- **depends_on**: [T0]
- **location**: `src/game/systems/market/**`
- **description**: 用 `query/`、`choice/`、`purchase/` 替换 `application/`，并把 `application/auto.lua` 提升为 `src/game/systems/market/auto.lua`；同步修正 `market` 目录内部引用，保留 `src/game/systems/market/init.lua` 的 façade 形状不变。
- **validation**: `src/game/systems/market/application/**` 被完全替换；`src/game/systems/market/init.lua` 仍导出 `query/choice/purchase/auto`；`market` 目录内部无旧路径残留。
- **status**: Completed
- **log**:
  - `2026-03-13 23:27 +0800` 完成 `application/**` 到 `query/`、`choice/`、`purchase/` 的物理搬迁，并将 `application/auto.lua` 上提到 `src/game/systems/market/auto.lua`。
  - `2026-03-13 23:27 +0800` 同步修正 `market` 子树内全部 require 路径，`init.lua` 继续导出 `query/choice/purchase/auto` 四个 façade 入口。
  - `2026-03-13 23:27 +0800` 验证 `rg -n \"src\\.game\\.systems\\.market\\.application(\\.|$)\" src/game/systems/market` 结果为零，并执行最小 require 冒烟通过。
- **files edited/created**: `.agents/plan.md`, `src/game/systems/market/auto.lua`, `src/game/systems/market/init.lua`, `src/game/systems/market/choice_handlers.lua`, `src/game/systems/market/query/context.lua`, `src/game/systems/market/query/eligibility.lua`, `src/game/systems/market/choice/builder.lua`, `src/game/systems/market/choice/feedback.lua`, `src/game/systems/market/choice/outcome.lua`, `src/game/systems/market/choice/session.lua`, `src/game/systems/market/purchase/core.lua`, `src/game/systems/market/purchase/fulfillment.lua`, `src/game/systems/market/purchase/local_purchase.lua`, `src/game/systems/market/purchase/paid_fulfillment.lua`, `src/game/systems/market/purchase/paid_purchase_callback.lua`, `src/game/systems/market/purchase/policy.lua`

### T5: 跨子系统生产代码集成改写
- **depends_on**: [T2, T3, T4]
- **location**: `src/game/flow/turn/loop.lua`；`src/app/**`；`src/game/core/runtime/composition_root.lua`；其余仍指向旧路径的 `src/game/**`
- **description**: 统一处理跨主线桥接文件：`loop.lua` 同时切 turn 内部新路径和 market 新路径；`game_startup.lua` 同时切 `ui_runtime` 与 `auto.runner`；`composition_root.lua` 切 `scheduler_runtime` 与 `phases.registry`；支付网关切 market query 路径。此任务之后，`src/**` 应完全脱离旧路径。
- **validation**: `rg` 扫描 `src/**` 对三大家族旧路径应为零；关键生产模块可被加载；不新增任何跨层依赖。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T6: 测试、reload helper、stub 字符串改写
- **depends_on**: [T5]
- **location**: `tests/**`
- **description**: 按 T0 的映射表一次性替换测试中的 `require(...)`、`package.loaded[...]`、`_reload_module(...)`、`_load_fresh(...)`、stub key 与帮助函数字符串，避免边改边猜。
- **validation**: `tests/**` 不再出现旧路径；以下代表性 suite 通过：`suites.presentation.presentation_ui_event_bindings`、`suites.presentation.presentation_ui_interaction`、`suites.presentation.gameplay_t5_characterization`、`suites.gameplay.gameplay_turn_flow_and_interrupts`、`suites.gameplay.gameplay_t2_characterization`、`suites.domain.market`、`suites.domain.paid_currency`、`suites.gameplay.gameplay_t4_characterization`。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T7: 文档与目录清理
- **depends_on**: [T6]
- **location**: `docs/architecture/boundaries.md`；`docs/architecture/subsystems.md`；被清空的旧目录
- **description**: 更新文档中的路径示例与目录语义；删除旧空目录；明确不修改 `scripts/arch/config.lua`。
- **validation**: 文档只引用新路径；旧目录树不再残留 `canvas_specs/`、`view/`、`choice_screen_service/`、`market/application/` 等已退休目录。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T8: 全量护栏与残留验收
- **depends_on**: [T7]
- **location**: repo root
- **description**: 跑完整护栏、全量回归、CRAP 报告与旧路径残留扫描；验收通过后，这次重构结束。
- **validation**:
  - `lua scripts/arch.lua check`
  - `lua tests/guard.lua`
  - `lua tests/regression.lua`
  - `lua scripts/crap.lua report --lane behavior --lane contract --top 30`
  - 用 T0 的同一组 `rg` 模式复扫 `src tests docs`
  - 解析 `tmp/crap_report.json`，确认不存在 `crap >= 10` 的函数
- **status**: Not Completed
- **log**:
- **files edited/created**:

## Parallel Execution Groups

| Wave | Tasks | Can Start When |
|------|-------|----------------|
| 1 | T0 | Immediately |
| 2 | T1, T3, T4 | T0 complete |
| 3 | T2 | T1 complete |
| 4 | T5 | T2, T3, T4 complete |
| 5 | T6 | T5 complete |
| 6 | T7 | T6 complete |
| 7 | T8 | T7 complete |

## Testing Strategy

- `T2` 后跑 presentation 冒烟，重点覆盖 `canvas_route_registry`、`ui_runtime`、`choice_screens`、item slots、event bindings。
- `T5` 后跑生产代码冒烟，重点覆盖 turn runtime、`loop.lua`、`composition_root.lua`、market purchase/payment gateway。
- `T6` 后跑代表性 suite，再进入全量：
  - presentation: `presentation_ui_event_bindings`、`presentation_ui_interaction`、`gameplay_t5_characterization`
  - turn/gameplay: `gameplay_turn_flow_and_interrupts`、`gameplay_t2_characterization`
  - market: `domain.market`、`domain.paid_currency`、`gameplay_t4_characterization`
- 最终验收以 `T8` 为准：所有测试通过、`arch_view check ok`、旧路径残留为零、无 `crap >= 10`、且 `src/presentation/input/canvas_routes/**` 不依赖 `src.presentation.runtime.*`。

## Assumptions

- 这是一次切换；不保留兼容模块，不做双路径迁移。
- 只允许“路径改名 + 文件归位 + 调用点更新”；不顺手改业务逻辑、不改导出 API 形状。
- 顶层组件边界不变，不新增跨层依赖；若出现边界冲突，优先把纯计算移回 `src/presentation/input/*` 或 `src/presentation/model/*`，不把 runtime 依赖带入 `canvas_routes`。
- `scripts/arch/config.lua` 保持不变；若护栏失败，修代码以适配现有规则，不改规则。
- 旧工作树中的无关修改保持原样，不在本计划里处理。
