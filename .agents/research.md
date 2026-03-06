# Monopoly 代码库架构审查

> **评注**: 标题过于笼统，建议改为《Monopoly 代码库 Clean Architecture 审查报告》以明确审查方法论。

本次审查基于 Clean Architecture 视角，重点检查依赖方向、用例边界、端口适配器设计，以及宿主运行时与 UI 细节是否渗透进核心业务。结论是：仓库已经具备清晰的分层意图，也有依赖规则测试作为护栏，但当前仍未完全满足 Clean Architecture 的核心约束。最大的风险不是”目录没有分层”，而是”用例语义和宿主细节仍然穿透边界”，导致 `game/core`、`game/flow`、`app/bootstrap`、`presentation` 之间存在多处职责混杂。

> **评注**: 这段摘要写得很好，抓住了核心矛盾——“目录分层”≠”边界清晰”。建议补充一句：当前架构属于”分层骨架正确，但语义泄漏严重”的中间状态。

## 架构结论

当前架构已经出现明显的”圈层轮廓”：`game/core` 持有核心状态，`game/flow` 编排回合流程，`presentation` 负责 UI 与渲染，`app/bootstrap` 负责启动装配。
但它还没有真正做到”依赖只朝内层流动、外层只是细节”：宿主运行时 API 仍然停留在 `src/core` 与部分业务模块里，用例层仍直接操纵 UI 状态和模态框，`presentation` 也承接了不少应用级决策。
因此，这套架构可以继续演进，而不建议推倒重来；优先目标应是把最关键的边界从”共享可变 state + 约定字段”收敛成”稳定端口 + DTO/事件输出”。

> **评注**: “继续演进而非推倒重来”的判断很务实。但建议增加一个前提条件：必须先补齐契约测试，否则重构风险不可控。没有测试防护的演进式重构很容易陷入”改一点、坏一片”的困境。

## 当前分层映射

### 1. Entities / Enterprise Rules

- `src/game/core/player/Player.lua`
- `src/game/core/player/Inventory.lua`
- `src/game/core/runtime/Game.lua`
- `src/game/core/runtime/GameStatePlayers.lua`
- `src/game/core/runtime/GameStateTiles.lua`
- `src/game/core/runtime/GameStateTurn.lua`
- `src/game/systems/board/Board.lua`
- `src/game/systems/land/*`、`src/game/systems/items/*`、`src/game/systems/chance/*`、`src/game/systems/effects/*`

这里承载玩家、棋盘、资产、道具、效果、机会卡、地块规则等核心业务概念。整体上，这一层已经与 UI 目录物理隔离，且 `tests/internal/dep_rules.lua` 也在主动保护部分依赖方向。

> **评注**: 目录结构符合 Clean Architecture 的 Entities 层定义，但有一个疑问：`GameStatePlayers/Tiles/Turn` 看起来更像是应用层状态而非纯领域实体。建议澄清它们与 `Game` 实体的关系——如果它们只是 Game 的聚合子对象，应作为内部模块而非独立文件存在。当前扁平化结构可能导致实体层膨胀。

### 2. Use Cases / Application Rules

- `src/game/runtime/TurnEngine.lua`
- `src/game/runtime/PhaseRegistry.lua`
- `src/game/flow/turn/GameplayLoop.lua`
- `src/game/flow/turn/TurnDispatch.lua`
- `src/game/flow/turn/TurnDecision.lua`
- `src/game/flow/turn/*`
- `src/game/flow/intent/IntentDispatcher.lua`

这里是回合推进、输入分发、等待动画、超时、托管、选择分支、市场导航等应用规则最集中的区域，也是当前边界最容易塌陷的地方。

> **评注**: "最容易塌陷"的表述准确。但这里有一个结构性问题被忽略了：`game/runtime` 与 `game/flow` 的区分标准是什么？从文件命名看两者都用例相关，但目录上被拆分了。建议明确分层原则：> - `runtime` = 跨回合的生命周期管理（引擎、注册表）> - `flow` = 单回合内的状态机推进
> 如果无法清晰区分，考虑合并为 `game/usecases` 以减少认知负担。

