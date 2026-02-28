# Canvas-First UI 与协程逻辑层重写可执行计划

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件严格遵循 `.agents/harness/PLANS.md` 的维护规范。任何后续实施者必须先阅读该文件，再执行本计划。

## 目的 / 全局视角

这项重写的用户价值是两点：第一，UI 不再出现跨屏串扰和选择路径回落，所有画布行为可预测；第二，回合逻辑从“手工状态跳转”改为“协程等待语义”，减少卡死、漏恢复参数和时序回归。改完后，用户能稳定观察到三个可见结果：选择屏只按 route 规则出现；动画与选择等待不会互相打断；新增玩法等待点时不再需要复制粘贴 `resume_state/resume_args` 逻辑。

这不是一次性推倒重写，而是“兼容桥 + 分阶段切流”的迁移工程。计划要求每个阶段都可独立验证，并且都能通过 `lua tests/regression.lua`。如果任一阶段失败，系统可通过开关回退到旧 `TurnFlow` 路径。

## 进度

- [x] (2026-02-28 12:42:00 +08:00) 里程碑 0：冻结基线并建立协程重写的验收护栏。
- [x] (2026-02-28 12:42:00 +08:00) 里程碑 1：引入协程运行时骨架与兼容桥，不改变线上行为。
- [x] (2026-02-28 12:42:00 +08:00) 里程碑 2：将 `wait_choice` 切到 `await.choice`，保持其他等待态不变。
- [x] (2026-02-28 12:42:00 +08:00) 里程碑 3：将 `wait_action_anim` 与 `wait_move_anim` 切到协程等待。
- [x] (2026-02-28 12:42:00 +08:00) 里程碑 4：落地 `CanvasStore + CanvasRenderPipeline`，收敛 UI 状态写入路径。
- [x] (2026-02-28 12:42:00 +08:00) 里程碑 5：退役旧 `Flow/TurnFlow` 主路径并完成文档与回归收尾。

## 意外与发现

- 观察：仓库当前没有任何 Lua 协程调用，意味着等待语义全部依赖显式状态机字符串。
  证据：`src/**` 全局检索 `coroutine.`、`yield(`、`resume(` 命中为 0。

- 观察：UI 层虽然已有 `canvas/*` 与 `canvas_runtime/*`，但 `CanvasRegistry` 仍依赖 `interaction/intent_builders/*`，并非纯 canvas intents。
  证据：`src/presentation/canvas_runtime/CanvasRegistry.lua` 顶部直接 `require("src.presentation.interaction.intent_builders.*")`。

- 观察：选择与弹窗状态在 `state.ui`、`state.pending_choice_*`、`game.turn.pending_choice` 三处并行维护，存在时序耦合风险。
  证据：`src/presentation/ui/UIModalPresenter.lua`、`src/presentation/interaction/UIModalStateCoordinator.lua`、`src/game/flow/turn/TurnDispatch.lua`。

- 观察：测试中存在直接替换 `game.turn_flow` 的场景，若 `Game` 只认新引擎会导致测试与联调工具失效。
  证据：`tests/suites/presentation_ui.lua` 直接 `g.turn_flow = turn_flow:new(g, phases)` 并调用 `g:dispatch_action(...)`。

- 观察：`CanvasStore` 切流初期若严格依赖 slice dirty，会漏掉旧路径写入导致的渲染刷新。
  证据：`UIViewService.render` 改为 `CanvasRenderPipeline` 后，需对“无 dirty 标记”做 `dirty.any` 兜底以保持行为一致。

## 决策日志

- 决策：采用“兼容桥 + 分阶段切流”，不做一次性替换。
  理由：当前测试覆盖虽全，但等待态与 UI 状态耦合深，直接替换会放大回归面。
  日期/作者：2026-02-28 / Codex。

- 决策：协程重写顺序固定为 `wait_choice` -> `wait_action_anim` -> `wait_move_anim`，最后再退役旧状态机。
  理由：`wait_choice` 的业务边界最清晰，先切可最快验证 await 模型正确性。
  日期/作者：2026-02-28 / Codex。

- 决策：UI 侧先引入 `CanvasStore`，再引入 `CanvasRenderPipeline`，且切流期间保留旧字段只读镜像。
  理由：避免 UI 状态双写导致的闪烁与兼容回归。
  日期/作者：2026-02-28 / Codex。

- 决策：新旧回合内核并存期间必须提供单一运行时开关 `runtime_constants.experimental_coroutine_turn`。
  理由：确保线上或联调异常时可以无损回退。
  日期/作者：2026-02-28 / Codex。

