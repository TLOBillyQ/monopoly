# ARCHITECTURE

## 目标

当前架构保持“领域逻辑与表现层解耦 + dirty 增量刷新”的方向，不改变功能行为。  
本轮收敛的核心是删除无语义转发层，缩短常见改动链路。

## 启动链

入口：`main.lua` -> `src/app/init.lua`

启动流程：

1. `src/app/bootstrap/RuntimeInstall.lua`：安装运行时上下文。
2. `src/app/bootstrap/GameStartup.lua`：构建初始状态。
3. `src/app/bootstrap/UIBootstrap.lua`：注册 GAME_INIT/UI 初始化逻辑。
4. `src/app/bootstrap/GameRuntimeBootstrap.lua`：注入 turn/gameplay ports、创建 game、启动 tick。

## 主循环与端口

主循环位于 `src/game/flow/turn/GameplayLoop.lua`，每帧执行 `tick(game, state, dt)`。

`GameplayLoop` 通过 `src/game/flow/turn/GameplayLoopPorts.lua` 解析端口分组：

- `modal`
- `anim`
- `ui_sync`
- `debug`
- `clock`
- `state`

`GameRuntimeBootstrap` 在启动时构建并注入 `state.gameplay_loop_ports` 与 `state.turn_action_port`。

## UI 交互链（收敛后）

1. `src/presentation/interaction/UIEventRouter.lua` 直接加载 `intent_builders/*` 并组装 route specs。
2. `UIEventBindings` 负责节点点击绑定。
3. 点击回调构造 intent 后交给 `src/presentation/interaction/UIIntentDispatcher.lua`。
4. `UIIntentDispatcher` 分流：
   - 游戏动作：走 `TurnActionPort.resolve(...).dispatch_action(...)` -> `TurnDispatch`
   - 视图命令：直接调用 `UIViewService`

关键变化：`UIIntentBuilder.lua` 已删除，路由不再多一层门面。

## UI 模型链（收敛后）

`src/presentation/state/UIModel.lua` 现在是唯一 UI 数据组装入口，内部直接包含：

- board tiles 投影
- current player 解析
- item slots / auto 标签构建
- choice/market/popup 投影
- panel 构建与增量更新

关键变化：`UIModelProjection.lua` 与 `UIModelPanelBuilder.lua` 已合并删除。

## 仍保留的边界

- `TurnActionPort.lua` 保留：它提供默认回退端口语义（空对象安全行为）。
- `GameplayLoopPortsAdapter.lua` 当前保留：测试仍直接依赖该模块路径构建端口对象。
- `MarketService.lua` 当前保留：有多个调用方，仍承担统一命名空间入口。

## 改动路径约束

新增一个按钮语义：通常只改 2 处

1. 一个 `src/presentation/interaction/intent_builders/*.lua`
2. `src/presentation/interaction/UIEventRouter.lua` 的 `_build_default_route_specs`

修改一个展示字段：通常只改 1 处

1. `src/presentation/state/UIModel.lua`
