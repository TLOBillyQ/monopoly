# Monopoly Lua 项目架构

## 概览

项目入口是 `main.lua`，仅负责加载 `src/app/init.lua`。初始化阶段完成三件事：
- 建立运行时上下文与环境绑定（`src/core/RuntimeContext.lua`，由 `src/app/init.lua` 调用）。
- 组装游戏与 UI 状态，创建 `Game` 实例并注入到主循环（`src/game/core/runtime/Game.lua`、`src/game/flow/turn/GameplayLoop.lua`）。
- 绑定 UI 事件到意图分发链路（`src/presentation/interaction/UIEventRouter.lua`）。

运行期采用“回合推进 + 脏标记 UI 刷新”模型：
- 领域状态推进：`Game:advance_turn()` / `Game:dispatch_action()`。
- 回合编排：`GameplayLoop.tick()`。
- 脏数据消费与 UI 投影：`game:consume_dirty()` + `UIModel.update()`。

## 目录职责

- `main.lua`：唯一入口，加载应用初始化。
- `src/app/init.lua`：应用装配层。负责运行时注入、状态构建、事件注册、定时 tick 启动。
- `src/game/core/runtime/`：领域运行时核心。
  - `CompositionRoot.lua`：组装 `board/players/turn/dirty/turn_flow`。
  - `Game.lua`：领域门面，暴露 `advance_turn`、`dispatch_action`。
- `src/game/flow/turn/`：回合流程层。
  - `GameplayLoop.lua`：每帧调度中枢。
  - `GameplayLoopRuntime.lua`：输入锁、控制锁、超时计时等运行时细节。
  - `TurnDispatch.lua`：UI action 校验与落地执行。
- `src/game/flow/intent/IntentDispatcher.lua`：领域意图入口（`need_choice` / `push_popup`）。
- `src/presentation/api/`：表现层对回合层的适配接口。
  - `GameplayLoopPortsAdapter.lua`：把 UI 能力封装为 ports 给 `GameplayLoop` 使用（按 `modal/anim/ui_sync/debug/state` 分组，并保留平铺兼容）。
  - `UIView.lua`：具体 UI 渲染、弹窗/选择框、输入锁策略调用。
- `src/presentation/interaction/`：表现层交互编排。
  - `UIEventRouter.lua`：UI 点击路由到 intent（按 bind 时构建 route specs）。
  - `UIIntentBuilder.lua` + `intent_builders/`：按职责组装点击意图（基础按钮、弹窗、道具槽、选择、黑市）。
  - `UIIntentDispatcher.lua`：将 intent 分流到游戏动作或视图命令。
  - `UITouchPolicy.lua`：触控策略统一入口（托管/调试开关、批量触控、选择屏锁定、运行时节点触控）。
- `src/presentation/state/`：UI 读模型层。
  - `UIModel.lua`：从 game + env 构建/增量更新 UIModel。
  - `UIModelProjection.lua`：投影函数（当前玩家、地块、道具槽、choice/market/popup）。

## 分层依赖（Mermaid）

```mermaid
graph TD
  A[main.lua] --> B[src/app/init.lua]
  B --> C[src/presentation/interaction/UIEventRouter.lua]
  B --> D[src/game/flow/turn/GameplayLoop.lua]
  B --> E[src/presentation/api/GameplayLoopPortsAdapter.lua]

  C --> F[src/presentation/interaction/UIIntentBuilder.lua]
  C --> G[src/presentation/interaction/UIIntentDispatcher.lua]
  G --> H[src/game/flow/turn/TurnDispatch.lua]

  D --> I[src/game/flow/turn/GameplayLoopRuntime.lua]
  D --> H
  D --> E

  H --> J[src/game/core/runtime/Game.lua]
  J --> K[src/game/core/runtime/CompositionRoot.lua]

  D --> L[src/presentation/state/UIModel.lua]
  L --> M[src/presentation/state/UIModelProjection.lua]
  E --> N[src/presentation/api/UIView.lua]
```

说明：依赖方向是“应用编排层 -> 流程层 -> 领域层”，表现层通过 ports 被流程层调用，避免流程层直接依赖具体 UI 节点 API。

## 启动与 Tick 序列（Mermaid）

### 启动序列

```mermaid
sequenceDiagram
  participant M as main.lua
  participant A as src/app/init.lua
  participant V as UIEventRouter
  participant P as GameplayLoopPortsAdapter
  participant L as GameplayLoop
  participant G as Game

  M->>A: require
  A->>A: _build_state()
  A->>P: build(state)
  A->>L: new_game(state)
  L->>G: state.game_factory() -> game:new(...)
  A->>L: set_game(state, game)
  A->>V: bind(state, get_game)
  A->>A: _start_tick_loop() (SetFrameOut)
```

### Tick 序列

