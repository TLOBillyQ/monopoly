# Monopoly 代码库 Clean Architecture 研究报告

**审查日期**: 2026-03-07  
**代码状态**: `d8a91c5b`  
**代码规模**: `src/` 287 个 Lua 文件，`tests/` 43 个 Lua 文件，共 330 个 Lua 文件  
**审查方法**: Clean Architecture（Robert C. Martin）+ 关键模块抽样阅读 + 静态依赖扫描 + 回归入口复核  
**验证结果**: 运行 `lua tests/regression.lua architecture_guard_contract usecase_boundary_contract cross_module_contract read_model_contract runtime_ports_contract ui_gate_contract`，输出包含 `All regression checks passed (376)`、`dep_rules ok`、`tick ok`、`forbidden_globals ok`

---

## 架构结论

当前代码库不是“完全不符合 Clean Architecture”，也不是“已经只剩目录收尾”的状态。更准确的判断是：它已经在 **use case ↔ presentation** 边界上取得了实质进展，但在 **`game/systems -> game/flow` 反向依赖**、**`src/core` 运行时基础设施滞留**、以及 **UI 输出状态双轨并存** 这三处，Dependency Rule 仍未真正闭合。

因此，本仓库当前最合适的标签不是“完成态架构”，而是 **迁移中的混合架构**：外圈与内圈已经被部分切开，但仍保留几条关键的反向依赖和兼容桥。

---

## 当前关键事实

- `src/presentation` 中直接 `require("src.game.*")` 的静态扫描命中为 **0**，说明展示层没有直接反向侵入业务层。
- `src/presentation` 中基于 `choice.kind` / `choice.meta` / `pending_choice.kind` / `pending_choice.meta` 做业务推断的静态扫描命中为 **0**，说明 choice 显式字段协议已经落地。
- `src/game/flow` 中直接写 `state.ui_* =` 的静态扫描命中为 **0**，说明“回合编排层直接写 UI 根状态”这类旧耦合已被明显收口。
- `src/game/systems` 中直接 `require("src.game.flow.intent.IntentDispatcher")` 的静态扫描命中为 **9 个文件**，这是当前最明确的 Dependency Rule 反向依赖。
- `src/game` + `src/core` 中与退役 `ui_port` 兼容回退相关的引用仍有 **5 处**，说明旧适配边界还没有彻底移除。
- `src/core` 仍保留宿主/运行时触点：`RuntimeContext.lua` 直接约束 `LuaAPI` 环境，`RuntimeEventBridge.lua` 直接走 `TriggerCustomEvent` 与调试反射路径。

这些事实共同说明：**presentation 边界比 runtime/core 边界更健康，输出协议比目录语义更健康。**

---

## 1. 按当前实际落点映射四圈

本节按“当前代码真实行为”映射圈层，而不是按目录名做理想化解释。

### 1.1 Entities / Enterprise Rules

最接近企业级规则的位置主要在以下区域：

- `src/game/core/player/*`
- `src/game/systems/land/*`
- `src/game/systems/items/*`
- `src/game/systems/chance/*`
- `src/game/systems/market/service/*` 中的 `Eligibility.lua`、`PurchasePolicy.lua`、`LocalPurchase.lua`、`Fulfillment.lua`
- `src/core/NumberUtils.lua`、`src/core/RoleId.lua`、`src/core/DirtyTracker.lua`、`src/core/config/*`

这些模块大多描述玩家、地块、道具、机会卡、市场资格与兑现规则，已经具备较明显的“业务规则层”特征。

但要注意：`src/game/systems` 还没有完全成为“只向内依赖”的规则层，因为其中多处文件直接依赖 `src.game.flow.intent.IntentDispatcher`。这意味着它们还没有完全从应用编排层解耦。

### 1.2 Use Cases / Application Rules

最接近用例编排层的是：

- `src/game/flow/*`
- `src/game/runtime/*`

其中：

- `src/game/flow/turn/GameplayLoop.lua`
- `src/game/flow/turn/TurnDispatch.lua`
- `src/game/flow/turn/GameplayLoopPorts.lua`
- `src/game/flow/ports/UseCaseOutputPort.lua`
- `src/game/runtime/TurnEngine.lua`
- `src/game/runtime/PhaseRegistry.lua`

共同承担“回合如何推进、输入如何分发、超时如何处理、动画何时等待、UI 何时刷新”的应用级规则。

