# `src/` 命名与层级重构计划

## Summary

当前 `arch_view` 护栏是绿的，`tmp/crap_report.json` 里也没有 `crap >= 10` 的函数；这次重构应当保持这一状态不变。核心目标不是重写逻辑，而是把已经存在的职责边界“叫对名字、放对位置”，让目录结构更像现有架构文档描述的样子。

本次按你选定的策略执行：一次切换，不保留旧路径兼容壳；重构力度按“大幅重组”处理，但只在既有顶层组件内部移动，不跨 `app/core/game/infrastructure/presentation` 根目录，不改模块导出行为。

## Implementation Changes

- `presentation` 先收口到文档语义。
  将 `src/presentation/runtime/canvas_specs/` 整体迁到 `src/presentation/input/canvas_routes/`。文件名统一去掉泛化的 `intents.lua`：`base/intents.lua -> base.lua`，`base/item_slot_intents.lua -> item_slots.lua`，其余 `player_choice/target_choice/remote_choice/market/popup/always_show/secondary_confirm/intents.lua -> <screen>.lua`。`src/presentation/runtime/canvas_registry.lua` 同步改名并迁到 `src/presentation/input/canvas_route_registry.lua`，`src/presentation/runtime/canvas_event_router.lua` 改为依赖这个新 registry。

- `presentation/runtime/view/` 改名为 `src/presentation/runtime/ui_runtime/`，保留现有导出函数名不变。
  迁移 `init.lua`、`state.lua`、`assets.lua`、`item_slots.lua`、`debug.lua`，所有原来 `require("src.presentation.runtime.view...")` 的地方一次性切到 `src.presentation.runtime.ui_runtime...`。这一步只改模块路径，不改 `build_ui_state`、`render`、`apply_input_lock`、`refresh_turn_label` 等接口名。

- `presentation/runtime/controllers/choice_screen_service/` 合并并改名为 `src/presentation/runtime/controllers/choice_screens/`。
  `common.lua -> helpers.lua`，`openers.lua` 保持文件名；`modal_controller.lua` 和相关调用点全部切到新路径。`choice_screen_service` 这个目录名不再保留。

- `game/flow/turn/` 按职责分槽，减少 33 个文件平铺。
  新建 `dispatch/`，迁入 `dispatch.lua`、`dispatch_validator.lua`、`action_gate.lua`。
  新建 `phases/`，迁入 `start.lua`、`roll.lua`、`move.lua`、`move_followup.lua`、`land.lua`，并将 `phase_registry.lua -> registry.lua`。
  新建 `runtime/`，迁入 `loop.lua`、`loop_ports.lua`、`loop_runtime.lua`、`loop_tick_flow.lua`、`loop_tick_steps.lua`、`loop_ui_sync_defaults.lua`，并统一改名为 `loop.lua`、`ports.lua`、`runtime_ports.lua`、`tick_flow.lua`、`tick_steps.lua`、`ui_sync_defaults.lua`。
  新建 `waits/`，迁入 `await.lua`、`tick_timeout.lua`、`tick_choice_timeout.lua`、`tick_ui_gate.lua`、`tick_ui_sync.lua`、`anim.lua`，并改名为 `handlers.lua`、`timeout.lua`、`choice_timeout.lua`、`ui_gate.lua`、`ui_sync.lua`、`anim.lua`。
  新建 `auto/`，迁入 `auto_runner.lua`、`auto_context.lua`、`choice_auto_policy.lua`、`item_auto_play_context.lua`，并改名为 `runner.lua`、`context.lua`、`choice_policy.lua`、`item_context.lua`。
  新建 `policies/`，迁入 `timer_policy.lua`、`camera_policy.lua`、`role_control_policy.lua`，并改名为 `timer.lua`、`camera.lua`、`role_control.lua`。
  根目录只保留 `decision.lua`、`logger.lua`、`item_slot_data.lua`，并把 `script.lua -> session_script.lua`、`engine.lua -> scheduler_runtime.lua`。