### 3. Interface Adapters

- `src/presentation/api/*`
- `src/presentation/render/*`
- `src/presentation/ui/*`
- `src/presentation/interaction/*`
- `src/presentation/state/*`
- `src/presentation/read_model/GameplayReadPort.lua`

这一层名义上是外层 adapter，但实际上包含了两类东西：

- 真正的 adapter：`api/host_runtime`、`render/*`、`UIViewService`、`HostRuntimePort`
- 已经吞下应用规则的模块：`interaction/*`、`choice_screen_service/*`、`TargetChoiceEffects.lua`、`UIModalPresenter.lua`

> **评注**: 这里识别出了关键的"语义泄漏"问题。但我想进一步追问：`GameplayReadPort.lua` 放在 `read_model` 子目录下，是否暗示团队已经意识到 CQRS 的需求？如果是，建议明确区分：
> - Command 路径（写入）应通过 Input Port 进入用例层
> - Query 路径（读取）可直接从 Repository/DAO 到 ReadModel
> 目前的结构看起来 ReadPort 仍然混杂在 presentation 中，可能混淆了读取模型与展示模型的职责。

### 4. Frameworks & Drivers / Composition Root

- `src/app/init.lua`
- `src/app/bootstrap/RuntimeInstall.lua`
- `src/app/bootstrap/GameStartup.lua`
- `src/app/bootstrap/UIBootstrap.lua`
- `src/app/bootstrap/GameRuntimeBootstrap.lua`
- `src/app/bootstrap/GameStartupEventBridge.lua`
- `src/core/RuntimeContext.lua`
- `src/core/runtime_ports/DefaultPorts.lua`

入口集中在 `src/app/init.lua`，启动顺序明确：`RuntimeInstall -> GameStartup -> EventBridge -> UIBootstrap -> GameRuntimeBootstrap`。  
问题在于：组合根虽然存在，但并不纯，部分宿主细节和 UI 协调代码仍散落到 `src/core` 与 `src/app/bootstrap` 中。

> **评注**: 启动顺序看起来合理，但 `RuntimeContext` 放在 `src/core` 是一个关键错误。按 Clean Architecture，`core` 应该是最内层、最稳定的领域核心，而 RuntimeContext 显然依赖外层宿主环境。建议将 `RuntimeContext` 迁移到 `src/app/context` 或 `src/infrastructure/context`，以符合"向内依赖"原则。目前的目录结构会误导新开发者认为 `core` 是"框架核心"而非"领域核心"。

## 主要问题（P0-P3）

### P0: 宿主运行时细节仍停留在”内层”模块，Dependency Rule 被破坏

> **评注**: P0 定级合理，这是 Clean Architecture 的底线问题。但建议增加一个量化指标：统计 `src/core` 中直接依赖宿主 API 的行数/比例，作为技术债务的可视化指标。

最严重的问题是，`src/core` 并不只是稳定策略层，而是混入了对宿主运行时的直接访问。

证据：

- `src/core/Logger.lua`
  - 直接依赖 `GlobalAPI.show_tips`
  - 直接依赖 `SetTimeOut`
  - `configure_game_time()` 直接依赖 `GameAPI.get_timestamp/get_hour/get_minute/get_second`
- `src/core/RuntimeContext.lua`
  - 直接依赖 `GameAPI.get_role`
  - 直接依赖 `GameAPI.get_all_valid_roles`
  - 直接安装 `vehicle_helper/camera_helper/all_roles` 这类运行时辅助对象

> **评注**: `RuntimeContext` 中的 helper 安装是典型的时间耦合反模式。如果 helper 必须在特定时机初始化，应显式声明生命周期阶段（如 `onPreInit`、`onPostInit`），而非在 Context 构造函数中隐式完成。

- `src/core/runtime_ports/DefaultPorts.lua`
  - 默认端口直接依赖 `GameAPI`、`SetTimeOut`、`TriggerCustomEvent`

