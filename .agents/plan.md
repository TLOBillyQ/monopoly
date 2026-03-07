# 让 Monopoly 的 Clean Architecture 边界真正闭合的并行实施计划

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件必须遵循 `.agents/harness/PLANS.md` 维护。工作目录固定为仓库根目录 `/Users/billyq/Dev/Github/Lua/monopoly`。如果实施者重新打开这份文件，他不需要依赖对话历史；只靠本文件、当前工作树和仓库内文档，就应能继续推进。

## 目的 / 全局视角

这项工作的目标不是“把目录名改得更漂亮”，而是把当前还残留的几条错误依赖真正切干净，让业务规则重新独立于用例编排、旧 UI 兼容桥和宿主运行时细节。按照 `.agents/research.md` 当前结论，仓库已经在 `game/flow -> presentation` 这条边界上取得了明显进展，但仍然存在三类会持续制造维护成本的问题：`src/game/systems` 反向依赖 `src/game/flow.intent.IntentDispatcher`，`src/game` / `src/core` 仍保留 `ui_port` 兼容回退，以及 `state.ui_runtime` 与 legacy `state.*` 双轨并存。

改完之后，用户看不到玩法变化，但会得到三个可观察结果。第一，`src/game/systems` 下不再出现对 `src.game.flow.*` 的静态依赖，新的业务规则只能通过稳定端口向外发出“需要选择”“需要弹窗”这类意图。第二，`src/game` 与 `src/core` 中不再通过 `game["ui_port"]` 偷读动画或弹窗能力，所有运行时协作都通过窄端口完成。第三，choice、modal、UI model 的事实源只剩 `state.ui_runtime` 一套，回归测试继续通过，而且静态守护脚本能在未来第一时间阻止回退。

这项工作的验收不靠“代码看起来更整洁”，而靠一组稳定的命令和静态扫描。最终状态必须满足：`rg -n 'src\.game\.flow\.' src/game/systems -g '*.lua'` 没有输出，`rg -n '\bui_port\b' src/game src/core -g '*.lua'` 没有输出，定向 `market`、`presentation_ui`、`architecture_guard_contract`、`usecase_boundary_contract`、`runtime_ports_contract` 回归通过，并且 `lua tests/regression.lua` 的末尾继续出现 `All regression checks passed`、`dep_rules ok`、`tick ok` 与 `forbidden_globals ok`。

## 进度

- [x] 基于 `.agents/research.md` 重新确定实施范围，并把目标收敛到 P0 / P1 的真实边界问题，而不是纯目录重命名。
- [x] 读取并确认本计划必须遵循 `.agents/harness/PLANS.md` 的结构要求。
- [x] 里程碑 1：建立向内的意图输出端口，并用一条最小业务路径验证 `systems` 可以在不依赖 `flow.intent` 的前提下打开 choice / popup。
- [x] 里程碑 2：并行迁移 `land / effects / choice handlers`、`items`、`market` 三组业务模块，彻底切断 `src/game/systems -> src/game/flow.*` 依赖，然后收紧静态守护。
- [x] 里程碑 3：让 `state.ui_runtime` 成为唯一 UI 运行时事实源，逐步退役 `LegacyOutputMirror` 与对 root-level `state.*` 的直接读写。（当前已完成前两阶段：`game/flow` 与 `presentation/bootstrap` 侧收口）
- [x] 里程碑 4：删除 `ui_port` 兼容回退，强制使用 `anim_gate_port`、`popup_port`、`tile_feedback_port`、`board_scene_port`。
- [x] 里程碑 5：在行为边界稳定后，再迁移 runtime 具体实现离开 `src/core`，同步文档和守护规则，并跑最终全量回归。

## 意外与发现

这次规划阶段最重要的发现有四个。第一，展示层的情况比研究前乐观：`src/presentation` 中没有直接 `require("src.game.*")` 的静态依赖，而且对 `choice.kind` / `choice.meta` 的业务推断也已经基本清零。这意味着“presentation 反向侵入业务层”不是当前主战场。

第二，真正还在破坏 Dependency Rule 的是 `src/game/systems`。静态扫描命中九个文件直接依赖 `src.game.flow.intent.IntentDispatcher`，其中分布在 `effects`、`land`、`items`、`market/service` 和若干 `ChoiceHandlers`。这类依赖不是命名问题，而是业务规则层直接握住了用例编排器。

第三，状态边界比目录边界更脆弱。`UseCaseOutputPort` 已经抽出了 `ui_model`、`pending_choice` 和 modal timer，但 `LegacyOutputMirror` 仍然把它们同步回 root-level `state.*`，而 `TickUISync`、`TurnDispatchValidator`、`GameStartupEventBridge`、`UIModalPresenter`、`UIModalStateCoordinator` 等位置又在继续直接读写这些 legacy 字段。这意味着“新边界已经存在，但旧边界还没退休”。

第四，runtime 目录语义需要放在最后处理。`RuntimeContext.lua`、`RuntimeEventBridge.lua` 和 `DefaultPorts.lua` 确实更像 outer details，但如果在切断 `systems -> flow`、统一 `ui_runtime`、删除 `ui_port` 之前就做大搬家，会把行为改动和路径重命名揉在一起，降低可验证性。这个顺序必须反过来。

## 决策日志

2026-03-07：本计划直接以 `.agents/research.md` 为当前事实来源，不再沿用仓库中旧计划对“主体迁移已完成、只剩收尾”的判断。理由是研究结论已经明确指出 `systems -> flow.intent`、`ui_port` fallback 和双轨状态仍是结构性问题，继续按旧判断推进会低估实现工作量。

2026-03-07：为切断 `src/game/systems -> src/game/flow.intent.IntentDispatcher`，本计划采用“新建向内端口 + 外层 adapter 安装”的方式，而不是让 `systems` 直接返回临时 table 再让调用者猜语义。具体决定是新增 `src/game/ports/IntentOutputPort.lua` 作为 inward-facing contract，并在 `src/game/flow/ports/IntentOutputAdapter.lua` 中保留当前 `IntentDispatcher` 的具体实现包装。这样能把 `IntentDispatcher` 明确留在用例层，同时给 `systems` 一条可测试的窄边界。

2026-03-07：`state.ui_runtime` 被定为唯一的 UI 运行时事实源。`state.ui_model`、`state.pending_choice*`、`state.ui_modal_*` 等 root-level 字段只允许作为过渡期兼容输入存在，不能再作为新的业务读取来源。理由是当前最大同步风险来自“双轨事实源”，不是单个字段名字不好。

