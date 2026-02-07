# Monopoly 全局重构：稳定性彻底修复执行计划（待实施）

本可执行计划是活文档。实施过程中必须持续更新“进度”“意外与发现”“决策日志”“结果与复盘”四个章节。本文件遵循 `/.agents/PLANS.md`，并替代旧的迁移计划作为当前唯一执行入口。

## 目的 / 全局视角

这次工作不是打补丁，而是把 `src/game` 现有运行链做一次“可证明稳定”的全局重构。重构完成后，玩家在长局、快点、多次中断和 UI 延迟输入场景下不再出现硬崩、错结算和状态错位。可见结果是：同一套输入在同一随机种子下得到确定结果，错误输入会被拒绝而不是崩溃，回归测试可覆盖核心状态机、选择系统、UI 事件路由、资产与破产链路。

## 进度

- [x] (2026-02-07 03:41Z) 新任务接管并清空旧 `PLAN_CURRENT.md`，将目标切换为“全局重构彻底修复”。
- [x] (2026-02-07 03:41Z) 复核当前基线：`lua .agents/tests/regression.lua` 通过 36 项。
- [x] (2026-02-07 03:41Z) 完成高风险点审查与分级，确认根因集中在输入时序、choice 分发复制、全局运行时依赖和幂等性缺失。
- [x] (2026-02-07 03:52Z) 新增 `IntentDispatcher` 并替换所有 `_dispatch_intent` 副本。
- [x] (2026-02-07 03:52Z) 扫描确认 `src` 内无 `_dispatch_intent` 副本残留。
- [x] (2026-02-07 03:52Z) 回归通过：`lua .agents/tests/regression.lua` 36 项。
- [x] 里程碑 1：建立统一意图分发层并替换所有 `_dispatch_intent` 副本。
- [x] (2026-02-07 04:04Z) 里程碑 2：TurnDispatch/TurnManager/ChoiceManager 协议重构完成，choice_id 校验与延后清理落地。
- [x] (2026-02-07 04:04Z) 里程碑 3：RuntimeContext 引入并在 init/RuntimeGlobals 中显式注入。
- [x] (2026-02-07 04:04Z) 里程碑 4：UIEventRouter/UIView 软失败处理，去除选项后自动 cancel。
- [x] (2026-02-07 04:04Z) 里程碑 5：Bankruptcy 幂等、Board 确定性、Store path 校验完成。
- [x] (2026-02-07 04:04Z) 里程碑 6：合同测试与聚合入口新增，`lua .agents/tests/all.lua` 全通过。

## 意外与发现

当前仓库的主要稳定性问题不是单点逻辑错误，而是“多处实现同一协议”的系统性漂移。`need_choice` 和 `push_popup` 在 `src/game` 中有多份本地实现，字段默认值和空值保护并不一致，导致同一种意图在不同模块表现不同。

UI 层和领域层之间存在时序耦合：`TurnDispatch` 会先清理本地 UI choice，再把动作交给 `Game:dispatch_action`。在过期动作或并发输入场景下，这种顺序会制造短暂的不一致窗口，给状态错位留出机会。

运行时初始化依赖全局写入，`RuntimeGlobals` 在加载时直接绑定 `GameAPI` 与角色列表。这个模式对启动顺序敏感，对测试环境和重连恢复不友好，也让模块之间形成隐式依赖链。

里程碑 1 实施中发现 `ItemPhase` 的 `_dispatch_intent` 使用了未设默认值的 `choice_seq`，且缺少 choice 字段默认值；统一分发后用统一默认策略消除该漂移点。
 证据：旧实现中 `local seq = game.store:get({ "turn", "choice_seq" })` 无兜底，`title/body_lines/options` 直接透传。

- 观察：非法选项不再清空 pending，需要回归用例改为“保持等待”。
 证据：`lua .agents/tests/regression.lua` 通过 36 项。

## 决策日志

决策：本次允许跨模块、跨目录重构，不以“最小改动”作为约束，优先消除根因。
理由：用户已明确授权全局重构，且问题是结构性漂移，局部补丁会继续累积技术债。
日期/作者：2026-02-07 / Codex。

决策：统一意图分发协议，新增单一入口模块，禁止业务模块自行构造 `pending_choice`。
理由：choice 行为漂移是已确认根因；必须把协议收口到一个可测位置。
日期/作者：2026-02-07 / Codex。

