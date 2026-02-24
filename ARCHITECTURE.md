# Monopoly Lua 项目架构

## 概览

项目入口是 `main.lua`，只负责加载 `src/app/init.lua`。初始化分两段：
- **立即执行**：`init.lua` 先调用 `RuntimeInstall.install()` 安装运行时上下文（`src/app/bootstrap/RuntimeInstall.lua`），再调用 `GameStartup.build_state(...)` 构建全局 `state`（含 `game_factory`、`auto_runner`、UI 交互状态与事件监听）。
- **延迟到 `GAME_INIT`**：`UIBootstrap.install(state, current_game_ref)` 注册启动回调，在回调里构建 UI 节点、注入 `GameplayLoopPortsAdapter`、创建并挂载 `Game`、绑定点击路由、启动 `SetFrameOut` 常驻 tick（`src/app/bootstrap/GameRuntimeBootstrap.lua`）。

运行期主模型是**"状态机回合推进 + 脏标记增量刷新"**：
- **领域推进**：`Game:advance_turn()` / `Game:dispatch_action()`。
- **流程编排**：`GameplayLoop.tick()` + `TurnFlow`（底层 `Flow:step()`）。
- **增量渲染**：`game:consume_dirty()` -> `UIModel.update()` -> `UIView.render()`。

## 分层与职责

### 入口与装配层

- `main.lua`：唯一入口，加载 `src/app/init.lua`。
- `src/app/init.lua`：装配层，按序初始化运行时、state、事件桥接、UI启动。

### 启动编排层 (`src/app/bootstrap/`)

- `RuntimeInstall.lua`：安装 `RuntimeContext` 与运行时 helper，预加载核心类。
- `GameStartup.lua`：构建全局 `state`，定义 `state.game_factory`，处理角色列表或调试玩家回退。
- `GameStartupEventBridge.lua`：注册领域事件监听（`need_choice`、`tile_upgraded` 等），桥接到 UI 层。
- `GameRuntimeBootstrap.lua`：在 `GAME_INIT` 后启动运行时，初始化 ports、创建游戏实例、启动 tick 循环。
- `UIBootstrap.lua`：注册 `GAME_INIT` 回调，构建 UI 节点、验证节点完整性、初始化场景和资产。

### 测试配置注入层 (`src/app/testing/`)

- `TestProfileBootstrap.lua`：按测试 profile 修改玩家初始资源（现金、余额、道具）与地块归属/等级。

### 核心框架 (`src/core/`)

- `Flow.lua`：通用状态机步进器，供 `TurnFlow` 驱动阶段流转。
- `DirtyTracker.lua`：脏标记管理（players、board_tiles、turn、market、turn_countdown、inventory_ids）。
- `RuntimeContext.lua`：运行时上下文封装（GameAPI/LuaAPI）。
- `Logger.lua`：日志记录，支持每回合信息条数限制。
- `NumberUtils.lua`：数值处理工具。

### 领域运行时核心 (`src/game/core/runtime/`)

- `Game.lua`：领域门面，暴露 `advance_turn`、`dispatch_action`，混入 `GameStateOps` 和 `GameVictory`。
- `CompositionRoot.lua`：组装 `board/players/turn/dirty/registries`，初始化游戏状态。
- `Bootstrap.lua`：创建并初始化各系统注册表（items、choices、chances、effects）。
- `MonopolyEvents.lua`：领域事件命名空间（movement、land、market、chance、game、intent）。
- `PhaseRegistry.lua`：定义默认回合阶段（start、roll、move、landing、post_action、end_turn）。
- `GameFactory.lua`：构建棋盘、RNG、玩家列表。
- `GameStateOps.lua`：聚合玩家、地块、回合状态操作。
- `GameStatePlayers.lua`：玩家状态操作（现金、余额、道具、位置、神明、载具等）。
- `GameStateTiles.lua`：地块状态操作（所有者、等级）。
- `GameStateTurn.lua`：回合状态操作（待选动作、动画队列）。
- `GameVictory.lua`：胜利条件检测。
- `Agent.lua` / `AgentTargeting.lua`：AI代理与目标选择。
- `Bankruptcy.lua`：破产处理。
- `player_state/`：玩家状态子操作（BalanceOps、DeityOps、LocationOps、StatusOps、VehicleOps、Common）。

