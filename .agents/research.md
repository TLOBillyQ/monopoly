# Monopoly 代码库 Clean Architecture 复审报告

**审查日期**: 2026-03-07  
**代码状态**: `bad3e168` 之后的最新工作树  
**代码规模**: `src/` + `tests/` 共 326 个 Lua 文件  
**审查方法**: Clean Architecture（Robert C. Martin）+ 依赖规则静态扫描 + 已有契约测试/回归入口复核

---

## 执行摘要

### 架构结论

当前代码库**已经基本满足 Clean Architecture 的核心约束**：依赖方向总体朝内，use case 与 presentation 的边界已经显式化，之前最危险的 `src/core` 宿主直连、`game.ui_port` 反向依赖、presentation 通过 `choice.kind/meta` 猜业务语义这三类问题都已被大幅收口。

这不是“还在半路”的架构了，而是**主体迁移已经完成、只剩少量边界清理与命名语义收尾**的架构。严格来说，当前主要问题已从 P0/P1 的硬违规，下降为少数兼容桥与目录语义上的 P1/P2 债务。

### 关键现状指标

- `src/core` 对 `GameAPI` / `GlobalAPI` / `SetTimeOut` / `RegisterTriggerEvent` / `RegisterCustomEvent` 的**直接全局触点为 0**。
- `src/game/flow` 对 `state.ui_*` 的**直接写入为 0**。
- `src/presentation` 中基于 `choice.kind` / `choice.meta` / `pending_choice.kind` / `pending_choice.meta` 的**核心业务推断匹配为 0**。
- 全仓库对退役 `game.ui_port` 的命中只剩 **1 处兼容 fallback**：`src/presentation/api/presentation_ports/StatePorts.lua`。
- 默认回归入口 `lua tests/regression.lua`、定向 `market` suite、定向 `presentation_ui` suite 与 `dep_rules` 当前都能证明边界已锁住。

---

## 1. 最新分层映射

### 1.1 `src/core`：稳定策略、小型端口与跨玩法公共契约

`src/core` 现在的主要职责已经从“宿主 API 集散地”收缩为“稳定基础策略层”。这里放的是数值工具、配置访问器、路由策略、事件名、角色 ID、脏标记、以及供内层复用的小型抽象。

代表文件：

- `src/core/NumberUtils.lua`
- `src/core/ChoiceRoutePolicy.lua`
- `src/core/RoleId.lua`
- `src/core/DirtyTracker.lua`
- `src/core/events/MonopolyEvents.lua`
- `src/core/config/*.lua`

但这里仍保留了少量**语义上更像基础设施/运行时适配**的模块，例如：

- `src/core/RuntimeContext.lua`
- `src/core/RuntimeEventBridge.lua`
- `src/core/runtime_ports/DefaultPorts.lua`
- `src/core/RuntimeState.lua`
- `src/core/RuntimePorts.lua`

因此，`src/core` 在依赖方向上已经安全，但在目录语义上仍不够“纯”。

### 1.2 `src/game/flow`：用例编排层

`src/game/flow` 现在已经是非常清晰的 Application / Use Case 层。它负责回合推进、输入分发、输出端口发射、dirty 状态协调、以及 gameplay loop 的时序编排。

关键变化是：它不再直接改 `state.ui_*`，而是通过输出端口和 grouped ports 与外层通信。

代表文件：

- `src/game/flow/ports/UseCaseOutputPort.lua`
- `src/game/flow/turn/GameplayLoop.lua`
- `src/game/flow/turn/GameplayLoopPorts.lua`
- `src/game/flow/turn/TurnDispatch.lua`
- `src/game/flow/intent/IntentDispatcher.lua`

其中 `IntentDispatcher.open_choice()` 现在是边界穿越的关键点：它把 use case 层定义的稳定 choice 协议复制进运行时 `pending_choice`，从而保证 presentation 消费的是显式 DTO，而不是回头猜业务。

### 1.3 `src/game/systems`：业务规则层