决策：将“输入容错”从断言失败改为软拒绝，断言只用于真正不可恢复的内部不变量。
理由：玩家输入和 UI 回调天然不可靠，崩溃不是可接受策略。
日期/作者：2026-02-07 / Codex。

决策：新增合同测试层，覆盖状态机、意图分发、UI 路由、幂等逻辑和确定性。
理由：现有回归偏玩法路径，缺少协议级约束，无法防止重构回归。
日期/作者：2026-02-07 / Codex。

决策：`IntentDispatcher` 统一采用带默认值的 choice entry 构造策略（标题/列表/取消项），并保留 `TriggerCustomEvent` 触发。
理由：多数模块已有该默认策略；统一后消除字段缺失时的漂移。
日期/作者：2026-02-07 / Codex。

决策：choice UI 清理改为“先校验再提交再清理”，仅在 store pending 变化后关闭 UI。
理由：防止过期或非法输入提前清空 UI，避免状态错位。
日期/作者：2026-02-07 / Codex。

决策：RuntimeContext 安装全局时同步写入 `GameAPI`/`LuaAPI`，以兼容现有模块的全局访问。
理由：现有代码大量依赖全局 API，显式注入仍需提供桥接以便测试替换。
日期/作者：2026-02-07 / Codex。

决策：棋盘兜底选路采用固定方向优先级并排序未知方向。
理由：彻底移除 `pairs` 导致的遍历随机性，保证确定性。
日期/作者：2026-02-07 / Codex。

## 结果与复盘

已完成里程碑 1-6：统一意图分发、choice 协议重构、运行时上下文显式化、UI 事件软失败、幂等与确定性修复、合同测试与聚合入口全部落地。全量测试 `lua .agents/tests/all.lua` 通过。当前无未完成缺口，下一步仅需按需继续扩展合同测试覆盖或进行玩法迭代。

## 背景与导读

当前入口链是 `main.lua -> src/app/init.lua -> src/game/* + src/ui/*`。核心状态机在 `src/game/turn/TurnManager.lua` 与 `src/game/turn/GameplayLoop.lua`，选择处理在 `src/game/choice/ChoiceManager.lua`，输入路由在 `src/ui/UIEventRouter.lua`。运行时桥接由 `src/core/RuntimeGlobals.lua` 提供，它通过全局变量把 Eggy API 暴露给全局作用域。玩家资产、道具、地块和破产分别散布在 `src/game/player`、`src/game/item`、`src/game/land`、`src/game/game`。

本次重构会保留现有玩法语义和外部调用入口，但会重排模块职责。新的目标结构是“协议集中、状态机单向、UI 容错、运行时显式注入、测试合同化”。实现者不需要再决定“是否全局改”；该决策已锁定为必须执行。

## 工作计划

先建立一个统一意图分发层，把 `need_choice` 与 `push_popup` 的构造、默认值、事件触发和存储写入收敛到单模块。然后重写回合分发协议，保证 `choice` 的消费顺序是“先校验再提交再清理”，禁止 UI 本地状态先于领域状态变化。随后抽离运行时上下文，逐步替换 `RuntimeGlobals` 的隐式全局读写，让模块显式依赖上下文对象。完成协议收敛后，再处理领域幂等与路径确定性，最后补上合同测试并把它加入日常回归入口。

## 里程碑设计

### 里程碑 1：统一意图分发协议

本里程碑新增 `src/game/intent/IntentDispatcher.lua`，并在该模块内定义唯一的 `open_choice`、`push_popup`、`dispatch` 三个入口。`src/game/item/ItemPhase.lua`、`src/game/item/ItemInventory.lua`、`src/game/effect/EffectPipeline.lua`、`src/game/turn/TurnMove.lua` 和 `src/game/choice/ChoiceHandlers/*` 全部改为调用该模块，不再保留本地 `_dispatch_intent`。完成标志是仓库内不存在业务私有 `_dispatch_intent`，并且 `choice_seq` 与 `pending_choice` 的写入逻辑只有一个实现点。

### 里程碑 2：重构回合状态机与 choice 消费协议