```mermaid
sequenceDiagram
  participant T as Timer(SetFrameOut)
  participant L as GameplayLoop.tick
  participant R as GameplayLoopRuntime
  participant D as TurnDispatch
  participant G as Game/TurnFlow
  participant U as UIModel+UIView(ports)

  T->>L: tick(game, state, dt)
  L->>R: sync_input_blocked / sync_role_control_lock
  L->>L: step_auto_runner(...)
  L->>U: step_choice_timeout / step_modal_timeout
  L->>R: update_action_button_timer
  R-->>D: dispatch next(ui_button) when timeout
  L->>R: update_detained_wait_timer(step_turn)
  R-->>D: step_turn(game) when timeout
  D->>G: advance_turn() / dispatch_action()
  L->>G: consume_dirty()
  L->>U: refresh_from_dirty + sync_status_3d
```

## 核心领域对象

- `Game`（`src/game/core/runtime/Game.lua`）
  - 领域门面，控制回合推进与动作分发。
  - 生命周期由 `CompositionRoot.assemble` 完成实体装配。
- `GameVictory`（`src/game/core/runtime/GameVictory.lua`）
  - 仅负责胜负计算与领域状态更新；通过 `MonopolyEvents.game.finished` 发出结算事件。
- `turn`（在 `CompositionRoot.lua` 初始化）
  - 持有回合态：`current_player_index`、`phase`、`pending_choice`、动画序列、计时字段等。
- `dirty`（`src/core/DirtyTracker.lua`，由 `CompositionRoot.lua` 接入）
  - 聚合状态变更标记，供 `GameplayLoop.tick` 驱动 UI 增量刷新。
- `pending_choice` / popup intent（`src/game/flow/intent/IntentDispatcher.lua`）
  - 领域向 UI 发起交互需求的统一结构。
- `UIModel`（`src/presentation/state/UIModel.lua`）
  - 面向渲染的只读快照，不直接承载领域行为。

## 扩展点

- UI 事件扩展：`src/presentation/interaction/UIEventRouter.lua`
  - 在 `_build_default_route_specs` 增加 route spec（节点名 + `build_intent`）。
- UI 触控策略扩展：`src/presentation/interaction/UITouchPolicy.lua`
  - 新增或调整“谁可点/谁不可点”规则时，优先修改该模块；`UIInputLockPolicy` 只做流程编排，不重复写触控细节。
- UI 动作语义扩展：`src/game/flow/turn/TurnDispatch.lua`
  - 新增 `action.type` 或 `ui_button.id` 分支，并走 validator。
- Tick 行为扩展：`src/game/flow/turn/GameplayLoop.lua` 与 `GameplayLoopRuntime.lua`
  - 编排逻辑放 `GameplayLoop`，计时/锁策略放 `GameplayLoopRuntime`。
- 表现能力替换：`src/presentation/api/GameplayLoopPortsAdapter.lua`
  - 可替换 ports 实现以适配不同 UI 运行时或测试桩；优先按分组子接口替换。
- 胜负表现扩展：`src/presentation/api/UIEventHandlers.lua`
  - 监听 `MonopolyEvents.game.finished` 并执行胜负面板展示，避免领域层直接依赖 UI 引擎细节。
- UI 投影扩展：`src/presentation/state/UIModelProjection.lua`
  - 新增投影函数，再由 `UIModel.build/update` 接入。

## 新人阅读路径

建议按“先主链路，再细节”的顺序：

1. `main.lua`：确认入口极简。
2. `src/app/init.lua`：看初始化装配、事件绑定、tick 启动。
3. `src/game/core/runtime/CompositionRoot.lua` 与 `src/game/core/runtime/Game.lua`：理解领域对象如何组装与推进。
4. `src/game/flow/turn/GameplayLoop.lua`：把握每帧做什么。
5. `src/game/flow/turn/GameplayLoopRuntime.lua` 与 `src/game/flow/turn/TurnDispatch.lua`：理解输入锁、超时、动作落地。
6. `src/presentation/interaction/UIEventRouter.lua`：理解 UI 点击如何变成 intent/action。
7. `src/presentation/interaction/UITouchPolicy.lua` 与 `src/presentation/interaction/UIInputLockPolicy.lua`：理解输入锁期间的触控放行/锁定边界。
8. `src/presentation/state/UIModel.lua` 与 `src/presentation/state/UIModelProjection.lua`：理解领域状态如何投影为 UI。
9. `src/presentation/api/GameplayLoopPortsAdapter.lua` 与 `src/presentation/api/UIView.lua`：理解渲染层与流程层的接口边界。

读完以上文件，基本可以独立定位：
- “按钮点击为什么没生效”（先看 `UIEventRouter.lua` -> `TurnDispatch.lua`）。
- “状态变了为什么 UI 没更新”（先看 dirty 标记 -> `GameplayLoop.tick` -> `UIModel.update`）。
- “某阶段为什么不能操作”（先看 `GameplayLoopRuntime.is_phase_input_blocked` 与锁策略）。