> **评注**: "默认端口"本身不是问题（适配器模式允许有默认实现），但问题在于它位于 `src/core` 目录。建议将 `DefaultPorts.lua` 重命名为 `EggyRuntimePorts.lua` 并迁移到 `src/infrastructure/egg_runtime/` 或 `src/adapters/runtime/egg/`，使其物理位置符合架构意图。

- `src/game/systems/market/service/Purchase.lua`
  - `_build_goods_mappings()` 直接调用 `GameAPI.get_goods_list`
  - `_register_purchase_event_for_role()` 直接调用 `RegisterTriggerEvent`

影响：

- `core` 无法作为真正稳定的内圈策略层存在。
- 测试虽然能跑通，但大量默认实现天然绑定 Eggy runtime，替换宿主或做纯业务回归时成本很高。
- “port” 只是把调用包了一层，并没有把 runtime 细节真正赶到外圈。

> **评注**: 第三点最致命——“虚假抽象”。当前代码看似用了 Port/Adapter 模式，实际上只是加了一层 indirection，依赖方向仍是从内向外（`core` -> `GameAPI`）。真正的 Clean Architecture 要求外层实现内层定义的接口，依赖方向应是 `infrastructure` -> `core`（向内依赖）。

### P1: 用例层直接操纵 UI 状态与模态框，边界对象不稳定

> **评注**: 这是经典的"用例层知道太多"反模式。Clean Architecture 中，用例层应该通过 Output Port 输出"意图"，而非直接操作 UI 状态。

当前 `game/flow` 不只是表达用例意图，还直接改 UI 相关的共享 state，并显式打开/关闭 modal。

证据：

- `src/game/flow/turn/GameplayLoop.lua`
  - `_configure_pending_choice()` 直接写 `state.pending_choice`
  - 直接构建 `state.ui_model`
  - 直接调用 `modal_ports.open_choice_modal(state, model.choice, model.market)`
  - `_initialize_ports()` 中把 `game.ui_port` 直接挂到 `game`
- `src/game/flow/turn/TurnDispatch.lua`
  - 大量读写 `state.pending_choice`、`state.pending_choice_id`、`state.pending_choice_elapsed`
  - 大量读写 `state.ui_dirty`
- `src/game/flow/turn/TurnDecision.lua`
  - 通过 `game.ui_port.state.pending_choice_elapsed` 读取 UI 可见时间

影响：

- 用例层无法脱离当前 UI 状态结构独立运行。
- `state` 既是应用状态，又是 UI 协调状态，边界模糊。
- 未来替换 UI 表达方式时，会牵动 `game/flow` 这类本应稳定的用例编排层。

### P1: `game.ui_port` 形成反向渗透，内层对象知道外层 adapter 的挂载方式

> **评注**: 术语建议：”反向渗透”不如用”向内依赖”（Inward Dependency）或”依赖倒置违规”（DIP Violation）更精确。核心问题是：外层对象图的结构泄漏到了内层。

这是另一个关键的边界问题。内层模块不该知道”UI port 挂在 game.ui_port 上，并且有哪些字段/方法”。

证据：

- `src/game/flow/intent/IntentDispatcher.lua`
  - 直接断言 `game.ui_port.push_popup`
- `src/game/core/runtime/Bankruptcy.lua`
  - 直接通过 `game.ui_port:push_popup(...)` 推送提示
- `src/game/flow/turn/TurnMove.lua`
  - 直接读取 `game.ui_port.wait_move_anim`
- `src/game/flow/turn/TurnRoll.lua`
  - 直接读取 `game.ui_port.wait_action_anim`

影响：

- 应用规则与 UI adapter 的对象图直接耦合。
- 这不是“通过端口依赖抽象”，而是“通过共享对象拿到具体 adapter”。
- 一旦 `ui_port` 的结构变化，影响面会横跨多个业务模块。

### P1: `presentation` 层已经承接了不少应用规则，而不只是输入/输出适配