这一层已经出现了比较像 Clean Architecture 的端口设计：`GameplayLoopPorts` 把边界切成 `modal`、`anim`、`ui_sync`、`debug`、`clock`、`state`、`output` 七组，`UseCaseOutputPort` 则明确了 `ui_model`、`pending_choice`、modal timer 等输出语义。

### 1.3 Interface Adapters

最明显的接口适配层是：

- `src/presentation/*`
- `src/presentation/api/PresentationPorts.lua`
- `src/presentation/api/UIRuntimePort.lua`
- `src/presentation/api/UIViewService.lua`
- `src/presentation/canvas_runtime/CanvasEventRouter.lua`
- `src/game/systems/market/ports/PaidPurchasePort.lua`

它们承担两类典型 adapter 职责：

1. 把用例输出变成 UI 渲染、Modal、Target Picker、Board Scene 同步；
2. 把 UI 点击、Canvas 事件、支付回调等外部输入翻译成 turn action 或购买动作。

需要特别指出的是：`src/app/bootstrap/GameStartupEventBridge.lua` 也在做 adapter 级工作，但当前它放在 app/bootstrap 下，并且直接构建 `ui_model`、直接打开 modal，这使得边界路径变成“双通道”，削弱了 adapter 层的一致性。

### 1.4 Frameworks & Drivers

最外层细节主要在：

- `src/app/init.lua`
- `src/app/bootstrap/*`
- `src/app/bootstrap/payment/EggyPaidPurchaseGateway.lua`
- Eggy 运行时全局：`GameAPI`、`LuaAPI`、`GlobalAPI`、`SetTimeOut`、`RegisterCustomEvent`、`RegisterTriggerEvent`、`EVENT`
- UI 框架全局：`UIManager`

这里负责程序启动、宿主能力安装、UIManager 初始化、支付面板接入、事件注册、运行时别名安装等“离开 Eggy 就不存在”的细节。

这一圈的职责本来就是 outer details，所以它依赖别的层是合理的；问题在于，当前仍有部分外圈逻辑没有完全停留在外圈，而是渗入了 `src/core` 和 `src/game/core/runtime`。

---

## 2. 当前最成熟的边界

### 2.1 `game/flow -> presentation` 的分组端口边界已经成形

代表文件：

- `src/game/flow/turn/GameplayLoopPorts.lua`
- `src/game/flow/ports/UseCaseOutputPort.lua`
- `src/presentation/api/PresentationPorts.lua`
- `src/app/bootstrap/GameRuntimeBootstrap.lua`

这条边界已经具备三个健康特征：

1. 用例层依赖的是一组明确端口，而不是直接调用 `UIManager`；
2. presentation 通过 `PresentationPorts.build()` 提供实现，而不是让 `game/flow` 反查 UI 结构；
3. `board_scene_port`、`anim_gate_port` 这类窄端口已经替代了过去的 catch-all `ui_port` 大对象中的一部分职责。

### 2.2 choice 显式字段协议已经胜过隐式 `kind/meta` 解释

代表文件：

- `src/game/flow/intent/IntentDispatcher.lua`
- `src/core/ChoiceContract.lua`
- `src/presentation/state/ui_model/ChoiceSlice.lua`
- `src/presentation/interaction/ui_intent_dispatcher/PreConfirmFlow.lua`

现在 presentation 主要消费 `route_key`、`requires_confirm`、`owner_role_id`、`confirm_title`、`confirm_body`、`uses_target_picker`、`active_tab`、`page_index`、`page_count` 等显式字段，而不是回头从 `choice.kind` / `choice.meta` 猜业务。

这意味着 choice 这条边界已经从“展示层补业务语义”退回到“用例层显式输出协议，adapter 层只负责消费”。这是当前代码库最接近 Clean Architecture 的一块。

---

## 3. 主要问题（P0-P3）

### P0：业务规则层仍反向依赖用例层

这是当前最明确、最需要优先处理的 Dependency Rule 违规。

静态扫描显示，`src/game/systems` 中至少以下文件直接依赖 `src.game.flow.intent.IntentDispatcher`：

- `src/game/systems/effects/EffectPipeline.lua`
- `src/game/systems/items/ItemInventory.lua`
- `src/game/systems/items/ItemUseBroadcast.lua`
- `src/game/systems/items/ItemPhase.lua`
- `src/game/systems/market/service/ChoiceOutcome.lua`
- `src/game/systems/choices/ChoiceHandlers/LandChoiceHandler.lua`
- `src/game/systems/choices/ChoiceHandlers/ItemChoiceHandler.lua`
- `src/game/systems/choices/ChoiceHandlers/OptionalEffectHandler.lua`
- `src/game/systems/land/LandingPresenter.lua`

