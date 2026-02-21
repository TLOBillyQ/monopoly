# Monopoly Lua 项目架构

## 概览

项目入口是 `main.lua`，只负责加载 `src/app/init.lua`。初始化分两段：
- 立即执行：`init.lua` 先 `RuntimeInstall.install()` 安装运行时上下文（`src/app/bootstrap/RuntimeInstall.lua`），再 `GameStartup.build_state(...)` 构建全局 `state`（含 `game_factory`、`auto_runner`、UI 交互状态与事件监听）。
- 延迟到 `GAME_INIT`：`UIBootstrap.install(state, current_game_ref)` 注册启动回调，在回调里构建 UI 节点、注入 `GameplayLoopPortsAdapter`、创建并挂载 `Game`、绑定点击路由、启动 `SetFrameOut` 常驻 tick（`src/app/bootstrap/UIBootstrap.lua`）。

运行期主模型是“状态机回合推进 + 脏标记增量刷新”：
- 领域推进：`Game:advance_turn()` / `Game:dispatch_action()`。
- 流程编排：`GameplayLoop.tick()` + `TurnFlow`（底层 `Flow:step()`）。
- 增量渲染：`game:consume_dirty()` -> `UIModel.update()` -> `UIView.render()`。

## 分层与职责

- `main.lua` / `src/app/init.lua`：装配层。负责把领域、流程、表现层拼起来。
- `src/app/bootstrap/`：启动编排层。
  - `RuntimeInstall.lua`：安装 `RuntimeContext` 与运行时 helper。
  - `GameStartup.lua`：构建全局 `state`，定义 `state.game_factory`，注册 choice/modal 相关事件桥接。
  - `UIBootstrap.lua`：注册 `GAME_INIT`，挂接 UI、ports、loop 与点击路由。
- `src/app/testing/`：测试配置注入层。
  - `TestProfileBootstrap.lua`：按测试 profile 修改玩家初始资源与地块归属。
- `src/game/core/runtime/`：领域运行时核心。
  - `CompositionRoot.lua`：组装 `board/players/turn/dirty/registries`。
  - `Game.lua`：领域门面，暴露 `advance_turn`、`dispatch_action`。
  - `MonopolyEvents.lua`：领域事件命名空间。
- `src/game/flow/turn/`：回合流程层。
  - `GameplayLoop.lua`：每帧主调度。
  - `GameplayLoopRuntime.lua`：输入锁、控制锁、计时器同步策略。
  - `TurnDispatch.lua`：动作校验与执行（`ui_button` / `choice_*`）。
  - `TurnFlow.lua`：回合阶段状态机（`run_until_wait` / `dispatch` / wait states）。
  - `GameplayLoopPorts.lua`：流程层能力接口聚合与默认实现填充。
- `src/core/Flow.lua`：通用状态机步进器，供 `TurnFlow` 驱动阶段流转。
- `src/game/flow/intent/IntentDispatcher.lua`：领域侧对 UI 的意图出口（`need_choice`、`push_popup`）。
- `src/presentation/api/`：表现层对流程层的适配。
  - `GameplayLoopPortsAdapter.lua`：把 `UIView/UIModel/动画/日志` 适配到 ports。
  - `UIView.lua`：UI 渲染与显示控制（modal/popup/input lock 等）。
  - `UIEventHandlers.lua`：监听领域事件并驱动表现层效果（日志、遮罩清理、结算面板）。
- `src/presentation/interaction/`：交互编排层。
  - `UIEventRouter.lua`：注册节点点击并路由为 intent。
  - `UIIntentBuilder.lua` + `intent_builders/`：按场景构造 intent。
  - `UIIntentDispatcher.lua`：intent 分流到游戏动作或纯视图命令。
  - `UIChoiceRoutePolicy.lua`：`choice.kind -> choice screen` 路由策略。
  - `UIModalStateCoordinator.lua`：modal 相关状态写入协调。
  - `UIInputLockPolicy.lua` / `UITouchPolicy.lua` / `UIRoleControlLockPolicy.lua`：输入与触控规则。
  - `UIEventState.lua`：交互态派生判断（例如 debug 是否启用）。
- `src/presentation/state/`：UI 读模型。
  - `UIModel.lua`：构建与增量更新。
  - `UIModelProjection.lua`：领域状态到展示字段的投影函数集合。

## Ports 契约

`GameplayLoop` 不直接依赖具体 UI 节点 API，只依赖 `GameplayLoopPorts` 五组接口（`src/game/flow/turn/GameplayLoopPortTypes.lua`）：
- `modal`：选择框/弹窗开关。
- `anim`：移动动画、动作动画、3D 状态层同步。
- `ui_sync`：倒计时、脏刷新、输入锁读写、UI 状态读取。
- `debug`：调试日志可见性与同步。
- `state`：角色控制锁、事件处理器安装、破产地块清理。

默认实现在 `GameplayLoopPorts.lua`，项目实际注入来自 `GameplayLoopPortsAdapter.build(state)`。