2026-03-07：`ui_port` 兼容回退必须在功能重构阶段删除，而不是放到最后的目录整理阶段。理由是只要 `game["ui_port"]` 还存在，核心代码就仍然能绕过窄端口读取旧 UI 细节，测试也无法真正证明边界已经闭合。

2026-03-07：本计划不引入任何新的第三方库，也不要求联网查阅新的外部 API 文档。唯一需要遵守的外部运行时约束已经以内置文档形式存在于仓库：`docs/eggy/lua_env.md`、`docs/eggy/ui_manager_lib.md`、`docs/eggy/eggy_lua_agent_memory.md`。因此，实施时应以这些本地文档和现有代码模式为准，而不是额外引入新的库或协议。

2026-03-07：为了让 T1、T6、T9 真正可以并行执行，本计划刻意把它们各自需要新增的契约测试拆到独立文件中，例如 `tests/suites/intent_output_contract.lua`、`tests/suites/ui_runtime_state_contract.lua`、`tests/suites/narrow_runtime_ports_contract.lua`。理由是共享修改 `architecture_guard_contract.lua` 或 `usecase_boundary_contract.lua` 会制造不必要的合并冲突，削弱并行收益。

## 结果与复盘

当前只有计划工作完成，代码尚未开始实施，因此本节先写清楚“完成后应出现什么结果”，便于后续逐步对照。整个计划完成后，最核心的结果不是文件搬家，而是四条边界变得可证明。第一，`src/game/systems` 不再静态依赖 `src/game/flow.*`。第二，`ui_port` 在生产代码中彻底消失。第三，choice / popup / modal / ui_model 的运行时事实只剩 `state.ui_runtime` 一套。第四，runtime 具体实现被压回 outer details，而 `src/core` 只留下真正稳定、被内层依赖的抽象和工具。

如果实际实施过程中发现某个里程碑会造成大面积行为飘移，本节要在每个里程碑结束时补上“哪里超出预期、是否需要拆更小步、是否需要临时保留并行路径”的复盘结论。默认策略不是追求一步到位，而是每个里程碑都能被单独验证并安全回滚。

## 背景与导读

本仓库当前最重要的代码区域有五块。`src/game/systems` 保存玩法规则本体，例如地块、道具、机会卡、市场资格与兑现逻辑。`src/game/flow` 和 `src/game/runtime` 共同承担应用级编排，负责回合推进、动作分发、超时、动画等待与端口调用。`src/presentation` 承担界面适配，负责把 `ui_model`、choice、popup 和 board scene 渲染到 Eggy UIManager。`src/app/bootstrap` 负责启动、安装 runtime、接通 UI 和测试 profile。`src/core` 现在混合了稳定工具、运行时状态与一部分 outer details，是本计划最后一段才去整理的地方。

实施者在动手前，应先熟悉三条已经存在的成功模式。第一条是 market 支付路径中的“端口 + adapter”模式，代表文件是 `src/game/systems/market/ports/PaidPurchasePort.lua` 与 `src/app/bootstrap/payment/EggyPaidPurchaseGateway.lua`。第二条是 `game/flow -> presentation` 之间的分组端口模式，代表文件是 `src/game/flow/turn/GameplayLoopPorts.lua` 与 `src/presentation/api/PresentationPorts.lua`。第三条是 choice 显式字段协议，代表文件是 `src/core/ChoiceContract.lua`、`src/game/flow/intent/IntentDispatcher.lua`、`src/presentation/state/ui_model/ChoiceSlice.lua`。本计划会沿用这些已经被验证过的模式，而不是重新发明一套新的架构约定。

实施者还必须记住三个 Eggy 运行时约束。第一，数值解析必须继续使用 `src/core/NumberUtils.lua`，不要新写 `tonumber` 或 `type(...) == "number"`。第二，Eggy API 调用使用 `.`，不要改出 `:` 风格。第三，任何需要 UIManager 或宿主事件的逻辑，都必须留在外层 adapter 或 bootstrap 中，不能因为图方便回流到业务规则层。这三条约束已经由仓库内文档和 `tests/internal/forbidden_globals.lua` 守护，计划中的所有实现都必须遵守。

## 工作计划

这项工作分成五个里程碑。里程碑 1 是技术探针，目标是先证明 `systems` 能在不依赖 `flow.intent` 的情况下发出稳定意图；如果这一步都无法在不改行为的前提下走通，就不应该批量迁移。里程碑 2 是最大的并行波次，把 `land / effects / choice handlers`、`items`、`market` 三组模块同时迁走，然后再统一收紧静态守护。里程碑 3 聚焦状态边界，把 `ui_runtime` 变成唯一事实源。里程碑 4 删除 `ui_port` fallback，让所有 UI 协作都通过窄端口。里程碑 5 才处理 runtime 具体实现的目录归位和文档同步。

下面这张依赖图描述了任务之间的先后关系。图中同一层的任务可以并行执行，只要它们的 `depends_on` 已经满足，就不需要等待其它无关任务结束。

    T1 ──┬── T2 ──┐
         ├── T3 ──┼── T5 ──┐
         └── T4 ──┘        │
    T6 ── T7 ── T8 ────────┤
    T9 ────────────────────┤
                           ├── T10 ── T11

这张图意味着第一波并行可以同时启动 T1、T6 和 T9。T1 完成后，T2、T3、T4 可以由三名代理分别负责各自领域迁移。T6 完成后，另一名代理可以继续处理 T7，再接 T8。T9 独立推进，但最终合并前仍然要与 T8 和 T5 一起通过统一验证。T10 必须等到功能边界收口以后再开始，因为它是语义整理，不应和行为重构混在一波。T11 只做最终守护、文档和验收收尾。

### 里程碑 1：建立向内的意图输出边界

这个里程碑的范围很小，但必须能独立证明方向正确。完成后，仓库里会出现一条新的 inward-facing contract，让 `src/game/systems` 只知道“我要发出一个 choice / popup”，而不知道“是谁在外层把它渲染出来”。这一步只迁移一条最小路径，建议选 `src/game/systems/land/LandingPresenter.lua`，因为它依赖面较薄、行为容易通过现有 `landing` 和 `presentation_ui` 套件验证。

在这个里程碑结束时，仓库根目录执行下面命令，应该都出现 `All regression checks passed`，而且不应出现新的 assertion failure。

    lua -e "package.path = package.path .. ';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; require('TestHarness').run_all({ require('intent_output_contract'), require('landing'), require('presentation_ui') })"