> **评注**: 这是 MVC 遗留问题的典型表现。如果项目早期是基于 MVC 模式开发的，这种泄漏几乎是必然结果——Controller 倾向于积累业务逻辑。建议明确区分：MVVM/MVP 才是 Clean Architecture 的友好模式，presentation 层应该只包含 ViewModel 和 View。

`presentation` 在 import 方向上基本守住了边界，但语义边界已经开始泄漏。

证据：

- `src/presentation/interaction/UIIntentDispatcher.lua`
  - 负责把 intent 分流到 game action / view command
- `src/presentation/interaction/ui_intent_dispatcher/GameActionDispatcher.lua`
  - 处理 item phase、pre-confirm、market 翻页/确认、auto 语义转换
- `src/presentation/interaction/ui_intent_dispatcher/PreConfirmFlow.lua`
  - 直接读取 `Config.Generated.Market`
  - 直接依据 `choice.kind`、`screen_key`、商品种类决定二次确认逻辑
- `src/presentation/ui/choice_screen_service/common.lua`
  - 直接编码 `buy_land`、`upgrade_land`、`tax_card_prompt`、`item_phase_choice`
  - 通过 `game.board:get_tile_by_id(...)` 生成确认文案
- `src/presentation/render/TargetChoiceEffects.lua`
  - 识别 `roadblock_target`、`demolish_target`
  - 直接读取 `game.turn.pending_choice`
  - 负责 target 选择合法性与锁定逻辑

影响：

- UI 层不只是“显示模型”，还在做应用级条件判断和流程控制。
- `choice.kind/meta` 已经成为横跨用例层与 UI 层的隐式协议。
- 这种协议不稳定，后续新增 choice 类型时容易继续把业务分支堆进 UI。

### P1: `app/bootstrap` 是”半组合根”，但仍承载 UI-specific 协调逻辑

> **评注**: “半组合根”的表述很形象。组合根（Composition Root）应该是纯装配代码（Pure DI），不应该包含任何业务决策逻辑。

按 Clean Architecture，组合根可以依赖外层细节；问题不在”组合根依赖 presentation”，而在于它开始承载本该属于 adapter 自己的逻辑。

证据：

- `src/app/bootstrap/GameStartup.lua`
  - 直接依赖 `src.presentation.render.BoardRuntime`
  - 直接依赖 `src.presentation.api.UIViewService`
  - 把 `push_popup/on_tile_upgraded/on_tile_owner_changed` 这些 UI 回调塞进共享 `state`
- `src/app/bootstrap/GameRuntimeBootstrap.lua`
  - 通过 `presentation_ports.build()` 构造 `state.gameplay_loop_ports`
  - 启动 tick loop，并将 ports 与当前 game/state 绑定
- `src/app/bootstrap/UIBootstrap.lua`
  - 直接使用 `RegisterTriggerEvent`、`UIManager.Builder`、`SetTimeOut`
  - 在 `GAME_INIT` 生命周期里同时完成 UI 初始化和 runtime 启动
- `src/app/bootstrap/GameStartupEventBridge.lua`
  - 监听游戏事件后，直接构建 `presentation.state.UIModel`
  - 直接调用 `UIViewService.open_choice_modal`

影响：

- 组合根与 adapter 内部逻辑混杂。
- 启动层不只是“装配对象”，而是在做 UI 生命周期与事件回放。
- 将来替换 UIManager 或改造 choice 呈现时，会牵动启动层。

### P1: 市场购买链路跨越 domain、外部支付、回调兑现、UI 刷新，职责过载

> **评注**: 这是典型的”事务脚本”（Transaction Script）模式在领域模型中的滥用。购买逻辑涉及支付（外部系统）、库存（领域）、UI 刷新（展示）三个关注点，应该拆分为：领域服务（PurchaseDomainService）、支付适配器（PaymentGateway）、事件处理器（PaymentCallbackHandler）。

`src/game/systems/market/service/Purchase.lua` 是当前最明显的”边界塌陷点”。

证据：