- `game/systems/market/application/` 退役，换成按业务意图命名的子目录。
  新建 `query/`，迁入 `context.lua -> catalog.lua`、`eligibility.lua -> eligibility.lua`。
  新建 `choice/`，迁入 `choice.lua -> build.lua`、`choice_session.lua -> session.lua`、`choice_outcome.lua -> outcome.lua`。
  新建 `purchase/`，迁入 `purchase.lua -> execute.lua`、`purchase_policy.lua -> policy.lua`、`local_purchase.lua -> local.lua`、`fulfillment.lua -> fulfillment.lua`、`paid_purchase_callback.lua -> paid_callback.lua`、`paid_fulfillment.lua -> paid_fulfillment.lua`、`feedback.lua -> feedback.lua`。
  `application/auto.lua` 提升为 `src/game/systems/market/auto.lua`。`src/game/systems/market/init.lua` 保留为 façade，只改内部 require 路径，不改导出的 `market_service.query/choice/purchase/auto` 形状。

- 所有 `src/` 与 `tests/` 内对旧模块路径的 `require(...)`、`package.loaded[...]`、stub key、reload helper 字符串一次性全量替换；删除所有空目录；同步更新 `docs/architecture/boundaries.md` 与 `docs/architecture/subsystems.md` 中受影响的路径示例。`scripts/arch/config.lua` 不改。

## Public Module Path Changes

- 不保留旧路径兼容模块，旧路径全部删除。
- 对外可见的路径变更按家族统一切换：
  `src.presentation.runtime.canvas_*` 的输入路由模块改为 `src.presentation.input.canvas_*`。
  `src.presentation.runtime.view*` 改为 `src.presentation.runtime.ui_runtime*`。
  `src.game.flow.turn.loop*` 家族改为 `src.game.flow.turn.runtime.*`。
  `src.game.flow.turn.phase_registry` 改为 `src.game.flow.turn.phases.registry`。
  `src.game.flow.turn.move_followup` 改为 `src.game.flow.turn.phases.move_followup`。
  `src.game.flow.turn.dispatch*` 家族改为 `src.game.flow.turn.dispatch.*`。
  `src.game.systems.market.application.*` 全部改为 `src.game.systems.market.query.*`、`choice.*`、`purchase.*` 或 `auto`。

- 模块导出的 table 结构与函数名保持原样；本次只允许“路径改名 + 文件归位”，不引入行为变更。

## Test Plan

- 每完成一个子系统批次，都先跑对应高风险回归：
  `presentation` 批次后跑 presentation 相关 suite。
  `market` 批次后跑 market / paid_currency / gameplay characterization 相关 suite。
  `turn` 批次后跑 gameplay / runtime / architecture 相关 suite。
- 全量完成后，在仓库根目录执行：
  `lua scripts/arch.lua check`
  `lua tests/guard.lua`
  `lua tests/regression.lua`
  `lua scripts/crap.lua report --lane behavior --lane contract --top 30`
- 用 PowerShell 复核 CRAP 门槛：
  `$json = Get-Content tmp/crap_report.json -Raw | ConvertFrom-Json; $json.functions | Where-Object { $_.crap -ge 10 }`
  预期无输出。
- 验收标准是：
  所有测试通过；`arch_view check ok`；没有旧路径残留；没有 `crap >= 10` 的函数；`presentation/input` 新增的路由模块仍不依赖 `src.presentation.runtime.*`。

## Assumptions And Defaults

- 顶层组件边界不变；不新增跨层依赖；不为这次重构修改 `scripts/arch/config.lua`。
- `presentation/input/canvas_routes/` 允许依赖 `src.core.state_access.*`、`src.presentation.input.*`、`src.presentation.schema.*`，但禁止依赖 `src.presentation.runtime.*`；若出现 runtime 耦合，优先把纯计算搬到 `src.presentation.input.event_intents` 或 `src.presentation.model.choice_support`，不要把 runtime 依赖带进 input。
- 现有工作树里的无关改动保持原样，不碰 `Agents.md`、`scripts/lib/common.lua`、`test_mkdir.lua`、`test_path.lua`。
- 这次不顺手处理 `land/items/effects` 等已对齐但仍可继续优化的区域，避免把“结构整理”扩成逻辑重写。