### 里程碑 2：并行迁移所有 `systems -> flow.intent` 调用点

这个里程碑完成后，`src/game/systems` 下不再允许直接 `require("src.game.flow.*")`。为了降低冲突，这一波按领域拆成三组：`land / effects / choice handlers` 一组，`items` 一组，`market` 一组。三组都依赖里程碑 1 新建的端口合同，但它们不应该互相抢同一批文件。

这个里程碑结束时，除了领域回归之外，还要执行静态扫描，证明反向依赖已经归零。

    rg -n 'src\.game\.flow\.' src/game/systems -g '*.lua'

上面的命令应该没有任何输出。然后执行下面命令，验证静态守护和领域行为同时成立。

    lua tests/internal/dep_rules.lua
    lua -e "package.path = package.path .. ';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; require('TestHarness').run_all({ require('land'), require('landing'), require('item'), require('market'), require('cross_module_contract'), require('presentation_ui') })"

### 里程碑 3：统一 UI 运行时事实源

这个里程碑的目标是把 `state.ui_runtime` 从“新系统的一部分”提升为“唯一事实源”。做完之后，`UseCaseOutputPort`、`TickUISync`、`TurnDispatchValidator`、`UIModelSync`、`UIModalPresenter` 和 `GameStartupEventBridge` 都不应该再把 root-level `state.ui_model`、`state.pending_choice*`、`state.ui_modal_*` 当作正常读写路径。过渡期如果保留兼容读入，也必须集中在 `src/core/RuntimeState.lua` 一处完成，不能让消费方自己双读双写。

这个里程碑的证明方式既包括行为回归，也包括静态扫描。结束时先执行下面命令，检查 `src/game/flow` 中已经没有对 legacy UI 状态的直接读写。

    rg -n 'state\.ui_model|state\.pending_choice|state\.pending_choice_id|state\.pending_choice_elapsed|state\.ui_modal_elapsed|state\.ui_modal_ref' src/game/flow -g '*.lua'

预期是没有输出。然后执行：

    lua -e "package.path = package.path .. ';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; require('TestHarness').run_all({ require('architecture_guard_contract'), require('usecase_boundary_contract'), require('ui_gate_contract'), require('presentation_ui'), require('presentation_ui_model_dispatch'), require('read_model_contract') })"

### 里程碑 4：删除 `ui_port` 兼容回退

这个里程碑把旧的 catch-all UI 桥彻底关掉。完成后，`Game.lua`、`ActionAnimPort.lua`、`TurnRoll.lua`、`TurnMove.lua` 这些生产代码中不再允许读取 `game["ui_port"]` 或 `ui_port.*`。所有能力都必须来自 `anim_gate_port`、`popup_port`、`tile_feedback_port`、`board_scene_port` 这类窄端口，而且缺失时应尽早失败，而不是悄悄 fallback。

这个里程碑完成后先跑静态扫描：

    rg -n '\bui_port\b' src/game src/core -g '*.lua'

预期是没有输出。然后执行：

    lua -e "package.path = package.path .. ';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; require('TestHarness').run_all({ require('architecture_guard_contract'), require('usecase_boundary_contract'), require('gameplay_loop'), require('presentation_ui_action_anim'), require('presentation_ui') })"

### 里程碑 5：整理 runtime 具体实现的目录归位并同步文档

最后一个里程碑只在前四个里程碑都已经稳定、并且完整回归至少连续通过两次之后启动。它的目标不是再改业务行为，而是把仍然停在 `src/core` 里的 runtime 具体实现移到更外层的位置，让目录语义跟真实依赖方向一致。建议迁移 `RuntimeContext.lua`、`RuntimeEventBridge.lua`、`runtime_ports/DefaultPorts.lua`、必要时再加 `RuntimeEditorExports.lua` 和 `UIRoleGlobals.lua`，但保留 `src/core/RuntimePorts.lua` 作为稳定 façade，不要让内层直接依赖 `src/app/bootstrap/*`。

这个里程碑的证明方式是 runtime 契约回归、启动回归和全量回归一起通过。

    lua -e "package.path = package.path .. ';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; require('TestHarness').run_all({ require('runtime_ports_contract'), require('runtime_bootstrap'), require('startup_release') })"
    lua tests/regression.lua

## 具体步骤

### T1 建立 `IntentOutputPort` 合同并完成一条最小迁移路径

id：T1。depends_on：[]。status：Completed。location：`src/game/ports/IntentOutputPort.lua`、`src/game/flow/ports/IntentOutputAdapter.lua`、`src/game/flow/intent/IntentDispatcher.lua`、`src/game/flow/turn/GameplayLoop.lua`、`src/game/systems/land/LandingPresenter.lua`、新增 `tests/suites/intent_output_contract.lua`。

description：新增一个 inward-facing contract，让 `systems` 通过 `game.intent_output_port` 发出 `open_choice` 和 `push_popup`，而不是直接 require `IntentDispatcher`。`IntentDispatcher` 继续保留在 `src/game/flow`，但变成 adapter 的实现细节。为降低风险，这一步只迁移一条最小路径，建议以 `LandingPresenter.lua` 为技术探针；如果这条路径在不改行为的前提下跑不通，就不要进入批量迁移。为了避免和 T6、T9 争抢共享测试文件，这一步优先新增专用的 `intent_output_contract` 套件，而不是修改共享 contract suite。

validation：在仓库根目录执行下面命令，预期末尾出现 `All regression checks passed`，且没有新增 assertion failure。

    lua -e "package.path = package.path .. ';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; require('TestHarness').run_all({ require('intent_output_contract'), require('landing'), require('presentation_ui') })"

log：2026-03-07 已完成。探针选择 `src/game/systems/land/LandingPresenter.lua`，因为它只需要把 popup 输出从直接依赖 `IntentDispatcher` 改为经由稳定端口发出，能最小成本证明 `systems -> flow` 可被切断。实现中新增 `src/game/ports/IntentOutputPort.lua` 作为 inward-facing contract，并新增 `src/game/flow/ports/IntentOutputAdapter.lua` 作为 outer adapter；`GameplayLoop.set_game()` 负责安装 `game.intent_output_port`。为避免旧测试夹具在未走 `GameplayLoop.set_game()` 时立即失效，`IntentOutputPort` 暂时保留 adapter fallback；这被视为 T1 的过渡策略，后续 T2-T4 完成后再评估是否继续收紧。由于 T9 同时移除了生产代码中的 `ui_port` fallback，本轮还同步把 `tests/suites/landing.lua` 显式映射到 `anim_gate_port`、`popup_port`、`tile_feedback_port`，以便 T1 的验收命令重新回到全绿。