- 负责商品名到 goods_id 的映射：`_build_goods_mappings()`
- 负责发起外部购买：`_start_external_purchase()`
- 负责监听平台回调：`_register_purchase_event_for_role()`
- 负责业务兑现：`_fulfill_paid_goods_purchase()`
- 负责刷新 market pending choice：`_refresh_market_choice_after_paid_callback()`

影响：

- 一个模块同时承担 domain service、runtime adapter、event bridge、presentation refresh 协调。
- 这是后续最适合切第一刀的高收益边界，因为它高度耦合、变化频繁、验证困难。

### P2: 依赖规则测试已经有价值，但主要保护”静态 import”，没有保护”语义边界”

> **评注**: 静态 import 检查（如 `presentation` 不能 `require(“src.game.*”)`）只是第一道防线，真正的架构守护需要语义级检查。建议引入架构契约测试（Architectural Contract Tests），验证：
> - 用例层不直接修改 UI 状态（通过拦截 `state.ui_*` 的写入）
> - 领域层不调用外部 API（通过禁止 `GameAPI` 符号）

现有测试体系是优点，但仍偏迁移治理，不足以阻止架构继续滑坡。

证据：

- `tests/internal/dep_rules.lua`
  - 能禁止 `presentation` 直接 `require("src.game.*")`
  - 能禁止旧 bridge、旧全局 API、若干直连路径
- `tests/suites/runtime_ports_contract.lua`
  - 能保护 strict runtime context / ports 约束
- `tests/suites/usecase_boundary_contract.lua`
  - 能保护少量 `turn_action_port` 与 clock contract

缺口：

- 没有规则禁止 `game/flow` 直接写 `state.ui_*` 这类 presentation 协议字段
- 没有规则禁止 `src/core` 继续出现 `GameAPI/GlobalAPI/SetTimeOut`
- 没有规则限制 `presentation` 读取业务语义（如 `choice.kind/meta`）后继续堆更多应用规则
- 没有规则约束 `app/bootstrap` 只能装配，不能直接操作 UI model/service

### P3: 分层命名和实际职责存在偏差，可读性成本偏高

> **评注**: P3 定级偏低，我认为这是 P1 级别的问题。命名是架构沟通的首要工具，`src/core` 的误命名会系统性地误导每个新加入的开发者。

典型例子：

- `src/core` 名字看起来像”最内层核心”，实际上混有 runtime 适配细节
- `src/presentation` 名字看起来像”纯视图适配层”，实际上包含了一部分应用级流程
- `src/app/bootstrap` 名字看起来像”纯启动装配”，实际上承载了生命周期和 UI 事件桥接

这不会直接导致 bug，但会持续抬高新成员理解成本，也让架构治理规则更难写清楚。

> **评注**: 建议的目录重命名方案：
> - `src/core` → `src/domain` 或 `src/entities`
> - `src/presentation` → `src/adapters/ui` 或 `src/infrastructure/ui`
> - `src/app/bootstrap` → `src/composition` 或保持现状但拆分出 `src/lifecycle`

## 正向观察

- 依赖规则测试是明显资产，说明团队已经在主动治理架构，而不是完全失控。
- `RuntimePorts`、`GameplayLoopPorts`、`PresentationPorts` 的方向是正确的，说明边界反转意识已经存在。
- `src/game/core`、`src/game/runtime`、`src/game/flow`、`src/game/systems` 的目录分工，已经能看出”实体 / 用例编排 / 子域规则”的基础轮廓。
- 全量回归当前可通过，说明这套结构虽然不够干净，但仍具备稳定演进的工程基础。

> **评注**: 这四点观察客观且建设性。但建议补充一个”时间维度”的观察：当前架构债务是否随时间恶化？如果新代码继续违反边界，需要更激进的治理措施（如代码门禁）；如果只是历史遗留，可以渐进式修复。

## 最小可落地重构方案

以下方案按”最小切口、最大收益、可渐进迁移”排序，不建议一次性全量重构。