`src/game/systems` 现在承担 Monopoly 的规则本体：地块、道具、机会卡、市场、动画请求、着陆效果等。这里已经明显更像 Enterprise Rules / 领域规则层，而不再是 UI 与宿主 API 的混合区。

代表文件：

- `src/game/systems/land/*`
- `src/game/systems/items/*`
- `src/game/systems/chance/*`
- `src/game/systems/market/service/*`

其中 Market 是本轮重构最典型的成功案例：

- `Choice.lua` 负责构造 market choice 输出。
- `ChoiceSession.lua` 负责 session 刷新与 pending-choice 回写。
- `Purchase.lua` 只保留购买编排。
- `LocalPurchase.lua` / `PaidPurchaseGateway.lua` / `PaidFulfillment.lua` / `PurchasePolicy.lua` / `Feedback.lua` / `ChoiceOutcome.lua` 分别承接本地购买、外部支付桥接、兑现、资格校验、失败反馈、购买后续动作。

这已经非常接近 Clean Architecture 里“用例依赖端口、细节留在外层适配器”的理想状态。

### 1.4 `src/presentation`：Interface Adapters / 展示适配层

`src/presentation` 现在主要负责四件事：

1. 组装 `ui_model`
2. 把 choice / popup / market ViewModel 渲染到具体 UI
3. 把 UI 输入翻译成 turn action
4. 监听外层运行时事件，驱动显示同步

代表文件：

- `src/presentation/state/UIModel.lua`
- `src/presentation/ui/UIChoice.lua`
- `src/presentation/state/ui_model/ChoiceSlice.lua`
- `src/presentation/render/TargetChoiceEffects.lua`
- `src/presentation/interaction/ui_intent_dispatcher/PreConfirmFlow.lua`
- `src/presentation/api/PresentationPorts.lua`

这一层最重要的进步是：**它已经不再把 `choice.kind` / `meta` 当成隐式 DSL 来解释业务**。现在它主要消费显式字段，例如：

- `route_key`
- `requires_confirm`
- `confirm_title` / `confirm_body`
- `owner_role_id`
- `uses_item_slots`
- `pre_confirm_before_slot_pick`
- `uses_target_picker`
- `target_picker_owner_role_id`
- `active_tab` / `page_index` / `page_count`

这意味着 presentation 已从“半个业务层”退回到了真正的 adapter。

---

## 2. 主要问题（P0-P3）

### P0：当前没有新的硬性 Dependency Rule 违规

这次复审没有看到新的 P0。此前最严重的三类问题——`src/core` 宿主全局耦合、`game.ui_port` 反向渗透、presentation 业务推断——都已经不再构成系统级硬违规。

如果按 Clean Architecture 最核心的标准判断：**当前核心业务已经不再被 UI、宿主 API 或支付面板直接控制**。

### P1-1：`StatePorts` 仍保留一条 `game.ui_port` 兼容回退

文件：`src/presentation/api/presentation_ports/StatePorts.lua`

`on_bankruptcy_tiles_cleared()` 已优先走 `board_scene_port`，但仍保留：

- `game.ui_port:get_board_scene()` fallback
- `ui_port.board_scene` fallback

这不是大面积渗透，但它说明旧的 retired interface 还没有被完全删除。它的问题不在“数量大”，而在**它继续允许外层适配器从退役共享对象取依赖**，会让后续维护者误以为 `game.ui_port` 仍是合法边界。

判断：这是当前最值得优先清掉的剩余 P1。

### P1-2：`src/core` 仍承载部分运行时适配细节，目录语义没有完全收口

关键文件：

- `src/core/RuntimeContext.lua`
- `src/core/RuntimeEventBridge.lua`
- `src/core/runtime_ports/DefaultPorts.lua`
- `src/core/RuntimePorts.lua`
- `src/core/RuntimeState.lua`

这些模块已经不再直接读取宿主全局，但它们仍明显带有 Frameworks & Drivers / Interface Adapter 色彩：