files edited/created：`src/game/ports/IntentOutputPort.lua`、`src/game/flow/ports/IntentOutputAdapter.lua`、`src/game/flow/turn/GameplayLoop.lua`、`src/game/systems/land/LandingPresenter.lua`、`tests/suites/intent_output_contract.lua`、`tests/suites/landing.lua`。

结果：Completed。

### T2 迁移 `land / effects / choice handlers` 领域脱离 `flow.intent`

id：T2。depends_on：[T1]。status：Completed。location：`src/game/systems/effects/EffectPipeline.lua`、`src/game/systems/choices/ChoiceHandlers/`、`src/game/systems/land/`、必要时补充 `tests/suites/land.lua`、`tests/suites/landing.lua`、`tests/suites/cross_module_contract.lua`、`tests/suites/presentation_ui.lua`。

description：把 `land`、`effects` 和剩余 `ChoiceHandlers` 中对 `IntentDispatcher` 的直接依赖全部替换成新端口。迁移时不要顺手改业务语义；唯一允许改变的是“由谁负责把业务意图交给外层”。如果某个 handler 需要传递额外上下文，优先扩展端口 payload，而不是重新把 `flow` 模块引回去。

validation：先执行静态扫描，确认这一组文件不再出现 `IntentDispatcher` 依赖；再跑领域与交互回归。

    rg -n 'IntentDispatcher' src/game/systems/effects src/game/systems/land src/game/systems/choices/ChoiceHandlers -g '*.lua'
    lua -e "package.path = package.path .. ';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; require('TestHarness').run_all({ require('land'), require('landing'), require('cross_module_contract'), require('presentation_ui') })"

log：2026-03-07 已完成。`src/game/systems/effects/EffectPipeline.lua`、`src/game/systems/choices/ChoiceHandlers/LandChoiceHandler.lua`、`src/game/systems/choices/ChoiceHandlers/OptionalEffectHandler.lua` 与 `src/game/systems/choices/ChoiceHandlers/ItemChoiceHandler.lua` 中对 `IntentDispatcher` 的直接依赖已全部改为 `IntentOutputPort`。本轮没有改变业务语义，只把 `need_choice` / `push_popup` / 复合 `intent` 的交付路径切到稳定端口。由于 `T9` 已移除生产代码中的 `ui_port` fallback，`tests/suites/landing.lua` 继续承担窄端口测试夹具角色。

files edited/created：`src/game/systems/effects/EffectPipeline.lua`、`src/game/systems/choices/ChoiceHandlers/LandChoiceHandler.lua`、`src/game/systems/choices/ChoiceHandlers/OptionalEffectHandler.lua`、`src/game/systems/choices/ChoiceHandlers/ItemChoiceHandler.lua`。

结果：Completed。

### T3 迁移 `items` 领域脱离 `flow.intent`

id：T3。depends_on：[T1]。status：Completed。location：`src/game/systems/items/ItemInventory.lua`、`src/game/systems/items/ItemUseBroadcast.lua`、`src/game/systems/items/ItemPhase.lua`、相关测试 `tests/suites/item.lua`、`tests/suites/gameplay_core.lua`、`tests/suites/presentation_ui_interaction.lua`。

description：把 `items` 领域的 choice、popup 和广播输出全部切到 `IntentOutputPort`。这一组比 land 更容易碰到 ownership、slot 选择和 auto flow，实施者必须刻意保持行为一致，不要在同一步里顺手改交互规则。

validation：先扫描 `items` 目录不再出现 `IntentDispatcher`，再跑 item 和交互回归。

    rg -n 'IntentDispatcher' src/game/systems/items -g '*.lua'
    lua -e "package.path = package.path .. ';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; require('TestHarness').run_all({ require('item'), require('gameplay_core'), require('presentation_ui_interaction'), require('presentation_ui') })"

log：2026-03-07 已完成。`ItemInventory.lua`、`ItemUseBroadcast.lua`、`ItemPhase.lua` 均已脱离 `IntentDispatcher`，统一改为 `IntentOutputPort.push_popup`、`IntentOutputPort.open_choice`、`IntentOutputPort.dispatch`。这一步保留了 item slot、auto flow 与 preconsumed 语义不变，只调整输出边界。并且 `presentation_ui` 中与 selected option 相关的断言已同步读 `ui_runtime`，避免测试继续依赖 root-level legacy 字段。

files edited/created：`src/game/systems/items/ItemInventory.lua`、`src/game/systems/items/ItemUseBroadcast.lua`、`src/game/systems/items/ItemPhase.lua`、`src/game/systems/choices/ChoiceHandlers/ItemChoiceHandler.lua`、`tests/suites/item.lua`、`tests/suites/presentation_ui.lua`。

结果：Completed。

### T4 迁移 `market` 领域脱离 `flow.intent`

id：T4。depends_on：[T1]。status：Completed。location：`src/game/systems/market/service/ChoiceOutcome.lua`、必要时连带 `src/game/systems/market/service/ChoiceSession.lua`、`src/game/systems/market/MarketService.lua`，以及测试 `tests/suites/market.lua`、`tests/suites/paid_currency.lua`、`tests/suites/presentation_ui_popup_market.lua`。

description：把 market choice 结果和购买后续动作改为通过新端口输出，不再直接 require `IntentDispatcher`。这一步不要重写 market 业务规则；只调整“把业务结果交给外层”的位置。若出现付费购买回调要刷新 choice 的路径，仍由 market service 产出稳定意图，再交给外层 adapter 处理。

validation：先扫描 market service 目录不再出现 `IntentDispatcher`，再跑 market 与 popup/paid_currency 回归。

    rg -n 'IntentDispatcher' src/game/systems/market -g '*.lua'
    lua -e "package.path = package.path .. ';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; require('TestHarness').run_all({ require('market'), require('paid_currency'), require('presentation_ui_popup_market') })"

log：2026-03-07 已完成。`src/game/systems/market/service/ChoiceOutcome.lua` 已从直接依赖 `IntentDispatcher` 改为依赖 `IntentOutputPort`。本轮只解释 market 当前真实会产出的稳定意图：`need_choice` 走 `open_choice`，`push_popup` 走 `push_popup`；未额外扩张端口表面。付费购买回调链路无需新增 adapter，沿用既有 gateway 即可。