> **评注**: “不建议一次性全量重构”是明智的。但建议补充一个关键前提：**必须建立架构守护测试（Architecture Fitness Functions）**，防止重构过程中新代码继续违反边界。没有护栏的渐进式重构往往演变为”新旧混杂、债务翻倍”。

### 步骤 1：先把”用例输出协议”定义清楚，停止直接写 UI state

> **评注**: 步骤 1 是正确且优先的。但建议明确协议的序列化格式——是 Lua 表结构？还是事件对象（如 `ChoiceRequestedEvent`）？建议采用事件驱动的方式，这样后续可以支持事件溯源（Event Sourcing）或审计日志。

做法：

- 在 `game/flow` 或 `app` 边界定义稳定输出协议，例如：
  - `choice_requested`
  - `popup_requested`
  - `move_anim_requested`
  - `action_anim_requested`
  - `role_control_changed`
- `GameplayLoop` / `TurnDispatch` / `IntentDispatcher` 只产出这些 DTO/事件，不直接操作 `state.pending_choice`、`state.ui_model`、`modal_ports`
- `presentation` adapter 消费这些 DTO，再决定如何刷新 UI

影响范围：

- `src/game/flow/turn/*`
- `src/game/flow/intent/IntentDispatcher.lua`
- `src/app/bootstrap/GameStartupEventBridge.lua`
- `src/presentation/api/presentation_ports/*`

预期收益：

- 先切断最频繁的跨层共享状态。
- 为后续替换 `game.ui_port` 和 UI-specific state 提供稳定锚点。

回归风险：

- 中等。因为 choice/popup/anim 都是主流程的一部分。

### 步骤 2：移除 `game.ui_port` 反向挂载，改为显式 output port / event sink

> **评注**: 步骤 2 本质上是"依赖注入容器"的设计问题。`game.ui_port` 是全局状态的一种形式，违反了"显式优于隐式"原则。建议在 `game` 对象创建时，通过构造函数注入 `outputPort`，而非运行时动态挂载。

做法：

- 用 `game.output_port` 或 `usecase_output_port` 替换 `game.ui_port`
- 端口接口只保留稳定动作语义，例如：
  - `notify_popup(payload)`
  - `notify_tile_owner_changed(tile_id, owner_id)`
  - `notify_action_anim(spec)`
- 禁止内层读取 `wait_move_anim/wait_action_anim/state` 这类 UI-specific 字段
- 动画等待条件改由 use case 输入端口返回稳定 gate 状态，而不是从 `ui_port` 里读

影响范围：

- `src/game/flow/turn/TurnMove.lua`
- `src/game/flow/turn/TurnRoll.lua`
- `src/game/flow/intent/IntentDispatcher.lua`
- `src/game/core/runtime/Bankruptcy.lua`
- `src/game/flow/turn/GameplayLoopRuntime.lua`

预期收益：

- 修正最明显的依赖方向错误。
- 让业务模块不再知道 adapter 是谁、挂在哪里。

回归风险：

- 中等偏高。因为动画等待与 popup 是用户可见路径。

### 步骤 3：把 runtime 默认实现从 `src/core` 外迁，保留 `core` 只定义抽象与纯逻辑

> **评注**: 步骤 3 涉及物理目录迁移，风险最高（可能影响 import 路径）。建议：
> 1. 先复制文件到新目录，保持旧文件为转发代理（facade）
> 2. 逐模块迁移调用方
> 3. 最后删除旧文件
> 同时，建议配套建立 "架构决策记录"（ADR），解释为什么 `core` 必须纯净。

做法：

- `src/core/Logger.lua` 只保留日志聚合与 sink 接口，不直接触达 `GameAPI/GlobalAPI/SetTimeOut`
- `src/core/runtime_ports/DefaultPorts.lua` 的 Eggy 实现外迁到 `src/app/bootstrap/runtime_install/*` 或 `src/presentation/api/host_runtime/*`
- `src/core/RuntimeContext.lua` 若继续保留，应只保存 context 数据，不直接安装宿主 helper/global