### 回合流程层 (`src/game/flow/turn/`)

- `GameplayLoop.lua`：每帧主调度，协调输入锁、角色控制锁、自动执行、动画、脏刷新。
- `GameplayLoopRuntime.lua`：输入锁、控制锁、计时器同步策略。
- `GameplayLoopPorts.lua`：流程层能力接口聚合与默认实现填充。
- `GameplayLoopPortTypes.lua`：Ports 类型定义（modal/anim/ui_sync/debug/clock/state）。
- `TurnFlow.lua`：回合阶段状态机，驱动 `Flow:step()`，管理 wait 状态（wait_choice、wait_move_anim、wait_action_anim、detained_wait）。
- `TurnDispatch.lua`：动作校验与执行（`ui_button` / `choice_select` / `choice_cancel`）。
- `TurnDispatchValidator.lua`：动作校验逻辑（角色验证、选择验证、道具槽位解析）。
- `TurnStart.lua`：回合开始阶段（处理拘留、医院等状态）。
- `TurnRoll.lua`：掷骰子阶段。
- `TurnMove.lua`：移动阶段（处理路障、偷窃中断、市场中断）。
- `TurnLand.lua`：落地阶段（触发地块效果）。
- `TurnWaits.lua`：等待状态处理（动画等待）。
- `TurnChoiceHandler.lua`：选择等待处理。
- `TurnAnim.lua`：移动动画与动作动画步进。
- `TurnDecision.lua`：决策处理。
- `TurnLogger.lua`：回合日志记录。
- `TurnChoiceAutoPolicy.lua`：选择自动执行策略。
- `AutoRunner.lua`：自动执行器，按间隔自动触发 "next" 动作。
- `TickTimeout.lua`：选择超时与弹窗超时处理。
- `TickUISync.lua`：倒计时更新、UI 环境构建、脏刷新协调。
- `ItemSlotData.lua`：道具槽位数据解析。

### 意图出口 (`src/game/flow/intent/`)

- `IntentDispatcher.lua`：领域侧对 UI 的意图出口（`need_choice`、`push_popup`），负责选择ID生成、路由推断、事件发射。

### 系统层 (`src/game/systems/`)

#### 棋盘系统 (`board/`)
- `Board.lua`：棋盘管理（路径、分支、覆盖物、导航）。
- `Tile.lua`：地块定义。

#### 移动系统 (`movement/`)
- `Movement.lua`：玩家移动逻辑（步进、路障检测、经过玩家、市场中断、偷窃中断、起点奖励）。

#### 机会卡牌系统 (`chance/`)
- `ChanceResolver.lua`：机会卡牌解析与执行。
- `ChanceHandlers.lua`：处理器注册。
- `handlers/CashHandlers.lua`：现金相关效果。
- `handlers/AssetHandlers.lua`：资产相关效果。
- `handlers/MovementHandlers.lua`：移动相关效果。
- `handlers/Common.lua`：通用工具。

#### 选择系统 (`choices/`)
- `ChoiceRegistry.lua`：选择处理器注册表。
- `ChoiceResolver.lua`：选择解析辅助。
- `ChoiceHandlers/ItemChoiceHandler.lua`：道具选择。
- `ChoiceHandlers/LandChoiceHandler.lua`：地块选择（购买/升级）。
- `ChoiceHandlers/MarketChoiceHandler.lua`：市场选择。
- `ChoiceHandlers/OptionalEffectHandler.lua`：可选效果选择。

#### 商业系统 (`commerce/`)
- `PaidCurrencyBridge.lua`：付费货币桥接。

#### 效果系统 (`effects/`)
- `EffectRegistry.lua`：效果执行器注册表。
- `EffectExecutor.lua`：效果执行校验。
- `EffectPipeline.lua`：效果管道执行（条件检查、执行、后处理）。
- `EffectRunner.lua`：效果运行上下文构建。
- `MineEffect.lua`：地雷效果。