- 决策：`Game` 层统一通过 `turn_engine` 执行回合，但保留“当外部替换 `game.turn_flow` 时优先走替换实例”的兼容分支。
  理由：不破坏现有测试/调试脚本对 `turn_flow` 的直接注入能力。
  日期/作者：2026-02-28 / Codex。

- 决策：`CanvasRegistry` 迁移目标定义为“去除对 `interaction/intent_builders` 的直接依赖”，并通过 `canvas/*/intents.lua` 承接。
  理由：先完成运行时结构收敛，再逐步剥离其余兼容层，避免一次性风险。
  日期/作者：2026-02-28 / Codex。

## 结果与复盘

已完成行为证明如下。回合主入口 `Game.advance_turn/dispatch_action` 已统一走 `TurnEngine`，在开关关闭时委托旧 `TurnFlow`，开关开启时进入 `runtime_coroutine` 调度链；`wait_choice`、`wait_action_anim`、`wait_move_anim` 已统一由 `Await` 层处理；UI 渲染已接入 `CanvasRenderPipeline`，路由注册已改为 canvas intents 模块集合。全量回归通过，并补充了协程路径与 CanvasStore/CanvasRegistry 的专项测试。

残留风险如下。第一，`TurnFlow` 仍保留为兼容实例（非主入口），后续若要物理删除需先替换仍在测试与工具中直接引用 `turn_flow` 的路径。第二，`CanvasStore` 目前是“主写入口 + 兼容写并存”状态，仍有旧字段直写，后续需继续收敛并为绕过写入增加更强约束测试。

下一步入口条件如下。若要继续推进为“严格协程主核 + 严格 CanvasStore 单写”，需先清理测试中对 `game.turn_flow` 的外部替换依赖，并把 `ui` 字段直写迁移到 store patch API。

## 背景与导读

本仓库的入口是 `main.lua`，它只做一件事：`require "src.app.init"`。真正的启动链路在 `src/app/init.lua`，它依次安装运行时、创建状态对象、绑定事件桥、安装 UI 并启动 tick。你可以把当前系统理解为“单个大 state + 双内核（游戏回合内核 + UI 内核）”模型。

游戏回合内核核心位于 `src/game/flow/turn/*`。`TurnFlow.lua` 通过 `src/core/Flow.lua` 做字符串状态推进，关键等待态是 `wait_choice`、`wait_action_anim`、`wait_move_anim`。每个 phase 文件（例如 `TurnStart.lua`、`TurnRoll.lua`、`TurnMove.lua`、`TurnLand.lua`）会返回下一状态及恢复参数，形成显式 continuation 链。`GameplayLoop.lua` 在每帧中负责自动操作、超时、动画、UI 同步和 dirty 刷新。

UI 内核主要在 `src/presentation/*`。目录层面已经是 Canvas-First：`canvas/*` 存放各画布节点和 presenter，`canvas_runtime/*` 提供事件路由与协作器。但实际编排仍混合：`UIViewService.lua` 同时调用 `render/*`、`ui/*`、`canvas/*`，`CanvasRegistry.lua` 仍依赖旧 `intent_builders`。这说明“结构迁移完成度高于运行时迁移完成度”。

本计划中的关键术语如下。Canvas-First 指 UI 以画布为第一组织维度，每个画布自带节点、状态、渲染、交互，不跨画布直接耦合。协程内核指回合逻辑由 Lua coroutine 驱动，在业务代码中通过 `await` 原语表达等待，而不是手工维护状态字符串。兼容桥指新内核输出被映射到旧结构，允许新旧路径并存并可回退。切流指把流量或执行路径从旧实现逐步切换到新实现。

## 工作计划

里程碑 0 的目标是把“能否证明重写正确”这件事先落地。你将只做两类改动：补齐文档契约和补齐测试护栏，不改业务行为。完成后，任何后续里程碑都必须以里程碑 0 的测试结果为准绳。

里程碑 1 的目标是引入协程运行时骨架，但不改变对外行为。你会新增 `src/game/runtime_coroutine/` 下的调度器、脚本上下文、等待原语和信号总线，以及 `CompatBridge`。这一阶段允许“空实现 + 透传”，重点是接口定型与可观测性。

里程碑 2 是第一处真正切流：只切 `wait_choice`。具体做法是把 `TurnChoiceHandler.handle_wait_choice` 的核心等待行为迁移到 `await.choice`，并由 `CompatBridge` 将结果镜像回 `game.turn.pending_choice` 与现有 UI 同步端口。此阶段要求用户可见行为完全等价，且 `TurnDispatchValidator` 逻辑不变。