影响范围：

- `src/core/Logger.lua`
- `src/core/RuntimeContext.lua`
- `src/core/runtime_ports/DefaultPorts.lua`
- `src/app/bootstrap/RuntimeInstall.lua`

预期收益：

- 真正建立“内圈不认识宿主运行时”的边界。
- 后续测试替身、离线回归、宿主替换都会更容易。

回归风险：

- 中等。因为 runtime helper 初始化覆盖面很广，但路径相对集中。

### 步骤 4：单独拆出 Market 外部支付 adapter

> **评注**: 支付是"外部系统"的典型代表，最适合作为端口优先拆分。但需要注意：支付回调通常是异步的，需要设计一个" saga / 流程管理器"（Process Manager）来处理"支付中"的悬挂状态，防止重复发货或丢单。

做法：

- 把 `Purchase.lua` 拆成三块：
  - 纯业务规则：能否购买、扣费/兑现结果、额度限制
  - 外部支付 adapter：goods 映射、面板调用、平台回调注册
  - choice refresh / UI 协调：交给 output/event adapter
- 用 `MarketPurchasePort` 或等价接口承载支付发起与回调

影响范围：

- `src/game/systems/market/service/Purchase.lua`
- `src/game/systems/market/MarketService.lua`
- `src/app/bootstrap/*` 或专门的 runtime adapter 目录

预期收益：

- 清掉最明显的高耦合热点。
- 把“业务购买”与“Eggy 平台支付”分离，方便迭代与测试。

回归风险：

- 中等。支付链路复杂，但模块集中、切口清晰。

### 步骤 5：把 `presentation` 中的应用规则往内收，只保留 ViewModel 解释与渲染

> **评注**: 步骤 5 是最容易被低估的，因为"ViewModel"的定义很模糊。建议明确 ViewModel 的生成位置：是用例层输出 ViewModel 给 presentation，还是用例层输出 DTO，由 presentation 转换为 ViewModel？前者更干净（presentation 纯展示），后者更灵活（UI 可根据平台调整）。团队需要做出一致决策。

做法：

- `PreConfirmFlow`、`choice_screen_service/common.lua`、`TargetChoiceEffects.lua` 中与业务语义相关的判断，下沉到 use case 输出模型
- `presentation` 层只解释稳定 ViewModel，例如：
  - secondary confirm 标题/正文
  - target choice 可选项、owner、锁定状态
  - market 分页/确认能力

影响范围：

- `src/presentation/interaction/*`
- `src/presentation/ui/choice_screen_service/*`
- `src/presentation/render/TargetChoiceEffects.lua`
- `src/presentation/state/UIModel.lua`

预期收益：

- 防止 `choice.kind/meta` 继续演化成隐式跨层 DSL。
- 降低新增玩法时 UI 层的规则膨胀。

回归风险：

- 中等。主要在 modal/choice 交互回归。

## 测试建议

> **评注**: 测试建议章节很务实。建议补充第 4 类测试：集成契约测试（Integration Contract Tests），验证适配器与真实外部系统（Eggy runtime、支付平台）的契约是否仍然有效。这类测试不需要频繁运行，但在升级外部 SDK 时必须执行。

至少补齐以下三类测试：

### 1. 用例级测试

- `GameplayLoop` / `TurnDispatch` / `IntentDispatcher` 在 fake output port 下运行
- 验证输出的是稳定 DTO/事件，而不是直接写 `state.ui_*`
- 验证 choice/popup/anim/timeout 路径都能在无真实 UI 的情况下完成

### 2. 边界契约测试

- 为 `RuntimePorts`、`GameplayLoopPorts`、未来的 `MarketPurchasePort`、`ChoiceOutputPort` 建 contract tests
- 验证：
  - 内层只认识抽象，不认识 Eggy global API
  - adapter 负责把 DTO 翻译成 UI / runtime 调用
  - callback / event bridge 不再直接写 `state.ui_model`

### 3. 依赖规则补强

建议新增静态规则：