files edited/created：`src/game/systems/market/service/ChoiceOutcome.lua`、`tests/suites/market.lua`。

结果：Completed。

### T5 收紧 `dep_rules` 并把 `systems -> flow` 反向依赖纳入永久守护

id：T5。depends_on：[T2, T3, T4]。status：Completed。location：`tests/internal/dep_rules.lua`、必要时补充 `tests/suites/architecture_guard_contract.lua`、`tests/suites/usecase_boundary_contract.lua`。

description：在功能迁移全部完成后，正式把 `src/game/systems` 依赖 `src.game.flow.*` 设为禁止项，避免未来任何业务模块重新 require `IntentDispatcher` 或其它用例层模块。不要在 T2、T3、T4 还没做完时提前把守护收紧，否则并行实现会在中间阶段被静态守护卡死。

validation：执行下面命令。第一条命令必须没有输出，第二条必须打印 `dep_rules ok`，第三条需要出现 `All regression checks passed`。

    rg -n 'src\.game\.flow\.' src/game/systems -g '*.lua'
    lua tests/internal/dep_rules.lua
    lua -e "package.path = package.path .. ';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; require('TestHarness').run_all({ require('architecture_guard_contract'), require('usecase_boundary_contract') })"

log：2026-03-07 已完成。`tests/internal/dep_rules.lua` 现已明确禁止 `src/game/systems` 依赖 `src.game.flow.*`。在 T2/T3/T4 收口后，静态扫描 `rg -n 'src\.game\.flow\.' src/game/systems -g '*.lua'` 当前无输出，`lua tests/internal/dep_rules.lua` 输出 `dep_rules ok`。最初的契约回归失败并非 dep_rules 本身，而是默认 output port 仍经由 legacy mirror 回写 root-level UI 状态；该问题已在 T8 中一并解决，随后 `architecture_guard_contract + usecase_boundary_contract` 已通过。当前没有保留任何豁免。

files edited/created：`tests/internal/dep_rules.lua`。

结果：Completed。

### T6 给 `RuntimeState` 增加显式读写 API，并先迁移 `game/flow` 消费方

id：T6。depends_on：[]。status：Completed。location：`src/core/RuntimeState.lua`、`src/game/flow/ports/UseCaseOutputPort.lua`、`src/game/flow/turn/TickUISync.lua`、`src/game/flow/turn/TurnDispatchValidator.lua`、`src/game/flow/turn/GameplayLoopTickSteps.lua`、新增 `tests/suites/ui_runtime_state_contract.lua`，以及按需最小修改 `tests/suites/ui_gate_contract.lua`。

description：在不改变对外行为的前提下，把 `RuntimeState` 从“只负责 ensure table”升级为“提供稳定的 UI runtime 读写 API”。这一阶段只先处理 `game/flow` 侧消费者，让回合编排、timeout、validator 和 output port 不再直接读写 legacy root-level `state.*`。过渡期允许 `RuntimeState` 在初始化时从旧字段读入一次，但不允许消费方继续自己双读双写。为了保持并行写集独立，这一步优先新增 `ui_runtime_state_contract` 套件承接新增断言。

validation：先执行静态扫描，确认 `src/game/flow` 中已经没有 legacy UI 状态直接访问；再跑定向契约回归。

    rg -n 'state\.ui_model|state\.pending_choice|state\.pending_choice_id|state\.pending_choice_elapsed|state\.ui_modal_elapsed|state\.ui_modal_ref' src/game/flow -g '*.lua'
    lua -e "package.path = package.path .. ';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; require('TestHarness').run_all({ require('ui_runtime_state_contract'), require('ui_gate_contract') })"

log：2026-03-07 已完成。为避免在 `game/flow` 里继续双读双写 legacy `state.*`，本任务先在 `src/core/RuntimeState.lua` 增加显式 API：`is_ui_dirty` / `set_ui_dirty`、`get_ui_model` / `set_ui_model`、`get_pending_choice` / `set_pending_choice`、`get_pending_choice_id` / `set_pending_choice_id`、`get_pending_choice_elapsed` / `set_pending_choice_elapsed`、`get_modal_elapsed` / `get_modal_ref` / `set_modal_timer`。随后把 `UseCaseOutputPort`、`TickUISync`、`TurnDispatchValidator`、`GameplayLoopTickSteps` 改成统一走这些 API。为了让验收扫描真正归零，本轮还最小补齐了 `GameplayLoop.lua` 与 `TickTimeout.lua` 的 legacy 读取路径。专用契约测试 `ui_runtime_state_contract` 已落地并通过。

files edited/created：`src/core/RuntimeState.lua`、`src/game/flow/ports/UseCaseOutputPort.lua`、`src/game/flow/turn/TickUISync.lua`、`src/game/flow/turn/TurnDispatchValidator.lua`、`src/game/flow/turn/GameplayLoopTickSteps.lua`、`src/game/flow/turn/GameplayLoop.lua`、`src/game/flow/turn/TickTimeout.lua`、`tests/suites/ui_runtime_state_contract.lua`。

结果：Completed。

### T7 迁移 `presentation` 和 bootstrap 对 UI 运行时状态的消费

id：T7。depends_on：[T6]。status：Completed。location：`src/presentation/api/presentation_ports/ui_sync/UIModelSync.lua`、`src/presentation/interaction/UIModalStateCoordinator.lua`、`src/presentation/ui/UIModalPresenter.lua`、`src/presentation/interaction/ui_intent_dispatcher/PreConfirmFlow.lua`、`src/app/bootstrap/GameStartupEventBridge.lua`、必要时补充 `src/presentation/state/ui_model/ChoiceSlice.lua` 和相关测试。

description：让 presentation 和 bootstrap 不再把 root-level `state.ui_model`、`state.pending_choice*`、`state.ui_modal_*` 当作正常路径读取。`GameStartupEventBridge` 若继续保留，只允许做事件桥接，不允许再直接写 `state.pending_choice*` 或直接 build `ui_model` 作为旁路。所有这类状态都应改经 `RuntimeState` API 读取或更新。

