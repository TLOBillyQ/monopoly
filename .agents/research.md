# Monopoly 项目重写研究：Canvas-First UI + 协程化逻辑层

更新时间：2026-02-28（第二轮深度审计）
范围：`src/presentation/**`、`src/game/**`、`src/app/bootstrap/**`、`tests/**`

---

## 1. 结论摘要

1. 协程运行时骨架（`src/game/runtime_coroutine/`）已落地，7 个模块均为可运行实现，非空壳。`TurnEngine` 通过 `experimental_coroutine_turn` 开关在新旧路径间切换，当前默认 `false`（走旧 `TurnFlow`）。
2. Canvas 运行时层（`src/presentation/canvas_runtime/`）已完成结构迁移：`CanvasRegistry` 已不再依赖 `interaction/intent_builders/*`，改为引用 `canvas/*/intents.lua`。`CanvasStore`、`CanvasRenderPipeline` 均已实现。
3. 但"骨架落地"不等于"切流完成"。系统仍处于"混合态"——旧 `TurnFlow` 仍是实际主路径，`Await` 模块被旧路径以"函数调用+轮询"方式使用而非协程 `yield`，`resume_state/resume_args` 仍在 8 个生产文件中传播，`shared/UINodes` 仍被 14 个生产文件引用。
4. 协程路径测试覆盖极低：仅 2 个测试，只覆盖 `wait_choice` 的基本解决，未覆盖动画等待、detained、seconds、多阶段串联、错误恢复。
5. 下一步的核心问题是：**在默认开启协程路径之前，必须先补足测试覆盖，消除混合态中的隐式耦合，才能安全切流。**

---

## 2. 第一轮研究回顾

第一轮研究（2026-02-28 早间）建立了完整的目标架构设计和分阶段路线，详见本节以下子节。这些分析在第二轮审计后仍然有效，但需要根据实际落地情况做修正。

## 2.1 代码规模与模块分布

1. `src/presentation`：约 68 个 Lua 文件，分布在 `canvas/`（13 个子模块）、`canvas_runtime/`（7 个文件）、`interaction/`（15 个文件）、`render/`（15 个文件）、`api/`（16 个文件）、`ui/`（8 个文件）、`shared/`（5 个文件）、`state/`（3 个文件）。
2. `src/game`：约 96 个 Lua 文件，分布在 `core/runtime/`（23 个文件）、`flow/turn/`（22 个文件）、`systems/`（48 个文件）、`runtime_coroutine/`（7 个文件）。
3. `src/core`：7 个工具文件。
4. 回归测试主入口：`tests/regression.lua`，当前聚合 20 个 suite，30 个测试文件。

## 2.2 启动与运行拓扑

关键链路：

1. `main.lua` -> `src/app/init.lua`
2. `GameStartup` 构建运行态 state
3. `UIBootstrap` 在 `GAME_INIT` 绑定 UI 节点并启动 runtime
4. `GameRuntimeBootstrap` 用 `SetFrameOut` 驱动 `GameplayLoop.tick(...)`

`state` 仍是全局大状态对象，同时被 UI、输入、动画、倒计时、回合流使用。

## 2.3 UI 层：Canvas-First 结构已落地，运行时收敛未完成

已完成部分：

1. `CanvasRegistry` 已改为从 `canvas/*/intents.lua` 构建路由，不再引用 `interaction/intent_builders/*`。
2. `CanvasStore` 已实现 `ensure/get_slice/patch_slice/mark_dirty/consume_dirty` 接口。
3. `CanvasRenderPipeline` 已协调 dirty 状态、base_presenter、BoardRuntime、UITurnEffects。
4. `CanvasEventRouter` 已作为事件分发层。
5. 13 个 canvas 子模块各有 `nodes.lua`、`contract.lua`，7 个有 `intents.lua`。

未完成/风险点：

1. `shared/UINodes.lua` 仍被 14 个生产文件引用（UIViewService、UIBootstrap、UITouchPolicy、UIInputLockPolicy、UIEventBindings、UICanvasCoordinator、UIPanelPresenter、UITurnEffects、ActionAnim、intent_builders/ChoiceIntents、intent_builders/BasicIntents、ui_view_service/state、ui_view_service/core、ui_view_service/assets）。
2. `interaction/intent_builders/` 目录仍存在且被 1 个测试文件引用（`presentation_ui.lua:2414`）。虽然 CanvasRegistry 已不使用，但目录未删除。
3. modal/choice/popup 状态仍分散在 `state.ui`、`state.pending_choice_*`、`game.turn.pending_choice`。
4. dep_rules 仅有 2 条规则：interaction 不引 game、canvas 不引 UINodes。缺少"canvas_runtime 不引 intent_builders"等进一步约束。