- 禁止 `src/core` 出现 `GameAPI`、`GlobalAPI`、`SetTimeOut`、`RegisterTriggerEvent`
- 禁止 `src/game/flow` 直接写 `state.ui_`、`state.pending_choice`、`state.ui_model`
- 禁止 `presentation` 直接 `require("Config.Generated.Market")` 这类业务配置，除非在专门 read-model adapter 中
- 禁止 `app/bootstrap` 直接构建 `presentation.state.UIModel` 或直接调用 `UIViewService.open_choice_modal`

> **评注**: 这四条规则清晰可执行。建议补充自动化检查工具（如 Lua 的静态分析器或简单的 grep 脚本），在 CI 中强制执行。没有自动化的规则只是建议，不是约束。

## 权衡说明

> **评注**: 权衡说明章节是这份报告的最大亮点——诚实面对技术债务的"利息"。建议补充一个量化维度：预计每个步骤的人日投入和可交付的"架构健康度"指标（如边界违规点数量）。

短期成本：

- 需要补一批端口/DTO/contract tests
- 主流程会出现一段迁移期，新旧路径可能暂时并存
- choice/popup/anim 这类用户可见路径需要更细的回归验证

长期收益：

- 新玩法接入时，规则更集中在 `game/flow` 与 `game/systems`，不会继续散落到 UI
- UI 重构、宿主 API 变化、支付链路变化时，影响面会明显收敛
- 自动化测试可以更多停留在用例层，不必总是构造完整 UI/runtime 环境
- 架构治理规则会更容易写成清晰、可持续执行的静态约束

结论上，这套架构适合”增量隔离”，不适合”大爆破重写”。优先切 `GameplayLoop` 输出协议、`game.ui_port`、`Purchase.lua`、`src/core` runtime 默认实现，收益最高。

> **评注**: 最终结论精准。但”增量隔离”需要严格的纪律性——每个 PR 必须明确说明它是在”还债”还是在”借债”。建议建立”架构债务看板”，追踪每个违规点的修复状态。否则五年后，这份报告会和无数架构文档一样，成为”知道但不做”的历史遗迹。

## 本次审查的验证依据

### 代码抽样范围

- `src/app/init.lua`
- `src/app/bootstrap/*`
- `src/core/*`
- `src/game/core/*`
- `src/game/runtime/*`
- `src/game/flow/*`
- `src/game/systems/*`
- `src/presentation/*`
- `tests/internal/dep_rules.lua`
- `tests/suites/runtime_ports_contract.lua`
- `tests/suites/usecase_boundary_contract.lua`
- `tests/suites/ui_gate_contract.lua`

### 已执行验证

在仓库根目录执行：

    lua tests/regression.lua

结果：

- 全量回归通过：`All regression checks passed (361)`
- 依赖规则通过：`dep_rules ok`
- 无 UI 环境 gameplay loop 检查通过：`tick ok`

说明：

- 当前架构在工程上是稳定可运行的。
- 审查提出的问题主要是”边界质量”和”未来演进成本”，不是”代码现在已经不可用”。

---

## 评注总结

> **整体评价**: 这是一份高质量的架构审查报告，体现了对 Clean Architecture 的深刻理解。报告的价值不仅在于指出问题，更在于：
> 1. **优先级清晰**（P0-P3 分级）
> 2. **可落地性强**（5 个渐进式步骤）
> 3. **风险诚实**（权衡说明章节）
> 4. **基于证据**（验证依据和回归测试）
>
> **主要建议加强的方面**:
> 1. **量化指标**: 补充边界违规的数量、趋势图，让技术债务可度量
> 2. **自动化门禁**: 静态规则必须配套 CI 检查，否则只是”纸面约束”
> 3. **命名重构**: `src/core` 的误命名是 P1 级别问题，不应降级为 P3
> 4. **治理机制**: 建立”架构债务看板”和 ADR 文档，确保报告成果不被遗忘
>
> **最终评分**: 8/10。报告本身优秀，但落地执行将是真正的考验。