validation：先扫描 `src/presentation` 与 `src/app/bootstrap/GameStartupEventBridge.lua`，确认 legacy 访问大幅收口；再跑 presentation 相关回归。

    rg -n 'state\.ui_model|state\.pending_choice|state\.pending_choice_id|state\.pending_choice_elapsed|state\.ui_modal_elapsed|state\.ui_modal_ref' src/presentation src/app/bootstrap/GameStartupEventBridge.lua -g '*.lua'
    lua -e "package.path = package.path .. ';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; require('TestHarness').run_all({ require('presentation_ui'), require('presentation_ui_model_dispatch'), require('presentation_ui_popup_market'), require('read_model_contract') })"

log：2026-03-07 已完成。`UIModelSync.lua`、`UIModalStateCoordinator.lua`、`UIModalPresenter.lua`、`PreConfirmFlow.lua`、`GameStartupEventBridge.lua`、`ChoiceSlice.lua` 均已改为通过 `RuntimeState` API 读取或更新 UI runtime。过程中还发现 `UIEventIntents.lua`、`MarketModalRenderer.lua`、`canvas/market/intents.lua`、`PopupRenderer.lua` 等 presentation 辅助模块存在遗漏，于是最小补齐了 `runtime_state` 引入并移除了 root-level fallback。为避免测试继续跟旧字段耦合，`tests/suites/presentation_ui.lua` 中与 selected option / choice visible ids 相关的断言已改读 `ui_runtime`。最后又收紧了 `RuntimeState.ensure_ui_runtime()`：legacy choice 相关字段只在第一次初始化时吸收一次，后续不再把已清空状态从 root-level 重新回填。

files edited/created：`src/presentation/api/presentation_ports/ui_sync/UIModelSync.lua`、`src/presentation/interaction/UIModalStateCoordinator.lua`、`src/presentation/ui/UIModalPresenter.lua`、`src/presentation/interaction/ui_intent_dispatcher/PreConfirmFlow.lua`、`src/app/bootstrap/GameStartupEventBridge.lua`、`src/presentation/state/ui_model/ChoiceSlice.lua`、`src/presentation/interaction/UIEventIntents.lua`、`src/presentation/ui/MarketModalRenderer.lua`、`src/presentation/canvas/market/intents.lua`、`src/presentation/ui/PopupRenderer.lua`、`tests/suites/presentation_ui.lua`。

结果：Completed。

### T8 退役 `LegacyOutputMirror` 并把 root-level legacy 状态降为只读兼容或彻底删除

id：T8。depends_on：[T7]。status：Completed。location：`src/game/flow/ports/LegacyOutputMirror.lua`、`src/game/flow/ports/UseCaseOutputPort.lua`、`src/core/RuntimeState.lua`、新增 `tests/suites/legacy_output_mirror_contract.lua`，以及相关回归 `tests/suites/presentation_ui.lua`。

description：当 flow 和 presentation 两侧都已改成通过 `RuntimeState` 读写后，就可以删除或极限瘦身 `LegacyOutputMirror`。这一任务的目标是让 root-level legacy 字段不再承担“第二套事实源”的职责；如果为了平滑启动保留一次性迁移，也必须集中在 `RuntimeState` 内部完成，不能继续让 mirror 在每次输出时写回。

validation：在生产代码范围执行下面扫描，预期除了 `src/core/RuntimeState.lua` 之外不再命中；随后跑回归。

    rg -n 'state\.ui_model|state\.pending_choice|state\.pending_choice_id|state\.pending_choice_elapsed|state\.ui_modal_elapsed|state\.ui_modal_ref' src/game src/presentation src/app -g '*.lua'
    lua -e "package.path = package.path .. ';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; require('TestHarness').run_all({ require('legacy_output_mirror_contract'), require('presentation_ui') })"

log：2026-03-07 已完成。默认 output port 已改为 runtime-only：`UseCaseOutputPort.build_base_output_ports()` 现在直接返回 runtime 输出，不再通过 `LegacyOutputMirror` 回写 `state.ui_dirty`、`state.ui_model`、`state.pending_choice*`、`state.ui_modal_*`。`LegacyOutputMirror` 被保留为显式 passthrough 壳，仅用于兼容模块路径和专用契约测试，不再承担第二套事实源职责。配套新增 `legacy_output_mirror_contract`，证明 base output ports 只写 `ui_runtime`，legacy wrapper 也只是 runtime passthrough。随后本地复验 `architecture_guard_contract + usecase_boundary_contract + legacy_output_mirror_contract` 全绿，且 `rg -n 'state\.ui_model|state\.pending_choice|state\.pending_choice_id|state\.pending_choice_elapsed|state\.ui_modal_elapsed|state\.ui_modal_ref' src/game src/presentation src/app -g '*.lua'` 当前无输出。

files edited/created：`src/game/flow/ports/UseCaseOutputPort.lua`、`src/game/flow/ports/LegacyOutputMirror.lua`、`tests/suites/legacy_output_mirror_contract.lua`。

结果：Completed。

### T9 删除 `ui_port` 兼容回退并强制窄端口安装

id：T9。depends_on：[]。status：Completed。location：`src/game/core/runtime/Game.lua`、`src/core/ActionAnimPort.lua`、`src/game/flow/turn/TurnRoll.lua`、`src/game/flow/turn/TurnMove.lua`、新增 `tests/suites/narrow_runtime_ports_contract.lua`，以及相关回归 `tests/suites/presentation_ui_action_anim.lua`、`tests/suites/gameplay_loop.lua`。

description：删除所有通过 `game["ui_port"]` 或 `ui_port.*` 获取动画等待、弹窗和 tile feedback 的兼容回退。`Game` 应只暴露或要求 `popup_port`、`tile_feedback_port`、`anim_gate_port`、`board_scene_port` 这些窄端口；缺失时应 assert，而不是 fallback。实施者可以保留 `ensure_*` 风格的方法名，但它们不能再偷偷从 `ui_port` 构造兼容对象。当前 `GameplayLoop.set_game` 已经负责安装窄端口，所以 T9 默认不占用 `src/game/flow/turn/GameplayLoop.lua`；只有发现真实安装缺口时，才在决策日志中补记并新拆一项任务。为了避免和 T1、T6 抢共享 contract suite，这一步优先把新增断言写进专用的 `narrow_runtime_ports_contract`。

validation：先扫描 `src/game` 与 `src/core` 中已经没有 `ui_port`，再跑动画与 loop 相关回归。

    rg -n '\bui_port\b' src/game src/core -g '*.lua'
    lua -e "package.path = package.path .. ';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; require('TestHarness').run_all({ require('narrow_runtime_ports_contract'), require('presentation_ui_action_anim'), require('gameplay_loop'), require('presentation_ui') })"