- `RuntimeContext` 安装 LuaAPI 能力与 helper
- `RuntimeEventBridge` 负责自定义事件桥接
- `DefaultPorts` 提供 runtime port 的默认实现
- `RuntimeState` 定义共享运行时缓存形状

这类代码放在 `src/core` 并不会立即破坏依赖方向，但会弱化“core 应表达稳定策略而非运行时细节”的架构信号。也就是说，它更像**命名/归属仍未完全表达业务**，而不是依赖方向再次错误。

### P2-1：`RuntimeState` 仍是跨层共享表结构，边界契约隐含在字段约定里

关键文件：

- `src/core/RuntimeState.lua`
- `src/game/flow/ports/UseCaseOutputPort.lua`
- `src/presentation/state/UIModel.lua`
- `src/presentation/api/presentation_ports/*.lua`

现在的边界已经比早期强很多，但 `ui_runtime` / `board_runtime` / `anim_runtime` / `turn_runtime` 仍是共享 table schema。好处是迁移成本低、兼容旧逻辑容易；坏处是：

- 契约仍主要靠字段命名约定维护
- `UseCaseOutputPort`、`RuntimeState`、presentation ports 三方需要保持同步理解
- 缺少更显式的 DTO / state contract 模块时，字段漂移风险仍存在

它已经不是“直接写 UI 状态”的旧问题，但仍属于边界表达不够强的 P2。

### P2-2：`src/game/runtime` 与 `src/presentation/read_model` 的命名仍有语义歧义

关键文件：

- `src/game/runtime/TurnEngine.lua`
- `src/game/runtime/PhaseRegistry.lua`
- `src/presentation/read_model/GameplayReadPort.lua`

`src/game/runtime` 实际上更像 use case engine shell，而不是外部 runtime 适配层。`src/presentation/read_model` 目前也不是一个独立查询架构层，而是 presentation 的辅助读模型目录。

这不会破坏代码运行，但会削弱 Screaming Architecture：目录首先在“说技术安排”，而不是“说业务与边界”。这是典型 P2，而不是必须立即大修的 P1。

### P3-1：choice 稳定协议已经落地，但还缺少单一的协议清单模块

关键文件：

- `src/game/flow/intent/IntentDispatcher.lua`
- `src/presentation/ui/UIChoice.lua`
- `src/presentation/state/ui_model/ChoiceSlice.lua`
- `docs/architecture/boundaries.md`

本轮已经把协议真正串通了，但协议字段列表仍散在多个模块里，主要靠代码对齐与测试保护。现在这样是可工作的，但从长期一致性看，后续如果 choice 字段继续扩展，最好把“哪些字段属于稳定协议”集中到一个 schema/helper/documented contract 中，否则维护者容易只改 builder，不改 runtime copy 或 presenter。

这属于可读性与一致性层面的 P3，不影响当前整体架构判断。

---

## 3. 哪些重构阶段已经可视为完成

### 阶段 0：架构守护 —— 已完成

证据：

- `tests/internal/dep_rules.lua`
- `tests/suites/architecture_guard_contract.lua`
- `tests/regression.lua`

静态规则、动态契约和统一回归入口都已建立，而且不是“文档上完成”，而是持续运行中的完成。

### 阶段 1：用例输出协议 —— 已完成

证据：

- `src/game/flow/ports/UseCaseOutputPort.lua`
- `src/game/flow/turn/GameplayLoopPorts.lua`
- `src/game/flow/turn/GameplayLoop.lua`
- `src/game/flow/turn/TurnDispatch.lua`

`src/game/flow` 已经不再直接写 `state.ui_*`，说明输出协议迁移已经跨过“名义完成”，进入“行为完成”。

### 阶段 2：移除 `game.ui_port` 隐式挂载 —— 基本完成

证据：

- `src/game` 层扫描下，退役 `game.ui_port` 命中已清零
- 当前只剩 `src/presentation/api/presentation_ports/StatePorts.lua` 的兼容 fallback

因此，这个阶段对**核心用例层和业务层**来说已经完成；对“全仓库彻底删除兼容桥”来说，还剩一个收尾点。