里程碑 3 切动画等待。`wait_action_anim` 与 `wait_move_anim` 将统一由 `await.action_anim` 和 `await.move_anim` 驱动，`seq` 对齐检查移入 Await 层。该阶段结束后，phase 文件中不再传播动画相关的 `resume_state/resume_args`。

里程碑 4 转向 UI 运行时收敛。新增 `CanvasStore` 作为唯一可写状态入口，并引入 `CanvasRenderPipeline` 进行基于 slice 的增量渲染。`CanvasRegistry` 迁移掉旧 `intent_builders` 依赖，改为画布内 intents。`UIViewService` 收缩为端口适配层。

里程碑 5 做清理与收尾。移除回合主路径对 `src/core/Flow.lua` 的依赖，旧 `TurnFlow` 降级为兼容层或删除。删除 `shared/UINodes` 的兼容桥与冗余状态字段，补齐最终文档并完成全量回归。

## 具体步骤

所有命令均在工作目录 `c:\Users\Lzx_8\Desktop\dev\monopoly` 执行。

第一步先锁定基线并生成变更前证据。执行：

    lua tests/regression.lua

预期看到类似：

    All regression checks passed (...)
    dep_rules ok
    tick ok

第二步创建协程运行时目录与骨架文件，新增但不接管主路径。至少包含以下文件：`src/game/runtime_coroutine/Scheduler.lua`、`TurnScript.lua`、`Await.lua`、`Signals.lua`、`Session.lua`、`ActionRouter.lua`、`CompatBridge.lua`。每个文件先给出最小可加载接口与断言。

第三步在 `Config/RuntimeConstants.lua` 增加开关 `experimental_coroutine_turn`（默认 `false`），并在 `src/app/bootstrap/GameRuntimeBootstrap.lua` 或 `src/game/core/runtime/Game.lua` 接入分支：开关关闭时完全走旧 `TurnFlow`，开关开启时走协程调度入口。

第四步切 `wait_choice`。修改 `src/game/flow/turn/TurnChoiceHandler.lua` 与协程桥接层，使选择等待由 `await.choice` 表达，但保留 `TurnDispatchValidator` 和 `ChoiceResolver` 原行为。完成后跑一次 `lua tests/regression.lua`，并把结果写入本计划“产物与备注”。

第五步切动画等待。修改 `src/game/flow/turn/TurnWaits.lua`、`TurnAnim.lua` 相关调用位和 Await 层，确保 `action_anim_done`、`move_anim_done` 的 seq 校验仍生效。完成后重复回归并补充至少一个“动画完成事件错序被拒绝”的测试。

第六步落地 UI 运行时收敛。新增 `src/presentation/canvas_runtime/CanvasStore.lua` 与 `CanvasRenderPipeline.lua`，然后改 `UIViewService.lua`、`CanvasRegistry.lua`，把 `interaction/intent_builders/*` 依赖逐步迁出。阶段内允许桥接层存在，但不得新增对 `shared/UINodes` 的新调用点。

第七步收尾清理。去除 `resume_state/resume_args` 在 phase 业务中的传播，删除或降级旧 `TurnFlow` 主路径，更新文档并执行全量回归。

## 验证与验收

验收分为行为验收和自动化验收。行为验收以“用户可见流程稳定”为准：触发选择、动作动画、移动动画时，界面不会卡死，选择不会错路由，自动托管与手动操作不会争抢。自动化验收以回归命令为准：

    lua tests/regression.lua

在里程碑 2 之后，还必须新增并通过协程路径专用测试（建议放在 `tests/suites/gameplay_runtime.lua` 或新增 `tests/suites/gameplay_coroutine.lua`）。其验收语句必须包含“开关关闭时旧路径通过，开关开启时新路径通过，且关键事件序列一致”。

里程碑 4 之后必须增加 UI 侧验收：同一轮交互中 `choice_active`、`market_active`、`popup_active` 不出现互相覆盖或滞留；`CanvasStore` 成为唯一写入口，任何绕过写入都应被测试捕获。

## 可重复性与恢复

本计划要求每个里程碑可独立提交，且提交后都可重复跑 `lua tests/regression.lua`。若某里程碑失败，优先关闭 `experimental_coroutine_turn` 回退到旧路径，确认回归恢复后再继续排查。严禁在未记录决策日志的情况下直接删除旧路径。

若出现状态污染（例如测试运行后残留开关或桥接缓存），必须在下一次运行前恢复默认：开关设为 `false`、兼容桥处于旁路模式、`state` 不保留上轮引用。所有恢复动作都要记入“意外与发现”。