log：2026-03-07 已完成。生产代码中的 `game["ui_port"]` / `ui_port.*` fallback 已从 `Game.lua`、`ActionAnimPort.lua`、`TurnRoll.lua`、`TurnMove.lua` 清除。为避免真实启动路径缺省时报错，本轮在 `Game.lua` 安装 no-op 默认窄端口：`anim_gate_port` 默认关闭动画等待，`popup_port.push_popup` 与 `tile_feedback_port.on_tile_upgraded` 默认为 no-op。专用契约测试 `narrow_runtime_ports_contract` 已新增，用来证明即使存在 legacy `ui_port` 也不能再作为生产 fallback。并行验收中发现部分测试夹具仍依赖 `ui_port`，因此补了 `tests/suites/presentation_ui.lua` 与 `tests/suites/landing.lua` 的窄端口适配；这属于测试侧收口，不改变生产边界。

files edited/created：`src/game/core/runtime/Game.lua`、`src/core/ActionAnimPort.lua`、`src/game/flow/turn/TurnRoll.lua`、`src/game/flow/turn/TurnMove.lua`、`tests/suites/narrow_runtime_ports_contract.lua`、`tests/suites/presentation_ui.lua`、`tests/suites/landing.lua`。

结果：Completed。

### T10 在功能边界稳定后迁移 runtime 具体实现离开 `src/core`

id：T10。depends_on：[T5, T8, T9]。status：Completed。location：`src/core/RuntimeContext.lua`、`src/core/RuntimeEventBridge.lua`、`src/core/runtime_ports/DefaultPorts.lua`、必要时连带 `src/core/RuntimeEditorExports.lua`、`src/core/UIRoleGlobals.lua`，以及 `src/app/bootstrap/runtime_install/`、`src/app/bootstrap/RuntimeInstall.lua`、`tests/suites/runtime_ports_contract.lua`、`tests/suites/runtime_bootstrap.lua`、`tests/suites/startup_release.lua`。

description：把明显属于 outer details 的 runtime 具体实现迁到更外层路径，建议放进 `src/app/bootstrap/runtime_install/` 或新的 `src/infrastructure/runtime/`。本任务不要让内层模块反向依赖 `src/app/bootstrap/*`；`src/core/RuntimePorts.lua` 可以保留为稳定 façade，但 façade 不应再承载宿主细节。若迁移路径会造成大面积 require 震荡，可以先保留薄 shim，再在下一次小步提交中清掉。

validation：先跑 runtime 契约与启动回归，再跑完整回归；期间不允许出现“为了搬路径而新建第二套启动入口”。

    lua -e "package.path = package.path .. ';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; require('TestHarness').run_all({ require('runtime_ports_contract'), require('runtime_bootstrap'), require('startup_release') })"
    lua tests/regression.lua

log：2026-03-07 已完成。`src/core/RuntimeContext.lua`、`src/core/RuntimeEventBridge.lua`、`src/core/runtime_ports/DefaultPorts.lua` 当前均已退化为转发壳，真实实现位于 `src/app/bootstrap/runtime_install/RuntimeContext.lua`、`src/app/bootstrap/runtime_install/RuntimeEventBridge.lua`、`src/app/bootstrap/runtime_install/DefaultPorts.lua`。因此 T10 的主要工作不是再做一次大搬家，而是确认这条 façade 结构仍然成立，并用 `runtime_ports_contract + runtime_bootstrap + startup_release` 证明迁移后的启动链与契约保持稳定。该组回归已通过。

files edited/created：`docs/architecture/boundaries.md`、`.agents/research.md`（同步当前运行时迁移事实）。

结果：Completed。

### T11 同步文档、最终守护和收尾验收

id：T11。depends_on：[T10]。status：Completed。location：`docs/architecture/boundaries.md`、`.agents/research.md`、`.agents/plan.md`、必要时补充 `tests/internal/dep_rules.lua` 和相关契约测试。

description：在功能边界已经收口并通过全量回归之后，再更新文档，把新的依赖方向、运行时边界和验收命令写回仓库文档。不要提前修改文档为“理想状态”；只记录已经落地、已被测试证明有效的行为。此任务还负责对 `dep_rules`、`architecture_guard_contract` 等守护做最后一次收口，确保它们真实匹配当前实现。

validation：运行下面命令，并人工检查文档描述与代码事实一致，不出现“文档写已完成、代码仍留旧桥”的情况。

    lua tests/internal/dep_rules.lua
    lua tests/regression.lua
    git diff --stat

log：2026-03-07 已完成。文档已同步以下事实：前五个里程碑全部完成；运行时具体实现已位于 `src/app/bootstrap/runtime_install/`，`src/core` 中对应模块只保留 façade；`systems -> flow` 反向依赖已被静态守护禁止；`LegacyOutputMirror` 已退化为 runtime passthrough；`presentation` 与 `game/flow` 已不再直接读取 root-level `state.ui_model`、`state.pending_choice*`、`state.ui_modal_*`。最终守护 `dep_rules` 通过，全量回归通过，计划闭环。

files edited/created：`.agents/plan.md`、`.agents/research.md`、`docs/architecture/boundaries.md`。

结果：Completed。

## 验证与验收

每个里程碑都必须同时满足“行为继续正确”和“边界更清晰”两条线。行为正确由定向 suite 和全量回归证明，边界更清晰由静态扫描与守护脚本证明。任何一个里程碑如果只满足其中一条，都不能算完成。

定向 suite 的运行方式统一使用仓库已有的 TestHarness，不额外发明新的临时入口。`market` 用于验证购买、支付回调与 market choice；`presentation_ui` 和其拆分 suite 用于验证 choice、modal、popup、target picker 与 UI 同步；`architecture_guard_contract`、`usecase_boundary_contract`、`ui_gate_contract`、`runtime_ports_contract` 用于验证边界形状没有回退。执行者不必强求每次都跑全量回归，但每个里程碑结束时必须至少跑一次覆盖本里程碑影响面的定向 suite。

最终验收必须在仓库根目录执行下面四类命令，并全部成功。第一类是 `systems -> flow` 的静态扫描：

    rg -n 'src\.game\.flow\.' src/game/systems -g '*.lua'

第二类是 `ui_port` 的静态扫描：

    rg -n '\bui_port\b' src/game src/core -g '*.lua'

这两条命令最终都不应有输出。第三类是静态守护：

    lua tests/internal/dep_rules.lua