## 2.4 逻辑层：混合态——Await 已被旧路径调用但非协程驱动

当前实际执行路径（默认模式，`experimental_coroutine_turn = false`）：

1. `Game.advance_turn()` -> `_resolve_turn_runtime()` -> `TurnEngine` -> legacy `TurnFlow`。
2. `TurnFlow.run_until_wait()` 循环调用 `Flow.step()`，遇到 wait 状态停下。
3. `TurnWaits.lua` 和 `TurnChoiceHandler.lua` 已改为调用 `Await.choice/move_anim/action_anim`，但方式是同步函数调用 + 返回 `{wait=true}` 或 `{next_state, next_args}`，**不使用 `coroutine.yield`**。
4. `resume_state/resume_args` 仍由 phase 文件（TurnStart、TurnRoll、TurnMove、TurnLand）产生，经 Await 提取后传回 Flow。

协程路径（`experimental_coroutine_turn = true`）：

1. `TurnEngine` 创建 `Session` + `Scheduler`。
2. `Scheduler.step()` 调用 `coroutine.resume()`，`TurnScript` 内部 `coroutine.yield()` 实现真正挂起。
3. 但此路径仅有 2 个测试覆盖，未经生产验证。

关键发现：**Await 模块是"双模"设计。在旧路径中被当作轮询函数使用（每帧调用，返回 wait 或 next），在新路径中被 TurnScript 在协程内调用（yield 由 TurnScript 包裹）。这个设计是有意的——允许渐进切流。**

---

## 3. 第二轮审计：差距分析

## 3.1 协程路径测试覆盖缺口

当前仅有 `tests/suites/gameplay_coroutine.lua` 的 2 个测试：

1. `turn_engine_defaults_to_legacy_mode`：验证默认走旧路径。
2. `turn_engine_coroutine_mode_resolves_wait_choice`：验证协程路径下 wait_choice 能被 choice_cancel 解决。

未覆盖的关键场景：

1. `wait_move_anim` 在协程路径下的解决（seq 校验）。
2. `wait_action_anim` 在协程路径下的解决（action_anim_queue 消费）。
3. `detained_wait` 在协程路径下的行为。
4. `await.seconds` 时间等待。
5. 多阶段完整回合串联（start -> roll -> move -> land -> end_turn）。
6. 协程错误传播与恢复。
7. CompatBridge 同步正确性。
8. 新旧路径行为一致性对比测试。

## 3.2 旧路径遗留依赖

| 依赖类型 | 生产文件数 | 测试文件数 | 总引用点 | 清理优先级 |
|---|---|---|---|---|
| `shared/UINodes` 引用 | 14 | 2 | ~16 | 高 |
| `intent_builders` 引用 | 目录内互引 | 1 | ~2 | 中（目录可删） |
| `resume_state/resume_args` | 8 | 3 | ~60 | 高（切流后消除） |
| `game.turn_flow` 字段替换（测试） | N/A | 3 | ~11 | 高（阻塞严格切流） |
| `wait_*` 字符串字面量 | 15 | 7 | ~70 | 中（实现细节） |
| `src/core/Flow.lua` 导入 | 1（TurnFlow） | 0 | 1 | 低（最后删除） |

## 3.3 Game.lua 兼容逻辑分析

`Game._resolve_turn_runtime()` 有一个重要的兼容分支：如果外部替换了 `game.turn_flow`（测试常用），则优先走替换实例而非 `TurnEngine`。这意味着测试中 `g.turn_flow = turn_flow:new(g, phases)` 的写法会绕过 `TurnEngine`。要让协程路径成为默认，必须先把这些测试改为通过 `TurnEngine` 接口操作。

## 3.4 CanvasStore 实际使用深度

`CanvasStore` 已实现但需要验证：当前渲染链是否真正以 dirty-slice 驱动，还是仍有旧路径直接写 `state.ui` 绕过 store。`CanvasRenderPipeline` 内部仍调用 `base_presenter`、`BoardRuntime`、`UITurnEffects`，这些模块是否统一通过 store 消费状态，需要进一步确认。

---

## 4. 目标架构设计（不变，保留第一轮设计）

## 4.1 UI 目标架构

目标目录结构：

    src/presentation/canvas/<canvas_key>/
      nodes.lua
      contract.lua
      state.lua
      intents.lua
      presenter.lua
      touch_policy.lua

    src/presentation/canvas_runtime/
      CanvasRegistry.lua
      CanvasStore.lua
      CanvasCoordinator.lua
      CanvasEventRouter.lua
      CanvasRenderPipeline.lua
      LocalActorResolver.lua