### 阶段 3：runtime 适配器外迁 —— 依赖方向已完成，目录语义未完全完成

证据：

- `src/app/bootstrap/RuntimeInstall.lua`
- `src/app/bootstrap/runtime_install/RuntimeGlobalAliases.lua`
- `src/app/bootstrap/runtime_install/RuntimePortDefaults.lua`

如果看 Dependency Rule，这个阶段已经完成，因为 `src/core` 不再直接触碰宿主全局。如果看目录语义与圈层表达，则还留有一段“runtime-like 模块仍在 core”的尾巴，因此我把它评价为：

- **依赖规则层面：完成**
- **目录语义层面：部分完成**

### 阶段 4：Market 购买链路拆分 —— 已完成

证据：

- `src/game/systems/market/service/Purchase.lua`
- `src/game/systems/market/service/LocalPurchase.lua`
- `src/game/systems/market/service/PaidPurchaseGateway.lua`
- `src/game/systems/market/service/PaidFulfillment.lua`
- `src/game/systems/market/service/PurchasePolicy.lua`
- `src/game/systems/market/service/Feedback.lua`
- `src/game/systems/market/service/ChoiceOutcome.lua`
- `src/game/systems/market/service/ChoiceSession.lua`

这一阶段已经达到 Clean Architecture 需要的“细节可替换、用例保留编排、适配器留在边界”的水平，没有继续拆碎 `Purchase.lua` 的必要。

### 阶段 5：presentation 应用规则清理 —— 已完成

证据：

- `src/game/flow/intent/IntentDispatcher.lua`
- `src/presentation/ui/UIChoice.lua`
- `src/presentation/state/ui_model/ChoiceSlice.lua`
- `src/presentation/interaction/ui_intent_dispatcher/PreConfirmFlow.lua`
- `src/presentation/render/TargetChoiceEffects.lua`

关键不是“少了几个 if”，而是 choice 稳定协议已经跨过边界，presentation 不再需要反查业务含义。这一点已经成立，所以阶段 5 可以视为完成。

### 阶段 6：目录语义整理 —— 文档化完成，激进重命名未做

证据：

- `docs/architecture/boundaries.md`

如果“完成”的定义是把职责边界固化进仓库并指导后续开发，那么它已经完成。如果“完成”的定义是重命名目录、迁移 require 路径、把语义上的不完美全部修到极致，那么它还没有做那一步。

因此，这一阶段的准确判断是：**文档与约束层面已完成，目录重命名层面被有意延后**。

---

## 4. 重构方案（按最小剩余工作排序）

### 步骤 1：删除 `StatePorts` 的 `game.ui_port` fallback

**影响范围**: 小  
**关键文件**: `src/presentation/api/presentation_ports/StatePorts.lua` 及相关测试  
**预期收益**: 彻底删除退役 `game.ui_port` 的最后一处兼容桥，让阶段 2 从“基本完成”变成“彻底完成”  
**回归风险**: 低；只要补一条 bankruptcy / board-scene 契约测试即可

建议做法：只保留 `board_scene_port` 路径；如果缺失就显式 no-op，不再回退旧对象图。

### 步骤 2：把 `RuntimeContext` / `RuntimeEventBridge` / `DefaultPorts` 从 `src/core` 迁到更外层的 runtime/infrastructure 目录

**影响范围**: 中  
**关键文件**: `src/core/RuntimeContext.lua`、`src/core/RuntimeEventBridge.lua`、`src/core/runtime_ports/DefaultPorts.lua`、`src/core/RuntimePorts.lua`、`src/app/bootstrap/*`  
**预期收益**: 让 `src/core` 真正“只表达稳定策略”，提升目录语义与 Clean Architecture 可读性  
**回归风险**: 中；需要同步修正 require 路径和 `runtime_ports_contract`

建议做法：不是大挪仓，而是先把这些模块迁到 `src/app/bootstrap/runtime_*` 或新的 `src/infrastructure/runtime`，再由 `src/core` 保留最小壳或纯接口。