#### 道具系统 (`items/`)
- `ItemRegistry.lua`：道具处理器注册表。
- `ItemHandlers.lua`：道具处理器实现。
- `ItemExecutor.lua`：道具执行。
- `ItemInventory.lua`：道具库存管理。
- `ItemPhase.lua`：道具阶段处理（pre_action/post_action）。
- `ItemPostEffects.lua`：道具后效（目标选择规范）。
- `ItemDemolish.lua`：拆除类道具（怪物/导弹）。
- `ItemRoadblock.lua`：路障道具。
- `ItemRemoteDice.lua`：遥控骰子。
- `ItemSteal.lua`：偷窃道具。
- `ItemStrategy.lua`：道具策略。

#### 地块系统 (`land/`)
- `LandActions.lua`：地块动作（购买、升级）。
- `LandBoardUtils.lua`：地块工具。
- `LandChoiceSpecs.lua`：地块选择规范。
- `LandEvents.lua`：地块事件。
- `LandPricing.lua`：地块定价。
- `LandRules.lua`：地块规则。
- `LandingEffectExecutors.lua`：落地效果执行器注册。
- `LandingPresenter.lua`：落地表现。
- `landing_effects/BaseLandEffects.lua`：基础地块效果（空地、自己的地、他人地块租金）。
- `landing_effects/ChanceEffects.lua`：机会地块效果。
- `landing_effects/MarketEffects.lua`：市场地块效果。
- `landing_effects/SpecialTileEffects.lua`：特殊地块效果（医院、监狱、矿山等）。

#### 市场系统 (`market/`)
- `MarketService.lua`：市场服务聚合（query、choice、purchase、auto）。
- `service/Eligibility.lua`：购买资格检查。
- `service/Choice.lua`：市场选择构建。
- `service/Purchase.lua`：购买执行。
- `service/Auto.lua`：自动购买处理。

#### 载具系统 (`vehicle/`)
- `VehicleFeature.lua`：载具功能（座位解析等）。

### 表现层 (`src/presentation/`)

#### API适配层 (`api/`)
- `GameplayLoopPortsAdapter.lua`：把 `UIView/UIModel/动画/日志` 适配到 ports（modal/anim/ui_sync/debug/state）。
- `UIViewService.lua`：UI 渲染服务门面（面板刷新、道具槽、输入锁、角色控制锁、弹窗）。
- `TurnActionPort.lua` / `TurnActionPortAdapter.lua`：回合动作端口适配。
- `UIRuntimePort.lua`：UI运行时端口（角色解析、事件发送）。
- `UIEventHandlers.lua`：监听领域事件并驱动表现层效果（日志、遮罩清理、结算面板）。
- `ports/ModalPorts.lua`：弹窗/选择框端口。
- `ports/AnimPorts.lua`：动画端口（移动动画、动作动画、3D状态同步）。
- `ports/UISyncPorts.lua`：UI同步端口（倒计时、脏刷新、输入锁）。
- `ports/DebugPorts.lua`：调试端口。
- `ports/StatePorts.lua`：状态端口（角色控制锁、事件处理器、破产清理）。
- `ui_view_service/`：UIViewService 子模块（assets、core、debug、item_slots、state）。

#### 交互编排层 (`interaction/`)
- `UIEventRouter.lua`：注册节点点击并路由为 intent。
- `UIEventBindings.lua`：UI事件绑定工具。
- `UIEventIntents.lua`：意图类型定义。
- `UIEventState.lua`：交互态派生判断（debug是否启用）。
- `UIIntentBuilder.lua` + `intent_builders/`：按场景构造 intent（Basic、ActionLog、Choice、ItemSlot、Market、Popup）。
- `UIIntentDispatcher.lua`：intent 分流到游戏动作或纯视图命令。
- `UIChoiceRoutePolicy.lua`：`choice.kind -> choice screen` 路由策略。
- `UIModalStateCoordinator.lua`：modal 相关状态写入协调。
- `UIInputLockPolicy.lua`：输入锁策略。
- `UITouchPolicy.lua`：触控放行策略。
- `UIRoleControlLockPolicy.lua`：角色控制锁策略。
- `UICanvasCoordinator.lua`：画布协调（debug画布切换）。

