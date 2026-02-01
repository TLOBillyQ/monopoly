# Monopoly 代码审查（SOLID）

## 范围与说明

- 仅审查 `monopoly` 代码；`SecretOfEscaper/` 不在范围内。
- 重点参考：`Manager/`、`Components/`、`Library/Monopoly/`、`Config/`、`Data/`、`Globals/`、`main.lua`、`init.lua`。

## SOLID 审查结论

### S（单一职责）

**优点**

- `Manager/System/Runtime.lua` 已将循环与 UI 拆到 `Manager/System/GUI/RuntimeLoop.lua` 与 `Manager/System/GUI/RuntimeUI.lua`，职责边界更清晰。
- `Manager/GameManager/Game.lua` 现在主要负责回合推进与服务访问，状态逻辑被拆到 `Manager/GameManager/GameState.lua`。
- `Manager/ChoiceManager/Choice/ChoiceRegistry.lua`、`Manager/ItemManager/Item/ItemRegistry.lua`、`Manager/ChanceManager/ChanceRegistry.lua` 将“注册”与“执行”分离，减少单点职责堆叠。

**问题**

- `Manager/System/Runtime.lua:install_game_init` 仍包含 UI 初始化、角色/单位缓存、地图实体查询、全局变量设置、加载屏控制等多类职责，属于“启动 + 运行时 + 资源绑定”混杂。
- `Manager/BoardManager/GUI/BoardView.lua:refresh_board` 同时做锚点解析、玩家单位映射、位置同步/布局、日志与告警、动画节流，函数跨度过大。
- `Manager/MovementManager/Movement/MovementService.lua` 在移动逻辑中直接处理奖励、事件广播与状态写回（位置、朝向），仍有“领域逻辑 + 应用流程 + 通知”的耦合。
- `Manager/ChanceManager/ChanceRegistry.lua` 将大量效果实现集中在同一文件，扩展时容易变成“超大工具箱”。

### O（开闭原则）

**优点**

- `ItemRegistry`/`ChanceRegistry`/`ChoiceRegistry` 已提供统一注册入口，新增类型不必修改执行器本体。
- `Manager/GameManager/CompositionRoot.lua` 的阶段表 `phases` 便于在回合流程上做替换或插拔。

**问题**

- 默认注册仍集中在 `ChanceRegistry.register_defaults` 与 `ItemRegistry.register_defaults`；新增效果通常需要改动这些文件或在外部显式调用注册，扩展路径仍偏“集中式”。
- `ChoiceService.setup` 依赖固定的 handler 组装顺序（`ChoiceHandlers/*`），新增新类 handler 往往需要回到 CompositionRoot 调整注入顺序。

### L（里氏替换）

**观察与风险**

- `ui_port` 依赖隐式“鸭子类型”接口：`GameState` 期望 `on_tile_owner_changed`，`IntentDispatcher` 期望 `push_popup`，`TurnMove` 依赖 `wait_move_anim` 等字段。缺少明确契约时，替换成测试桩或无 UI 运行会出现缺方法崩溃。
- `Game:get_service` 依赖 `services` 结构约定（`Globals.ServiceKeys`），但没有类型契约或默认实现，替换测试服务时需要额外小心。

### I（接口隔离）

**问题**

- `ui_port` 目前仍承担“弹窗通知 + 动画等待 + 地块变更通知”等多类接口，且多处模块直接访问；相较之前缩小了范围，但仍属于胖接口。
- `GameState` 同时承担状态写回与 UI 通知（`set_tile_owner`/`reset_tile`），导致下层模块无法仅依赖纯状态接口。

### D（依赖倒置）

**问题**

- 多个服务直接依赖 `Config.Generated.*` 与全局事件 API：
  - `MovementService` 依赖 `Config.Generated.Constants` 与 `TriggerCustomEvent`。
  - `MarketService` 直接读取 `Config.Generated.Market/Items/Vehicles`。
  - `LandActions` 直接依赖 `Config.Generated.Constants` 与 `TriggerCustomEvent`。