问题不在于“模块名叫错了”，而在于：**规则层直接调用外层编排器来打开 choice / push popup / 发意图。** 这样一来，业务规则不再独立，任何 intent 协议变化都会反向牵动 `systems`。

按 Clean Architecture 判断，这属于真正的方向错误，而不是简单的语义瑕疵。

### P1：核心/用例层仍保留 `ui_port` 兼容桥

以下位置仍然保留对退役 `ui_port` 的兼容回退：

- `src/game/core/runtime/Game.lua`
- `src/core/ActionAnimPort.lua`
- `src/game/flow/turn/TurnRoll.lua`
- `src/game/flow/turn/TurnMove.lua`

其中最典型的表现是：

- `Game:ensure_popup_port()` / `Game:ensure_tile_feedback_port()` 在端口缺失时回退到 `self["ui_port"]`
- `ActionAnimPort.is_enabled()` 回退读 `game.anim_gate_port or game["ui_port"]`
- `TurnRoll.lua` / `TurnMove.lua` 仍允许从 `game["ui_port"]` 读取动画等待开关

这说明“旧 UI 细节对象还能继续驱动内层逻辑”。即使当前测试已把新增扩散控制在小范围内，这条兼容桥仍然让核心逻辑受旧 adapter 约束。

### P1：输出边界没有唯一事实源，`ui_runtime` 与 legacy `state.*` 双轨并存

当前至少同时存在三套相近但不完全等价的 UI/choice 状态：

1. `game.turn.pending_choice` —— 业务事实；
2. `ui_runtime.pending_choice` / `ui_runtime.ui_model` / `ui_runtime.ui_dirty` —— 用例输出端口事实；
3. `state.pending_choice*` / `state.ui_model` / `state.ui_dirty` —— legacy 镜像状态。

代表文件：

- `src/game/flow/ports/UseCaseOutputPort.lua`
- `src/game/flow/ports/LegacyOutputMirror.lua`
- `src/presentation/api/presentation_ports/ui_sync/UIModelSync.lua`
- `src/game/flow/turn/TickUISync.lua`
- `src/game/flow/turn/TurnDispatchValidator.lua`
- `src/app/bootstrap/GameStartupEventBridge.lua`
- `src/presentation/interaction/UIModalStateCoordinator.lua`
- `src/presentation/ui/UIModalPresenter.lua`

这类“双轨同步”有两个后果：

- 一处变更很容易在另一条路径忘记同步；
- 测试虽然能证明“现状还能跑”，但不能证明“边界只有一条”。

从 Clean Architecture 角度看，这属于边界模糊，而不是纯命名问题。

### P2：`src/core` 的目录语义与当前职责不一致

`src/core` 现在一半像稳定策略层，一半像运行时基础设施层。

代表文件：

- `src/core/RuntimeContext.lua`
- `src/core/RuntimeEventBridge.lua`
- `src/core/RuntimePorts.lua`
- `src/core/RuntimeState.lua`
- `src/core/UIRoleGlobals.lua`

其中：

- `RuntimeContext.lua` 直接约束 `LuaAPI` 运行时环境；
- `RuntimeEventBridge.lua` 直接依赖 `TriggerCustomEvent`，还包含 `debug.getupvalue` 探测逻辑；
- `RuntimePorts.lua` 当前更像全局服务定位器，而不是纯粹的 inward-facing port definition；
- `RuntimeState.lua` 同时承接新旧 UI 状态桥接。

这些模块本身未必“写错”，但它们放在 `src/core` 里，会让目录误导读者：看起来像内核，实际却承接了明显的 infrastructure 语义。

### P2：`src/app` 仍然偏厚，启动、测试、UI bootstrap、事件桥混在一起

代表文件：

- `src/app/init.lua`
- `src/app/bootstrap/RuntimeInstall.lua`
- `src/app/bootstrap/GameStartup.lua`
- `src/app/bootstrap/GameStartupEventBridge.lua`
- `src/app/bootstrap/UIBootstrap.lua`
- `src/app/testing/TestProfileBootstrap.lua`

这里的问题不是“app 依赖太多”，因为 app 本来就是装配层；真正的问题是：**startup、testing、presentation event bridge、runtime install 的职责没有完全分开。** 这会让初始化链越来越难以推断。

### P3：目录命名还没有真正“以业务和用例大声说话”