### 步骤 3：把 choice 稳定协议整理成单一 schema / contract helper

**影响范围**: 中  
**关键文件**: `src/game/flow/intent/IntentDispatcher.lua`、`src/presentation/ui/UIChoice.lua`、`src/presentation/state/ui_model/ChoiceSlice.lua`  
**预期收益**: 防止后续新增字段时发生“builder 改了，runtime copy 没改，presenter 又靠 fallback 顶上”的漂移  
**回归风险**: 低到中；主要是字段透传回归

建议做法：不是引入复杂类型系统，而是新增一个小型 choice contract helper，集中声明允许透传的显式字段。

### 步骤 4：只在边界完全稳定后，再考虑目录重命名

**影响范围**: 中到大  
**关键文件**: `src/game/runtime/*`、`src/presentation/read_model/*`、相关 require 引用  
**预期收益**: 让目录更“会说话”  
**回归风险**: 中；纯重命名噪音大，容易掩盖真实行为变化

建议做法：把这一步视为“独立提交的纯语义整理”，不要与行为改动混做。

---

## 5. 测试建议

### 5.1 用例级测试

至少继续保持两类用例回归：

- `market` suite：验证 Market 购买编排、session 刷新、choice build purity、外部支付回调刷新
- `gameplay` / `presentation_ui` 相关 suite：验证 choice 打开、二次确认、target picker、modal 生命周期、owner 约束

重点不是覆盖更多 UI 细节，而是验证：**用例输出了什么，presentation 就消费什么**。

### 5.2 边界契约测试

建议补强三类契约：

1. `StatePorts` 只能通过 `board_scene_port` 获取 scene，禁止再读 `game.ui_port`
2. choice 稳定协议字段透传契约：builder → `IntentDispatcher.open_choice()` → `pending_choice` → `UIChoice` / `ChoiceSlice`
3. runtime 适配契约：`RuntimeContext` / `RuntimePorts` 迁移后，默认端口与 bootstrap 安装仍保持行为一致

### 5.3 现有回归入口继续保留单一真相源

继续以这几个入口作为单一事实标准：

- `lua tests/internal/dep_rules.lua`
- `lua -e "package.path = package.path .. ';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; require('TestHarness').run_all({ require('market') })"`
- `lua -e "package.path = package.path .. ';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; require('TestHarness').run_all({ require('presentation_ui') })"`
- `lua tests/regression.lua`

这是当前架构演进最有价值的资产之一，不应再分裂成多套互不一致的入口。

---

## 6. 权衡说明

### 短期成本

- 若继续把 runtime-like 模块迁出 `src/core`，会带来一轮 require 路径调整和契约测试修订。
- 若把 choice 协议进一步集中声明，会多一个薄层 helper，需要维护字段清单。
- 若彻底删除最后的兼容 fallback，少数旧测试/老路径可能需要显式补端口。

### 长期收益

- `src/core` 会真正变成稳定内核，目录语义更符合 Clean Architecture，也更便于新人阅读。
- choice 边界会从“靠经验维持”变成“靠协议和测试维持”，后续新增交互的成本明显下降。
- 删除最后一条 `game.ui_port` 兼容桥后，这条退役边界就能彻底从代码库语义中消失，不再误导后续开发。

### 总体判断

当前最正确的策略不是重新大拆，而是**接受主体迁移已经成功，改做小步收尾**。也就是说：现在的重点已经不是“救火式架构翻修”，而是“把最后几个语义毛边修平，防止回退”。

---

## 7. 最终结论

从 Clean Architecture 视角看，Monopoly 代码库已经跨过了最难的阶段：核心业务不再被宿主 API、UI 共享状态或 market 细节直接牵制，依赖规则总体成立，用例层与展示层边界也已经由显式协议维持。

剩下的问题是真实但有限的：一条 `game.ui_port` 兼容回退、几块 runtime-like 模块仍停在 `src/core`、以及少量目录命名还没有完全“scream business”。这些问题值得继续修，但它们已经属于**收尾质量问题**，不再是**架构方向问题**。