#### 渲染层 (`render/`)
- `BoardScene.lua`：棋盘场景初始化。
- `BoardRuntime.lua`：棋盘运行时刷新（地块归属、等级变化）。
- `board_runtime/`：子模块（anchors、events、placement、player_units）。
- `MoveAnim.lua`：移动动画播放。
- `ActionAnim.lua`：动作动画播放。
- `ActionAnimDice.lua`：骰子动画。
- `ActionAnimHandlers.lua`：动作处理器。
- `ActionAnimRegistry.lua`：动作注册表。
- `ActionAnimUnits.lua`：动作单位。
- `Status3DService.lua`：3D状态服务（角色头顶状态图标）。
- `status3d_service/`：子模块（meta、scene、specs、status）。
- `TileRenderer.lua`：地块渲染。
- `BuildingEffects.lua`：建筑效果。
- `MarketView.lua`：市场视图。

#### UI层 (`ui/`)
- `UIPanel.lua`：面板UI。
- `UIPanelPresenter.lua`：面板刷新实现。
- `UIModalPresenter.lua`：模态框/弹窗呈现。
- `UIChoice.lua`：选择界面。
- `PopupRenderer.lua`：弹窗渲染。
- `MarketModalRenderer.lua`：市场弹窗渲染。
- `UITurnEffects.lua`：回合效果UI。
- `choice_screen_service/`：选择屏幕服务（common、openers）。

#### 状态层 (`state/`)
- `UIModel.lua`：UI读模型构建与增量更新。
- `UIModelProjection.lua`：领域状态到展示字段的投影函数集合。
- `UIModelPanelBuilder.lua`：面板数据构建。
- `UIRoleAvatar.lua`：角色头像。
- `UIRoleContext.lua`：角色上下文。

#### 共享层 (`shared/`)
- `UINodes.lua`：UI节点定义与验证。
- `UIEvents.lua`：UI事件定义（show/hide）。
- `UIAliases.lua`：UI别名。
- `PlayerColors.lua`：玩家颜色。
- `MarketLayout.lua`：市场布局。

### 配置层 (`Config/`)

- `Map.lua`：地图配置入口，根据 test_profile 选择对应地图模块。
- `Maps/DefaultMap.lua`：默认地图。
- `Maps/RingMapBuilder.lua`：环形地图构建器。
- `Maps/UIQuickAll.lua` / `UIQuickBankruptcy.lua` / `UIQuickChoice.lua`：测试地图。
- `GameplayRules.lua`：游戏规则配置。
- `TestProfiles.lua`：测试配置档案。
- `LandingEffects.lua`：落地效果定义。
- `RuntimePaidGoods.lua`：运行时付费商品。
- `RuntimeConstants.lua`：运行时常量。
- `RuntimeRefs.lua`：运行时引用。
- `Generated/`：代码生成配置（Items、Roles、Tiles、Vehicles、ChanceCards、Market、Constants）。

## Ports 契约

`GameplayLoop` 不直接依赖具体 UI 节点 API，只依赖 `GameplayLoopPorts` 六组接口（`src/game/flow/turn/GameplayLoopPortTypes.lua`）：

| 组名 | 职责 |
|------|------|
| `modal` | 选择框/弹窗开关（close_choice_modal、open_choice_modal、close_popup） |
| `anim` | 移动动画、动作动画、3D状态层同步（play_move_anim、play_action_anim、reset_status_3d、sync_status_3d） |
| `ui_sync` | 倒计时、脏刷新、输入锁读写、UI状态读取（update_countdown、refresh_from_dirty、apply_input_lock、is_input_blocked 等） |
| `debug` | 调试日志可见性与同步（log_status、sync_debug_log、resolve_debug_enabled） |
| `clock` | 时间戳与差值计算（now、diff_seconds） |
| `state` | 角色控制锁、事件处理器安装、破产地块清理（apply_role_control_lock、install_event_handlers、on_bankruptcy_tiles_cleared） |

默认实现在 `GameplayLoopPorts.lua`，项目实际注入来自 `GameplayLoopPortsAdapter.build(state)`。

## 主链路时序

### 启动链路