## 主链路时序

### 启动链路

1. `main.lua` 加载 `src/app/init.lua`。
2. `init.lua` 立即执行 `RuntimeInstall.install()` 安装运行时上下文与 helper。
3. `init.lua` 调用 `GameStartup.build_state(current_game_ref)` 构建 `state`。
4. `UIBootstrap.install(...)` 注册 `GAME_INIT` 回调。
5. `GAME_INIT` 触发后，回调内完成：UI 节点构建 -> ports 注入 -> `new_game/set_game` -> 点击绑定 -> board/UI 初始化。
6. 回调最后启动 `SetFrameOut`，循环调用 `GameplayLoop.tick(game, state, dt)`。

### 建局与测试配置链路

1. `state.game_factory` 读取角色配置并加载 `Config.Map`。
2. `Config/Map.lua` 根据 `Config.GameplayRules.test_profile` 选择 `Config.Maps.*`，未命中时回退默认地图。
3. `game:new({... map_cfg ...})` 创建领域对象后，调用 `TestProfileBootstrap.apply(game, test_profile)`。
4. `TestProfileBootstrap` 可覆盖玩家现金、余额、道具与部分地块归属/等级，用于 QA 与回归场景复现。

### Tick 链路

1. `GameplayLoopRuntime` 同步输入锁与角色控制锁。
2. `AutoRunner` 与超时逻辑可能触发 `TurnDispatch.dispatch_action(...)`。
3. 回合推进由 `TurnFlow` 驱动：`dispatch/run_until_wait` 内部循环 `Flow:step()`，在 `wait_choice`、动画等待等状态停住等待外部输入或事件。
4. 领域推进后消费脏标记：`game:consume_dirty()`。
5. `ui_sync.refresh_from_dirty` 更新 `UIModel` 并驱动 `UIView`。
6. `anim.sync_status_3d` 与 `debug.sync_debug_log` 做补充同步。

## 状态机说明

- `Flow`（`src/core/Flow.lua`）只做一件事：根据当前 state 名称执行对应 handler，并返回下一个 state 名称。
- `TurnFlow`（`src/game/flow/turn/TurnFlow.lua`）把回合阶段函数注册成 `states`，并定义 `wait_states`（如 `wait_choice`、`wait_move_anim`、`wait_action_anim`、`detained_wait`）。
- `GameplayLoop` 不直接硬编码阶段跳转，只通过 `TurnFlow` 推进；这样 UI 选择、动画完成、自动执行都能在同一套 phase/wait 语义下收敛。

## 扩展点

- 新增 UI 点击入口：改 `src/presentation/interaction/UIEventRouter.lua` 的 route specs。
- 新增 intent 语义：改 `src/presentation/interaction/UIIntentBuilder.lua` 与对应 `intent_builders/*`。
- 新增动作执行语义：改 `src/game/flow/turn/TurnDispatch.lua` 与 `TurnDispatchValidator.lua`。
- 新增 choice 页面路由：改 `src/presentation/interaction/UIChoiceRoutePolicy.lua`。
- 调整输入锁/触控放行：优先改 `src/presentation/interaction/UIInputLockPolicy.lua` 与 `UITouchPolicy.lua`。
- 替换流程层依赖能力：改 `src/presentation/api/GameplayLoopPortsAdapter.lua`（按组替换 ports）。
- 扩展领域事件到表现层：改 `src/presentation/api/UIEventHandlers.lua`。
- 扩展 UI 投影字段：改 `src/presentation/state/UIModelProjection.lua`，再接入 `UIModel.lua`。

## 新人阅读路径

1. `main.lua`
2. `src/app/init.lua`
3. `src/app/bootstrap/RuntimeInstall.lua`
4. `src/app/bootstrap/GameStartup.lua`
5. `src/app/bootstrap/UIBootstrap.lua`
6. `Config/Map.lua`
7. `src/app/testing/TestProfileBootstrap.lua`
8. `src/game/core/runtime/CompositionRoot.lua`
9. `src/game/core/runtime/Game.lua`
10. `src/core/Flow.lua`
11. `src/game/flow/turn/TurnFlow.lua`
12. `src/game/flow/turn/GameplayLoop.lua`
13. `src/game/flow/turn/TurnDispatch.lua`
14. `src/presentation/interaction/UIEventRouter.lua`
15. `src/presentation/interaction/UIIntentDispatcher.lua`
16. `src/presentation/state/UIModel.lua`
17. `src/presentation/api/GameplayLoopPortsAdapter.lua`

读完后通常可以快速定位三类问题：
- 点击无响应：`UIEventRouter` -> `UIIntentDispatcher` -> `TurnDispatch`。
- 状态变化未渲染：`DirtyTracker` -> `GameplayLoop.tick` -> `UIModel.update`。
- 特定阶段不可操作：`GameplayLoopRuntime` + `UIInputLockPolicy` + `UITouchPolicy`。