- `Runtime` 与 `EventHandlers` 直接调用 `UIManager`、`LuaAPI`、`RegisterCustomEvent` 等环境级接口，隔离层较薄，测试替换难度仍高。

## 性能考量

**潜在热点**

- `Manager/System/GUI/RuntimeLoop.lua:tick` 每帧都会执行多段逻辑（自动行动、超时检查、动画派发、UI 刷新、日志），在低帧率设备上可能成为主开销。
- `Manager/BoardManager/GUI/BoardView.lua:refresh_board` 内部包含锚点解析、玩家单位映射与位置同步，尽管有缓存，但仍在频繁刷新时产生可观成本。
- `Manager/MovementManager/Movement/MovementService.lua:move` 逐步遍历并在每一步进行多次查表与事件派发，长步数与多分支会放大开销。
- `Manager/LandManager/Land/LandActions.lua:execute_pay_rent` 计算连续地块租金时可能触发广度遍历，且每次落地都会重复计算。
- `Manager/MarketManager/Market/MarketService.lua:list_buyable` 每次进入黑市都遍历并排序完整配置，数量增大后会带来额外开销。

**优化建议**

- 将 `RuntimeLoop.tick` 的日志与 UI 刷新拆分为“定帧刷新/变化驱动”，例如仅在状态变化或间隔帧时刷新面板与输出日志。
- 为 `refresh_board` 增加更细粒度的变化检测（例如仅在玩家位置变化或单位映射变化时触发），并避免在无动画/无位置变化时重复布局。
- 在 `MovementService.move` 中将“事件/日志派发”延迟到移动结束后批量处理，减少单步分发次数。
- 为租金计算引入缓存或预计算（按 owner 与区块聚合），在地产状态未变化时复用结果。
- 为黑市可购买列表增加缓存与失效策略（依赖库存/余额变化），避免每次都全量排序。

## 改进建议

1. **拆分 Runtime 引导逻辑**：将 `Runtime.install_game_init` 中的 UI 初始化、地图实体查询、全局资源绑定抽为 `RuntimeBootstrap` 或 `SceneAdapter`，`Runtime` 保持“生命周期/循环控制”。
2. **明确 UI 端口契约**：新增 `UIPort` 约定（函数表 + 默认空实现），让 `GameState` 与 `IntentDispatcher` 依赖最小接口，并提供 `NullUI` 便于纯逻辑测试。
3. **领域结果与事件分离**：让 `MovementService`/`LandActions` 返回结果与事件列表，由上层统一派发，避免服务直接触发全局事件。
4. **拆分大型注册文件**：将 `ChanceRegistry`、`ItemRegistry` 的默认注册拆到独立模块（按效果/道具分组），降低单文件复杂度并让扩展更清晰。

## 路线图（建议）

**阶段 1：低风险整理（1-2 周）**

- 抽离 `Runtime.install_game_init` 的 UI 与资源加载部分到独立模块。
- 引入 `UIPort` 约定与 `NullUI`，最小化 `GameState` 对 UI 的直接调用面。

**阶段 2：领域纯化（2-4 周）**

- 让 `MovementService`/`LandActions` 产出事件列表，事件统一由 `EventHandlers`/上层派发。
- 将 `ChanceRegistry`/`ItemRegistry` 的默认注册拆分为多个文件并在 CompositionRoot 统一装配。

**阶段 3：扩展能力（4-6 周）**

- 允许通过配置或模块自动发现注册（减少“改默认注册文件”的必要）。
- 为 `services` 增加默认实现或接口校验，降低替换成本。

## 结论

当前架构已明显朝分层与可扩展方向演进：回合流程、注册中心、运行时 UI 已拆分。主要压力仍集中在运行时引导逻辑、UI 端口接口与领域服务的副作用（事件/配置/环境依赖）。按“Runtime 拆分 + UI 契约 + 事件下沉”的路线推进，可进一步提升可测试性与可维护性。