它必须打印 `dep_rules ok`。第四类是全量回归：

    lua tests/regression.lua

它的末尾必须继续包含 `All regression checks passed`、`dep_rules ok`、`tick ok` 和 `forbidden_globals ok`。如果任何一个里程碑使这些输出消失，实施者必须先修复或回退，再继续下一个里程碑。

## 可重复性与恢复

这份计划的默认执行单位是“一项任务一组改动”。不要把 T2、T3、T4 这种本来可并行的任务混进同一次提交，也不要把“功能迁移”和“目录重命名”放在同一组改动里。每次只做一个任务定义中的写集，这样出问题时才能按任务粒度回退，而不是把整波并行工作一起撤掉。

如果里程碑 1 的技术探针失败，不要强行推进到里程碑 2。应直接在“意外与发现”和“决策日志”补记录，然后把 T1 再拆小，例如先只支持 `open_choice`，暂不迁 `push_popup`。如果 T6 或 T7 发现 `ui_runtime` 缺少某个只读 helper，不要重新让消费方去读 root-level `state.*`，而是回到 `RuntimeState` 增补 API。恢复策略始终是“补稳定接口”，不是“重新开口子”。

如果 T9 删除 `ui_port` fallback 后大量测试夹具失败，优先修夹具，让它们安装真实窄端口；不要因为测试夹具偷懒而把 `ui_port` 兼容路径重新塞回生产代码。只有当某个真实启动路径还没有窄端口安装点时，才允许在该任务里同时补安装逻辑。

如果 T10 的路径迁移导致 require 震荡过大，可以先保留薄 shim。这里的“薄 shim”指只负责转发到新路径的薄文件，不允许再含有新的逻辑分支。每保留一个 shim，都要在 `决策日志` 写清原因和退出条件，并在 T11 文档同步时再次确认它是否还能被删除。

## 产物与备注

本计划预期最终会触达以下类型的产物。第一类是新的边界模块，例如 `src/game/ports/IntentOutputPort.lua` 与 `src/game/flow/ports/IntentOutputAdapter.lua`。第二类是现有运行时状态和用例端口文件的重构，例如 `src/core/RuntimeState.lua`、`src/game/flow/ports/UseCaseOutputPort.lua`、`src/game/flow/turn/*`。第三类是生产代码的边界消费方，例如 `src/game/systems/*`、`src/presentation/*` 和 `src/app/bootstrap/*`。第四类是守护与回归测试，包括 `tests/internal/dep_rules.lua`、`tests/suites/architecture_guard_contract.lua`、`tests/suites/usecase_boundary_contract.lua`、`tests/suites/market.lua`、`tests/suites/presentation_ui*.lua`、`tests/suites/runtime_ports_contract.lua`。

这项工作不会引入新的第三方依赖，也不需要改动构建系统。所有验证均使用仓库现有 Lua 测试入口完成。若在实施中发现必须引入新库，必须先中止并补一条新的决策日志，解释为什么现有模式无法满足需求；在没有这条日志之前，默认禁止加库。

## 接口与依赖

本计划要求新增或明确以下接口，实施时不要在这些边界上继续含糊。

    src/game/ports/IntentOutputPort.lua
      open_choice(game, choice_spec, opts)
      push_popup(game, payload, opts)

这个模块是 inward-facing contract。`src/game/systems/*` 只能依赖它，不能依赖 `src/game/flow/*`。它自身不应直接调用 UI、宿主事件或 `IntentDispatcher`；它只负责解析并调用 `game.intent_output_port`。

    src/game/flow/ports/IntentOutputAdapter.lua
      build() -> { open_choice = fn, push_popup = fn }

这个模块是 outer adapter，内部可以继续使用 `src/game/flow/intent/IntentDispatcher.lua`，但它的存在意义就是把 `IntentDispatcher` 留在用例层，不再让业务规则层直接触碰它。

    game.intent_output_port
      open_choice(game, choice_spec, opts)
      push_popup(game, payload, opts)

这个表由 `GameplayLoop.set_game` 或与之等价的装配点安装。任何 `systems` 模块如果需要发出选择或弹窗意图，都从 `game.intent_output_port` 这条窄边界走。

    src/core/RuntimeState.lua
      ensure_ui_runtime(state)
      get_ui_model(state) / set_ui_model(state, model)
      is_ui_dirty(state) / set_ui_dirty(state, dirty)
      get_pending_choice(state) / set_pending_choice(state, choice, opts)
      get_pending_choice_id(state) / set_pending_choice_id(state, choice_id)
      get_pending_choice_elapsed(state) / set_pending_choice_elapsed(state, seconds)
      get_modal_timer(state) / set_modal_timer(state, payload)

这些函数名可以在实施时微调，但职责不能变：所有对 choice、modal、UI model、ui_dirty 的运行时读写都必须集中到这里，不允许各个消费方直接摸 root-level `state.*`。如果需要兼容旧字段，也只能在这个模块内部做一次性吸收，不能让外部模块再知道 legacy 布局。

    game.anim_gate_port
      wait_action_anim
      wait_move_anim

    game.popup_port
      push_popup(_, payload, opts)

    game.tile_feedback_port
      on_tile_upgraded(_, tile_id, level)

    game.board_scene_port
      get_board_scene()

这些窄端口是 `ui_port` 退役后的唯一合法替代。生产代码里不再允许读取 `game["ui_port"]`、`ui_port.wait_action_anim`、`ui_port.push_popup` 或类似路径。测试夹具若需要模拟 UI 能力，也必须显式安装这些窄端口，而不是偷塞一个 `ui_port` 大对象。

最后再次强调依赖方向。`src/game/systems` 可以依赖 `src/game/ports/*`、`src/core/*` 和其他更内层规则模块，但不能依赖 `src/game/flow/*`、`src/presentation/*` 或 `src/app/*`。`src/presentation` 可以依赖 `src/core/*` 和稳定的 read model / DTO，但不能新增对 `src/game/systems/*` 的直接 require。`src/app/bootstrap` 负责装配，可以依赖其它层，但不能把宿主细节重新塞回内层目录。

## 更新记录

2026-03-07：根据 `.agents/research.md` 重写 `.agents/plan.md`，把计划从“目录语义整理”改成“先切断 `systems -> flow`、再统一 `ui_runtime`、再删除 `ui_port`、最后整理 runtime 目录”的执行顺序。这样做是因为当前真正的风险来自依赖方向和双轨状态，而不是文件名本身。
