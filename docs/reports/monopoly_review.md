# Monopoly 代码审查（SOLID）

## 范围与说明

- 仅审查 `monopoly` 代码；`SecretOfEscaper/` 为模板工程，不在范围内。
- 重点参考：`Manager/`、`Components/`、`Library/Monopoly/`、`Config/`、`Data/`、`Globals/`、`main.lua`/`init.lua`。

## SOLID 审查结论

### S（单一职责）

**优点**

- `Components/Flow.lua`、`Components/Store.lua`、`Components/Board.lua`、`Components/Player.lua`职责较清晰，类边界明确。
- `Manager/GameManager/CompositionRoot.lua`集中装配依赖，降低了多处拼装的复杂度。

**问题**

- `Manager/System/Runtime.lua`同时负责时间格式化、日志初始化、UI初始化、ECA事件桥接、角色与单位缓存、地图实体查询、游戏创建与启动、帧更新循环，职责过多。
- `Manager/BoardManager/GUI/BoardView.lua`中的 `refresh_board` 聚合了“地图锚点解析”“玩家单位映射”“位置同步/布局”“日志与告警”“动画节流”等多个层面。
- `Manager/GameManager/Game.lua`既是领域模型又直接触发UI端口（`ui_port`）行为，并维护动画队列与胜负判定，职责叠加。
- `Manager/MovementManager/Movement/MovementService.lua`在移动计算的同时直接处理奖励、状态更新与日志输出，领域规则和应用流程耦合。

### O（开闭原则）

**优点**

- 通过 `ChoiceService.register` 与 `ChoiceService.setup` 提供了扩展入口。

**问题**

- `Manager/ItemManager/Item/ItemExecutor.lua`以静态表 `item_handlers` 绑定道具逻辑；新增道具大多需要改动此文件。
- `Manager/GameManager/Chance.lua`的 `handlers` 表写死效果映射，扩展机会卡需修改核心模块。
- `Manager/ChoiceManager/Choice/ChoiceService.lua`的 `setup` 强依赖固定 handler 列表，新增选择类型需要回到 CompositionRoot/ChoiceService 修改。

### L（里氏替换）

**观察与风险**

- 多处“鸭子类型”依赖隐式接口：如 `Game.ui_port` 期望具备 `push_popup/on_tile_owner_changed` 等方法（`Manager/GameManager/Game.lua`、`Library/Monopoly/IntentDispatcher.lua`）。
- 这些依赖缺少明确契约，替换实现（如测试桩、纯逻辑运行）时容易缺失方法而崩溃。

### I（接口隔离）

**问题**

- `ui_port` 作为“胖接口”，被 `Game`、`AdapterLayer`、`TurnMove`、`IntentDispatcher` 等多个模块调用，且方法并非所有场景都需要（例如动画、弹窗、地块渲染、ECA转发）。
- `Game` 作为服务容器暴露过多方法（`update_player_position`、`set_tile_owner`、`queue_action_anim` 等），下游服务依赖面过大，难以形成最小接口。

### D（依赖倒置）

**问题**

- 领域逻辑直接依赖具体实现和配置：
  - `Manager/MarketManager/Market/MarketService.lua` 直接依赖 `Config.Market/Items/Vehicles`。
  - `Manager/MovementManager/Movement/MovementService.lua` 直接依赖 `Config.Constants` 和具体 `Inventory`。
  - `Manager/LandManager/Land/LandActions.lua` 直接依赖 `Config.Constants` 与 `Inventory`。
- `Manager/System/Runtime.lua` 直接引用 `GameAPI/LuaAPI/UIManager` 等环境级接口，没有隔离层；测试与替换困难。

## 改进建议

1. **分离运行时与领域层**：将 `Runtime` 中的 UI/场景初始化、单位查询、ECA转发拆到独立模块，`Runtime` 仅负责引导与生命周期。
2. **收敛 UI 依赖面**：为 `ui_port` 定义最小接口（如 `UIActions`、`UIRender`、`UIEvents`），用适配器聚合，降低上层调用的“胖接口”。
3. **域服务纯化**：将 `MovementService/MarketService/LandActions` 中的日志、UI触发、动画队列等副作用集中到“应用层/事件层”。领域方法只返回结果与事件。
4. **效果/道具注册化**：为机会卡、道具与选择类型建立注册中心或数据驱动描述（配置+处理器映射），避免修改核心模块。
5. **依赖注入收敛**：在 `CompositionRoot` 中显式注入配置与服务，让领域逻辑依赖抽象（接口/函数表），而非直接 `require` 具体模块。

## 路线图（建议）

**阶段 1：低风险整理（1-2 周）**

- 在 `Manager/System/` 下新增 `RuntimeInit/RuntimeLoop` 之类的模块拆分 `Runtime`。
- 为 `ui_port` 定义最小接口文档与适配器（不改调用方行为，先加适配层）。
- 为 `Game` 增加事件回调出口（例如 `game.events.emit`），把 `set_tile_owner` 的 UI 通知迁移到事件层。

**阶段 2：域服务纯化（2-4 周）**

- 调整 `MovementService` 返回“结果+事件”（如 `passed_start/landed_on/roadblock_hit`），日志和动画由上层处理。
- 将 `LandActions/MarketService/Chance` 的 UI/日志调用迁移到“应用层处理器”。

**阶段 3：扩展能力建设（4-6 周）**

- 引入“效果/道具/选择类型注册中心”，将 `ItemExecutor`、`Chance`、`ChoiceService.setup` 的硬编码改为注册式。
- 在 `CompositionRoot` 里集中注册默认处理器，后续可以通过新增模块扩展而不改核心文件。

## 结论

整体模块划分已经具备一定的分层思路，但运行时、UI与领域逻辑仍有较多交叉，导致 SOLID 中的 SRP、ISP、DIP 承压。按上述路线图逐步拆分并建立注册/事件体系，可以显著提升可测试性与扩展性。