最典型的几个例子：

- `src/game/core/runtime/*`
- `src/game/runtime/*`
- `src/presentation/read_model/*`
- `src/core/*`

这些目录名并不能直接告诉读者“这里是 enterprise rules”“这里是 use cases”“这里是 adapter”“这里是 framework details”。

这不是当前最高优先级的问题，但如果前面的硬边界不先收口，后续开发者会不断被目录语义误导。

---

## 4. 重构方案

以下步骤按“最小可落地、且能真实改善依赖方向”的顺序排列。

### 步骤 1：切断 `systems -> flow.intent` 反向依赖

**影响范围**: 中到大  
**关键文件**: `src/game/systems/*` 中当前直接依赖 `IntentDispatcher` 的模块、`src/game/flow/intent/IntentDispatcher.lua`、相关 choice/popup 流程  
**预期收益**: 把业务规则重新收回到“产出稳定意图/调用窄端口”，不再直接依赖外层编排器  
**回归风险**: 中到高；会触及道具、落地效果、market choice、choice handlers

建议做法：

- 让 `systems` 返回稳定结果（例如 `need_choice`、`push_popup`、`action_anim_request`）或调用注入的 output port；
- 保持 `IntentDispatcher` 只出现在 `game/flow`；
- 不要让 `systems` 直接知道“choice 是怎么被打开的”。

这是当前最值得优先开的第一刀。

### 步骤 2：删除最后的 `ui_port` 兼容回退

**影响范围**: 中  
**关键文件**: `src/game/core/runtime/Game.lua`、`src/core/ActionAnimPort.lua`、`src/game/flow/turn/TurnRoll.lua`、`src/game/flow/turn/TurnMove.lua`  
**预期收益**: 让内层只依赖窄端口：`popup_port`、`tile_feedback_port`、`anim_gate_port`、`board_scene_port`  
**回归风险**: 中；旧测试或旧 bootstrap 若还偷懒依赖 `ui_port`，会被一次性打出来

建议做法：

- 让 `Game` 在装配阶段就拿到必需窄端口；
- 缺失端口时尽早失败，而不是回退到 `ui_port`；
- 对保留的桥接路径补契约测试，而不是继续保留 catch-all 对象。

### 步骤 3：让 `ui_runtime` 成为唯一输出事实源

**影响范围**: 中到大  
**关键文件**: `src/game/flow/ports/UseCaseOutputPort.lua`、`src/game/flow/ports/LegacyOutputMirror.lua`、`src/core/RuntimeState.lua`、`src/presentation/api/presentation_ports/ui_sync/UIModelSync.lua`、`src/game/flow/turn/TickUISync.lua`、`src/app/bootstrap/GameStartupEventBridge.lua`、`src/presentation/interaction/UIModalStateCoordinator.lua`  
**预期收益**: choice / ui_model / modal timer / ui_dirty 只有一套状态，不再双轨同步  
**回归风险**: 中；容易影响 choice 打开、倒计时、二次确认、market 翻页等路径

建议做法：

- 先让 `UIModelSync`、`TickUISync`、`TurnDispatchValidator` 改为只读 `ui_runtime`；
- 再删 `LegacyOutputMirror`；
- 最后处理 `GameStartupEventBridge` 这条直接 build model + open modal 的旁路。

### 步骤 4：把运行时基础设施实现从 `src/core` 挪到更外层

**影响范围**: 中  
**关键文件**: `src/core/RuntimeContext.lua`、`src/core/RuntimeEventBridge.lua`、`src/core/RuntimePorts.lua`、`src/core/RuntimeState.lua`、`src/app/bootstrap/runtime_install/*`  
**预期收益**: `src/core` 更接近稳定策略层，目录语义与 Clean Architecture 读法一致  
**回归风险**: 中；主要是 require 路径与测试装配同步调整

建议做法：

- 先迁实现，不急着大改所有调用者；
- 如需兼容，短期可以在 `src/core` 保留极薄 façade；
- 目标不是“形式上搬家”，而是把 runtime detail 明确留在外圈。

### 步骤 5：瘦身 app 装配层，并补齐边界守护规则

**影响范围**: 小到中  
**关键文件**: `src/app/init.lua`、`src/app/bootstrap/*`、`tests/internal/dep_rules.lua`  
**预期收益**: 启动链更单纯，测试守护更贴近真实风险点  
**回归风险**: 低到中；多为装配与测试调整

建议做法：