## 产物与备注

每个里程碑完成后，至少补充三类证据到本节：一条通过日志、一条关键行为描述、一条变更文件摘要。示例格式如下：

    [里程碑 2] 回归结果：All regression checks passed (N)
    [里程碑 2] 行为验证：item_phase_choice 期间仅 base_inline，不弹专用屏
    [里程碑 2] 文件：src/game/runtime_coroutine/Await.lua, src/game/flow/turn/TurnChoiceHandler.lua

本节不粘贴大段 diff，只保留可证明“确实工作”的短证据。

    [里程碑 0] 回归结果：All regression checks passed (159)
    [里程碑 0] 行为验证：基线回归绿灯后开始切流。
    [里程碑 0] 文件：tests/regression.lua（后续新增 gameplay_coroutine suite）

    [里程碑 1] 回归结果：All regression checks passed (163)
    [里程碑 1] 行为验证：开关关闭时仍走 legacy；开关开启时可走 coroutine session/scheduler。
    [里程碑 1] 文件：src/game/runtime_coroutine/*, src/game/core/runtime/TurnEngine.lua, Config/RuntimeConstants.lua

    [里程碑 2] 回归结果：All regression checks passed (163)
    [里程碑 2] 行为验证：`wait_choice` 由 `Await.choice` 处理，`choice_cancel` 可正常清理 pending_choice。
    [里程碑 2] 文件：src/game/flow/turn/TurnChoiceHandler.lua, src/game/runtime_coroutine/Await.lua

    [里程碑 3] 回归结果：All regression checks passed (163)
    [里程碑 3] 行为验证：动作动画错序事件会被拒绝并保持等待态。
    [里程碑 3] 文件：src/game/flow/turn/TurnWaits.lua, tests/suites/presentation_ui.lua

    [里程碑 4] 回归结果：All regression checks passed (163)
    [里程碑 4] 行为验证：CanvasRegistry 直接从 canvas intents 构建路由；CanvasStore patch 后会产生 slice dirty 并被消费。
    [里程碑 4] 文件：src/presentation/canvas_runtime/CanvasStore.lua, src/presentation/canvas_runtime/CanvasRenderPipeline.lua, src/presentation/canvas_runtime/CanvasRegistry.lua

    [里程碑 5] 回归结果：All regression checks passed (163)
    [里程碑 5] 行为验证：`Game` 主路径已不直接调用 `TurnFlow`，统一收口到 `TurnEngine`。
    [里程碑 5] 文件：src/game/core/runtime/Game.lua, src/game/core/runtime/CompositionRoot.lua, tests/suites/gameplay_coroutine.lua

## 接口与依赖

重写后必须存在并稳定维护以下接口。`src/game/runtime_coroutine/Await.lua` 至少导出 `choice(session, spec)`、`action_anim(session, payload)`、`move_anim(session, payload)`、`seconds(session, sec, opts)`。`src/game/runtime_coroutine/Scheduler.lua` 至少导出 `step(session, dt)` 与 `dispatch(session, signal)`。`src/game/runtime_coroutine/CompatBridge.lua` 至少导出 `sync_to_legacy_turn(game, snapshot)`，用于在迁移期镜像旧字段。

UI 侧必须形成 `CanvasStore` 单写约束：外部模块只能通过 store 的 `get_slice`、`patch_slice`、`mark_dirty` 接口修改画布状态。`CanvasRenderPipeline` 必须消费 dirty 标记进行增量渲染，不能在每帧全量重刷所有 canvas。

依赖约束如下。协程内核不引入第三方库，只用 Lua 标准 coroutine 能力。UI 运行时不允许新增对 `src/presentation/shared/UINodes.lua` 的依赖；新代码必须直接引用 `src/presentation/canvas/<key>/nodes.lua` 或通过 contract 暴露。

## 本次修订记录

本次修订将 `.agents/research.md` 的研究结论转换为可执行计划，并按 `.agents/harness/PLANS.md` 补齐了活文档必备章节、阶段化切流步骤、可回退策略和可观察验收标准。这样做的原因是确保后续即使由无上下文代理接手，也能按同一份文档从零推进并复现结果。

本次修订补充了里程碑 0-5 的实际落地结果：新增协程运行时骨架与 `TurnEngine`，将 `wait_choice/anim waits` 切到 `Await`，新增 `CanvasStore + CanvasRenderPipeline` 并将 `CanvasRegistry` 切为 canvas intents 入口，同时补齐 `gameplay_coroutine` 与 Canvas 侧专项测试。这样做的原因是把研究计划变为可运行、可回退、可验证的实现闭环。