本里程碑重写 `src/game/turn/TurnDispatch.lua` 与 `src/game/turn/TurnManager.lua` 的动作消费顺序，新增明确的返回语义（成功消费、拒绝、等待）。`choice` 输入必须带 `choice_id` 且与当前 pending 匹配，不匹配时保持原状态并记录警告。`src/game/choice/ChoiceManager.lua` 的非法选项策略改为“拒绝并保持等待”，不再自动清空 pending。完成标志是 stale 输入不会关闭当前 choice，且 UI/Store 不出现先后错位。

### 里程碑 3：运行时上下文显式化

本里程碑新增 `src/core/RuntimeContext.lua`，把 `GameAPI`、`LuaAPI`、事件注册器、角色缓存封装为可注入对象。`src/core/RuntimeGlobals.lua` 保留兼容层，但只从 `RuntimeContext` 读取，不再直接在模块顶层拉取运行时对象。`src/app/init.lua` 在启动时显式创建和传递上下文。完成标志是测试可注入 mock runtime 且不依赖真实全局 API。

### 里程碑 4：UI 事件路由容错化

本里程碑重构 `src/ui/UIEventRouter.lua`、`src/ui/UIView.lua`。所有来自 UI 的回调由“断言失败”改为“条件不满足则忽略并告警”，同时去掉“选项点击后自动派发 cancel”的双动作行为。`UIEventRouter` 只负责意图翻译，不直接做领域状态假设。完成标志是晚到/重复点击不会崩溃，也不会触发额外 cancel。

### 里程碑 5：领域幂等与确定性修复

本里程碑重构 `src/game/game/BankruptcyManager.lua`、`src/game/board/Board.lua`、`src/core/Store.lua` 和相关调用点。`bankruptcy_manager.eliminate` 变为幂等；棋盘兜底选路改为固定方向优先级遍历，去掉 `pairs` 随机性；`Store` 的 path 入参添加契约校验。完成标志是同一输入同一 seed 下路径稳定，重复破产调用不产生重复副作用。

### 里程碑 6：合同测试与门禁

本里程碑新增 `/.agents/tests/contracts/` 目录，创建 `intent_dispatcher.lua`、`turn_choice_protocol.lua`、`ui_router_resilience.lua`、`bankruptcy_idempotent.lua`、`board_determinism.lua`、`runtime_context_boot.lua`。再新增 `/.agents/tests/all.lua`，串联旧回归与合同测试。完成标志是新旧测试可一键执行，并且合同测试覆盖本次重构的全部关键约束。

## 具体步骤

步骤 A 在仓库根目录先建立新模块骨架和最小可运行测试入口。命令为：

    cd /Users/billyq/Dev/Github/Lua/monopoly
    lua .agents/tests/regression.lua

预期先得到当前基线通过，再进入改造。

步骤 B 完成里程碑 1 后执行文本扫描，确认 `_dispatch_intent` 副本已收敛。命令为：

    cd /Users/billyq/Dev/Github/Lua/monopoly
    rg -n "local function _dispatch_intent\\(" src

预期仅允许统一分发模块出现该实现，其他业务模块不应再匹配。

步骤 C 完成里程碑 2 与里程碑 4 后运行回归与新合同测试，确认 stale choice、晚到点击、双动作不会破坏流程。命令为：

    cd /Users/billyq/Dev/Github/Lua/monopoly
    lua .agents/tests/contracts/turn_choice_protocol.lua
    lua .agents/tests/contracts/ui_router_resilience.lua

预期输出应明确标记通过，且不存在断言崩溃。

步骤 D 完成里程碑 3 与里程碑 5 后执行确定性和幂等测试。命令为：

    cd /Users/billyq/Dev/Github/Lua/monopoly
    lua .agents/tests/contracts/runtime_context_boot.lua
    lua .agents/tests/contracts/board_determinism.lua
    lua .agents/tests/contracts/bankruptcy_idempotent.lua

预期同一输入重复执行结果一致，重复破产调用仅首次生效。

步骤 E 全量验收时运行聚合测试入口。命令为：

    cd /Users/billyq/Dev/Github/Lua/monopoly
    lua .agents/tests/all.lua

预期所有测试通过，并包含旧回归 36 项与新合同测试项。

## 验证与验收