- 把 test profile 装配继续收敛到 testing 入口；
- 让 `GameStartupEventBridge` 要么消失，要么退回标准 adapter 通道；
- 在 `dep_rules` 中新增规则，禁止 `src/game/systems -> src/game/flow.*`。

---

## 5. 测试建议

### 5.1 用例级测试

至少保持以下用例级测试为持续回归主线：

- `GameplayLoop` / `TurnDispatch`：验证回合推进、超时、选择、自动操作、动画等待
- `Market`：验证选择构建、购买资格、付费购买回调、session 刷新
- `ItemPhase` / `Landing` / `EffectPipeline`：验证业务规则产出的 choice/popup/anim 请求是否仍正确

重点不是测更多 UI 细节，而是测：**业务规则产出了什么、use case 如何编排这些输出、adapter 如何消费这些输出。**

### 5.2 边界契约测试

建议新增或强化以下契约：

1. **Dependency Rule 契约**  
   在 `tests/internal/dep_rules.lua` 中新增规则，禁止 `src/game/systems` 直接 require `src.game.flow.*`。

2. **退役 `ui_port` 契约**  
   把 `src/game` / `src/core` 中现存 `ui_port` 兼容引用纳入归零计划，最终预算收口到 0。

3. **单一输出事实源契约**  
   明确 `ui_model`、`pending_choice`、`ui_dirty`、modal timer 只允许从 `ui_runtime` 读取，不再允许 `state.*` 与 `ui_runtime.*` 并存读写。

4. **choice 边界契约**  
   从 `choice_spec` → `IntentDispatcher` → `pending_choice` → `presentation` 的字段透传契约继续保持；尤其是 `owner_role_id`、确认文案、target picker、market 分页字段。

5. **read model 契约**  
   如果后续继续推进 presentation 解耦，建议把更多查询收敛到 read port，而不是让 presenter/view-model 继续直接读 `game.turn`、`players`、`board` 聚合结构。

### 5.3 当前最有价值的回归入口

建议继续把以下入口视为单一事实标准：

- `lua tests/regression.lua`
- `lua tests/internal/dep_rules.lua`
- `architecture_guard_contract`
- `usecase_boundary_contract`
- `runtime_ports_contract`
- `ui_gate_contract`
- `read_model_contract`

其中本次实际复核结果表明：当前回归系统足以证明“很多旧耦合已经被压住”，但还不足以阻止 `systems -> flow` 这类新的方向错误继续存在。因此，守护规则本身也需要升级。

---

## 6. 权衡说明

### 短期成本

- 切断 `systems -> flow.intent` 会波及多个玩法路径，不是纯机械替换。
- 删除 `ui_port` 兼容桥会让部分“现在还能跑”的旧装配路径直接失败。
- 统一 `ui_runtime` 为唯一事实源，会牵动 choice、倒计时、market、modal 等多个状态同步点。
- 把 runtime 基础设施从 `src/core` 挪出去，会带来一轮 require 路径与测试装配改动。

### 长期收益

- 业务规则真正不再依赖用例编排细节，新增玩法时变更面更小。
- 用例层和展示层之间只有一条稳定输出路径，问题定位更简单。
- `src/core` 的语义会更接近“稳定内核”，新成员更容易建立正确心智模型。
- 以后如果要替换宿主事件、支付网关或 UI 实现，外圈改动对内圈冲击更可控。

### 总体建议

不要做“大爆炸式重构”，但也不要把当前状态误判成“只剩命名优化”。

最正确的节奏是：

1. 先切断 `systems -> flow.intent` 反向依赖；
2. 再删除 `ui_port` 兼容桥；
3. 然后统一输出状态事实源；
4. 最后再做 `src/core` / `src/app` / 目录命名层面的语义整理。

这样既能持续收口架构风险，又不会把整个仓库拖进一次性大搬家。

---

## 7. 最终判断

基于当前工作树，本报告**不再沿用“主体迁移已完成、只剩少量收尾”的判断**。更贴近事实的描述是：

- `game/flow -> presentation` 边界已经明显成形；
- choice 显式协议已经替代了 presentation 的业务猜测；
- 但 `systems -> flow`、`core/game.core -> runtime/ui_port`、以及 UI 输出双轨同步，仍然是结构性问题，而不是纯目录问题。

换句话说，这个仓库已经跨过“完全混杂”的阶段，但还没有跨过“Dependency Rule 真正闭合”的阶段。后续工作的重点不是继续写更多边界文档，而是把仍然存在的几条反向依赖和兼容桥切干净。