1. `main.lua` 加载 `src/app/init.lua`。
2. `init.lua` 立即执行 `RuntimeInstall.install()` 安装运行时上下文与 helper。
3. `init.lua` 调用 `GameStartup.build_state(current_game_ref)` 构建 `state`。
4. `GameStartupEventBridge.install(...)` 注册领域事件桥接。
5. `UIBootstrap.install(...)` 注册 `GAME_INIT` 回调。
6. `GAME_INIT` 触发后，`GameRuntimeBootstrap.start(...)` 完成：ports注入 -> `new_game/set_game` -> 点击绑定 -> 启动 `SetFrameOut` tick 循环。
7. Tick 循环每帧调用 `GameplayLoop.tick(game, state, dt)`。

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
- `TurnFlow`（`src/game/flow/turn/TurnFlow.lua`）把回合阶段函数注册成 `states`，并定义 `wait_states`（wait_choice、wait_move_anim、wait_action_anim、detained_wait）。
- `PhaseRegistry`（`src/game/core/runtime/PhaseRegistry.lua`）定义默认阶段：start -> roll -> move -> landing -> post_action -> end_turn。
- `GameplayLoop` 不直接硬编码阶段跳转，只通过 `TurnFlow` 推进；这样 UI 选择、动画完成、自动执行都能在同一套 phase/wait 语义下收敛。

## 扩展点

| 扩展需求 | 修改位置 |
|---------|---------|
| 新增 UI 点击入口 | `src/presentation/interaction/UIEventRouter.lua` 的 route specs |
| 新增 intent 语义 | `src/presentation/interaction/UIIntentBuilder.lua` 与对应 `intent_builders/*` |
| 新增动作执行语义 | `src/game/flow/turn/TurnDispatch.lua` 与 `TurnDispatchValidator.lua` |
| 新增选择页面路由 | `src/presentation/interaction/UIChoiceRoutePolicy.lua` |
| 调整输入锁/触控放行 | `src/presentation/interaction/UIInputLockPolicy.lua` 与 `UITouchPolicy.lua` |
| 替换流程层依赖能力 | `src/presentation/api/GameplayLoopPortsAdapter.lua`（按组替换 ports） |
| 扩展领域事件到表现层 | `src/presentation/api/UIEventHandlers.lua` |
| 扩展 UI 投影字段 | `src/presentation/state/UIModelProjection.lua`，再接入 `UIModel.lua` |
| 新增道具类型 | `src/game/systems/items/ItemRegistry.lua` 注册处理器 |
| 新增选择类型 | `src/game/systems/choices/ChoiceRegistry.lua` 注册处理器 |
| 新增落地效果 | `src/game/systems/land/LandingEffectExecutors.lua` 注册执行器 |
| 新增机会卡牌 | `src/game/systems/chance/ChanceHandlers.lua` 添加处理器 |
| 新增效果类型 | `src/game/systems/effects/EffectRegistry.lua` 注册执行器 |

## 新人阅读路径

1. `main.lua`
2. `src/app/init.lua`
3. `src/app/bootstrap/RuntimeInstall.lua`
4. `src/app/bootstrap/GameStartup.lua`
5. `src/app/bootstrap/GameRuntimeBootstrap.lua`
6. `src/app/bootstrap/UIBootstrap.lua`
7. `Config/Map.lua`
8. `src/app/testing/TestProfileBootstrap.lua`
9. `src/game/core/runtime/Game.lua`
10. `src/game/core/runtime/CompositionRoot.lua`
11. `src/core/Flow.lua`
12. `src/game/flow/turn/TurnFlow.lua`
13. `src/game/flow/turn/GameplayLoop.lua`
14. `src/game/flow/turn/TurnDispatch.lua`
15. `src/presentation/interaction/UIEventRouter.lua`
16. `src/presentation/interaction/UIIntentDispatcher.lua`
17. `src/presentation/state/UIModel.lua`
18. `src/presentation/api/GameplayLoopPortsAdapter.lua`

读完后通常可以快速定位三类问题：
- **点击无响应**：`UIEventRouter` -> `UIIntentDispatcher` -> `TurnDispatchValidator` -> `TurnDispatch`
- **状态变化未渲染**：`DirtyTracker` -> `GameplayLoop.tick` -> `UISyncPorts.refresh_from_dirty` -> `UIModel.update`
- **特定阶段不可操作**：`GameplayLoopRuntime` + `UIInputLockPolicy` + `UITouchPolicy` + `UIRoleControlLockPolicy`