核心设计原则不变：CanvasStore 单写、dirty-slice 增量渲染、route_key 唯一路由、节点契约生成。

## 4.2 逻辑目标架构

目标目录结构（已存在）：

    src/game/runtime_coroutine/
      Scheduler.lua
      TurnScript.lua
      Await.lua
      Signals.lua
      Session.lua
      ActionRouter.lua
      CompatBridge.lua

核心设计原则不变：单协程脚本 + await 原语、yield 语义等待、稳定事件契约。

---

## 5. 修正后的阶段路线

原计划 Phase 0-5 中，Phase 0（冻结基线）和 Phase 1（协程骨架引入）已完成。Phase 2-5 虽在计划中被标记为完成，但第二轮审计发现实际是"骨架 + 混合态"，而非"切流完成"。具体修正如下：

## Phase A（当前阶段）：协程路径测试补全 + 行为一致性验证

目标：在不改变默认路径的前提下，把协程路径的测试覆盖提升到可信赖级别。

1. 补充 `gameplay_coroutine.lua` 测试：覆盖所有 4 种等待态 + 完整回合 + 错误恢复。
2. 新增"行为一致性"测试：同一局面分别走旧路径和新路径，断言最终状态一致。
3. 在 dep_rules 中新增规则：`canvas_runtime` 不得引用 `intent_builders`。

## Phase B：默认开启协程路径

目标：将 `experimental_coroutine_turn` 默认值改为 `true`，全量走协程调度。

1. 修改 `Config/RuntimeConstants.lua` 默认值。
2. 将测试中直接替换 `game.turn_flow` 的写法迁移为通过 `TurnEngine` 接口。
3. 全回归通过后，保留旧 `TurnFlow` 作为回退但不再是默认。

## Phase C：消除 resume_state/resume_args 传播

目标：phase 文件不再产生和消费 `resume_state/resume_args`，等待恢复由协程栈帧自然处理。

1. 改造 TurnStart/TurnRoll/TurnMove/TurnLand 的 phase 函数，使其在协程内直接 await 而非返回 wait 状态。
2. 改造 ItemPhase/EffectPipeline 的 resume 逻辑。
3. Await 模块移除 `_resume()` 兼容函数。

## Phase D：UINodes 兼容层退役

目标：`shared/UINodes.lua` 不再被任何生产代码引用。

1. 逐文件迁移 14 个引用点到对应 `canvas/*/nodes.lua` 或 `canvas/*/contract.lua`。
2. 删除 `shared/UINodes.lua`。
3. 删除 `interaction/intent_builders/` 目录。
4. 更新 dep_rules 移除已无必要的规则。

## Phase E：旧 TurnFlow 退役 + 收尾

目标：`TurnFlow` 和 `src/core/Flow.lua` 不再被回合主路径引用。

1. `TurnEngine` 移除 legacy 模式分支。
2. `Game._resolve_turn_runtime()` 简化为只返回 `turn_engine`。
3. 删除 `TurnFlow.lua`、`Flow.lua`（或降级为独立工具）。
4. 完善文档与模板。

---

## 6. 风险与缓解（更新）

1. 风险：协程路径测试不足导致默认切流后回归。
   缓解：Phase A 是前置门控，不通过不切流。

2. 风险：测试中直接替换 `game.turn_flow` 的写法与 TurnEngine 冲突。
   缓解：Phase B 逐个迁移，保留 `_resolve_turn_runtime()` 兼容分支直到测试全部迁移完。

3. 风险：CanvasStore 与旧 `state.ui` 直写并存导致状态不一致。
   缓解：增加测试断言 CanvasStore 是唯一写入口；旁路写入应触发警告。

4. 风险：UINodes 引用点分散在 14 个文件，迁移量大。
   缓解：逐文件处理，每次迁移一个文件后跑回归。

---

## 7. 验收标准（最终完成定义）

1. 逻辑层：`experimental_coroutine_turn` 为默认 `true`，且不存在 `resume_state/resume_args` 在 phase 业务中传播。
2. UI 层：`shared/UINodes.lua` 不存在或零引用，`intent_builders/` 目录已删除。
3. 质量：`lua tests/regression.lua` 全绿，`gameplay_coroutine` 套件覆盖所有等待态。
4. 可回退：旧 `TurnFlow` 可通过开关恢复（Phase E 之前）。

---

## 8. 立即下一步

Phase A 是当前最高优先级：补全协程路径测试。这是所有后续切流的前提条件。具体行动见 `.agents/plan.md`。