验收按行为判断，不按“改了哪些文件”判断。首先，玩家可在高频点击和 UI 延迟场景下持续对局，不出现断言崩溃。其次，choice 协议对过期动作稳定拒绝，`pending_choice` 不被错误清空。再次，破产逻辑幂等、路径选择确定，重复回放结果一致。最后，回归门禁可一键执行并覆盖状态机、意图分发、UI 路由、资产链路四个域。

测试通过门槛固定为：`lua .agents/tests/regression.lua` 继续通过，新增合同测试全部通过，`lua .agents/tests/all.lua` 全通过。若任一失败，任务不得宣告完成。

## 可重复性与恢复

本重构按里程碑推进，每个里程碑单独提交，禁止跨里程碑混改。若某里程碑失败，先回退到上一个通过里程碑，再按该里程碑计划重做，不允许带病进入下一阶段。若运行时上下文改造导致启动失败，临时恢复到兼容层分支并保留日志，再用合同测试逐步收敛。任何时候都必须保证 `lua .agents/tests/regression.lua` 可运行，作为最低恢复锚点。

## 产物与备注

最终产物应包含一个统一意图分发模块、一个显式运行时上下文模块、重构后的回合与 UI 路由实现，以及新的合同测试目录和聚合测试入口。关键证据会在实施时以短终端输出追加在本节，示例如下：

    All regression checks passed (36)
    Contract turn_choice_protocol passed
    Contract ui_router_resilience passed
    Contract board_determinism passed
    Contract bankruptcy_idempotent passed
    All tests passed

本次里程碑 1 证据：

    All regression checks passed (36)

本次全量验收证据：

    All regression checks passed (36)
    Contract intent_dispatcher passed
    Contract turn_choice_protocol passed
    Contract ui_router_resilience passed
    Contract bankruptcy_idempotent passed
    Contract board_determinism passed
    Contract runtime_context_boot passed
    All tests passed

## 接口与依赖

本次重构锁定以下接口，不允许实施者临时改名。统一意图分发模块在 `src/game/intent/IntentDispatcher.lua` 提供：

    IntentDispatcher.dispatch(game, payload, opts) -> result
    IntentDispatcher.open_choice(game, choice_spec, opts) -> choice_entry
    IntentDispatcher.push_popup(game, popup_payload, opts) -> ok

回合分发层在 `src/game/turn/TurnDispatch.lua` 提供：

    turn_dispatch.dispatch_action(game, state, action, opts) -> { status = "applied" | "rejected" | "blocked" }

选择管理层在 `src/game/choice/ChoiceManager.lua` 提供：

    choice_manager.resolve(game, choice, action) -> { status = "resolved" | "rejected" | "waiting", stay = boolean }

运行时上下文在 `src/core/RuntimeContext.lua` 提供：

    RuntimeContext.new(env) -> ctx
    RuntimeContext.set_current(ctx) -> ctx
    RuntimeContext.current() -> ctx | nil
    RuntimeContext.install_globals(ctx) -> nil
    RuntimeContext.refresh_roles(ctx) -> roles

测试依赖继续使用 Lua 运行器，不引入新的外部工具链。配置依赖保持现状，`Config/Generated/*` 只读不改。

## 结果默认值与假设

本计划默认不改变玩法数值与配置语义，只修正执行协议、时序一致性和容错行为。默认保留现有入口 `main.lua -> src/app/init.lua`。默认新增测试脚本统一放在 `/.agents/tests/contracts/`，并由 `/.agents/tests/all.lua` 聚合调用。默认任何模块改造都必须给出回归或合同测试证据。

## 计划变更说明

2026-02-07 03:41Z 本次更新已完全替换旧 `PLAN_CURRENT.md`。变更内容是把任务从“V2 迁移计划”切换为“现行 `src/game` 全局重构彻底修复计划”，并给出已锁定的里程碑、接口、命令、验收与回退策略。变更原因是用户明确授权全局重构，且当前主要风险属于结构性问题，不能再用最小修复策略处理。
2026-02-07 03:52Z 更新里程碑 1 的实施状态与证据，记录统一分发的发现与决策，原因是已完成 `IntentDispatcher` 收敛并通过回归验证。
2026-02-07 04:04Z 更新里程碑 2-6 的实施状态与证据，补充 RuntimeContext、UI 容错、幂等与确定性修复、合同测试与聚合入口，并记录相关决策与发现。
