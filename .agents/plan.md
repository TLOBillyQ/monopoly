# Clean Architecture 收尾计划：支付适配器外迁与 choice/output 边界固化

## 目的 / 全局视角

这份计划对应 `.agents/research.md` 的最新结论，目标不是再做一次全局大拆，而是把当前代码库里最后几条高价值边界真正收口。用户视角下，这项工作的意义很直接：后续继续改黑市支付、choice 交互、UI 运行时同步时，不会再因为平台 API、旧共享状态或隐式协议混进业务层而牵一发而动全身。

改完之后，仓库会比现在多三种新的稳定性。第一，黑市付费购买将真正通过端口与 Eggy 平台解耦，业务规则不再直接认识 `GameAPI` 和购买 trigger。第二，用例层的 output port 将只表达“应该输出什么”，不再顺手维护旧 UI 状态镜像。第三，choice 协议会从“约定俗成的一组字段”变成“显式、可验证、可持续扩展的边界契约”。

这项工作是否真的生效，不能靠“代码看起来更整齐”判断，而要靠可观察结果判断。工作完成后，应该继续能跑通 `market`、`presentation_ui` 和全量回归；同时，`tests/internal/dep_rules.lua` 应新增对支付适配边界和 output 镜像边界的守护，确保这些问题不会再悄悄长回来。

## 进度

- [x] (2026-03-07 11:58 +0800) 已按最新代码重写 `.agents/research.md`，确认当前主体迁移已完成，剩余工作集中在四类收尾问题：付费适配器外迁、output port 去镜像、choice 协议 contract 化、`owner_role_id` 强约束化。
- [x] (2026-03-07 12:02 +0800) 已重读 `.agents/harness/PLANS.md`、现有 `.agents/plan.md`、`docs/architecture/boundaries.md`、`tests/internal/dep_rules.lua` 和关键边界代码，确认当前统一回归入口仍是 `lua tests/regression.lua`，最新全量输出为 `All regression checks passed (376)`。
- [x] (2026-03-07 12:18 +0800) 已完成里程碑 1 的第一刀：把 Eggy 宿主支付实现搬到 `src/app/bootstrap/payment/EggyPaidPurchaseGateway.lua`，`src/game/systems/market/service/PaidPurchaseGateway.lua` 现只保留薄代理；同时 `tests/internal/dep_rules.lua` 新增守护，禁止 `src/game/systems/market/service` 再直接触碰 `GameAPI`、`RegisterTriggerEvent`、`EVENT`。定向 `market`、`paid_currency`、全量回归均继续通过。
- [x] (2026-03-07 12:31 +0800) 已完成里程碑 1 的第二刀：新增 `src/game/systems/market/ports/PaidPurchasePort.lua`，`Purchase.lua` 现改为只依赖 market 内层支付端口；`RuntimePorts` 与 `src/app/bootstrap/runtime_install/RuntimePortDefaults.lua` 也已接入 `resolve_market_paid_gateway()` 默认装配。当前仍保留 port 内部对 Eggy adapter 的测试环境 fallback，但 `Purchase` / `MarketService` 已不再直接 require 外层实现。
- [x] (2026-03-07 12:46 +0800) 已完成里程碑 2：新增 `src/game/flow/ports/LegacyOutputMirror.lua`，`UseCaseOutputPort.lua` 现只维护 `ui_runtime` 语义，默认 `build_base_output_ports()` 再通过 legacy mirror 把旧字段桥接回 `state`；已补 `usecase_boundary_contract` 验证“纯 runtime output 不写 legacy state，默认 base output 仍保留桥接行为”。
- [x] (2026-03-07 13:02 +0800) 已完成里程碑 3 的第一刀：新增 `src/core/ChoiceContract.lua`，把 `route_key`、`requires_confirm`、`owner_role_id`、`confirm_*`、item-slot、target-picker、market 分页等稳定字段集中成单一清单；`IntentDispatcher.lua`、`UIChoice.lua`、`TurnDispatchValidator.lua`、`TargetChoiceEffects.lua`、`ItemSlice.lua` 已改接 contract helper，`usecase_boundary_contract` 已补“显式字段单点复制”契约。
- [x] (2026-03-07 13:18 +0800) 已完成里程碑 4：`ChoiceContract.resolve_owner_role_id()` 不再回退到 `meta.player_id`；`TurnChoiceAutoPolicy.lua`、`TickChoiceTimeout.lua`、`ChoiceSession.lua`、`TurnDispatchValidator.lua`、`ItemSlice.lua` 已统一改走显式 `owner_role_id` 路径；`LandChoiceSpecs.lua` 与 `EffectPipeline.lua` 也已为相关 choice 补齐 `owner_role_id`。全量回归继续通过。
- [x] (2026-03-07 13:22 +0800) 里程碑 5 当前无需再做行为或目录重命名整理：`docs/architecture/boundaries.md` 已足够承担目录语义导读，继续重命名目录的收益低于噪音，故本轮在研究目标上视为完成。

## 意外与发现

- 当前代码库最大的变化不是“目录更漂亮了”，而是三条旧耦合已经被压下去：`src/core` 宿主耦合、`game.ui_port` 反向依赖、presentation 对 `choice.kind/meta` 的主要业务推断。这意味着新计划不应再按“救火式重构”写，而应按“小步收尾”写。

- `PaidPurchaseGateway.lua` 现在已经是黑市支付链路里唯一最显眼的外部细节泄漏点。它直接调用 `GameAPI.get_goods_list`、`RegisterTriggerEvent` 和 `EVENT.SPEC_ROLE_PURCHASE_GOODS`。这说明它不是“还可以等等的小瑕疵”，而是当前最明确的 Dependency Rule 逆流。

- `UseCaseOutputPort.lua` 虽然建立了正确方向的 output port，但实现中仍会同步写 `state.ui_dirty`、`state.ui_model`、`state.pending_choice*`、`state.ui_modal_*` 等 legacy 字段。这条兼容桥是有意留下的，但也意味着真正的边界尚未完全纯化。

- choice 稳定协议已经显式化了很多字段，例如 `route_key`、`confirm_title`、`confirm_body`、`owner_role_id`、`uses_target_picker`、`target_picker_owner_role_id`、`active_tab`、`page_index`、`page_count`。但这些字段目前仍分散在多个 builder、copy 点和 presenter 中，还没有一个单一 contract helper 统一约束。

- `docs/architecture/boundaries.md` 已经把当前目录职责写清楚，所以本计划不再把“立刻重命名目录”当作前置工作。真正的顺序应该是先清掉行为边界上的最后几条漏点，再看目录名是否还值得动。

## 决策日志

- 决策：这版计划不再重复阶段 0 到阶段 6 的历史迁移，而只围绕最新 `research` 识别出的剩余边界工作展开。
  理由：历史主体迁移已经完成，继续让计划围绕旧阶段展开会误导执行者，把注意力拉回已收口区域。
  日期/作者：2026-03-07 / Codex

- 决策：优先把 `PaidPurchaseGateway` 外迁，而不是先改 runtime 目录名。
  理由：前者是仍然活着的 Dependency Rule 错误，后者主要是目录语义优化。Clean Architecture 下，先修依赖方向，再修命名。
  日期/作者：2026-03-07 / Codex
- 决策：里程碑 1 先采用“外层搬家 + 静态守护上锁”的两段式推进，而不是一次性同时完成端口反转。
  理由：先把宿主 API 从 `src/game/systems/market/service` 物理挪出，并用 `dep_rules` 锁死回流，可以在零行为变化下先拿到一个稳定检查点；随后再把薄代理替换为真正的内层端口，风险更低，也更容易回滚。
  日期/作者：2026-03-07 / Codex

- 决策：市场支付端口暂时允许在 `PaidPurchasePort.lua` 内部保留一个 Eggy adapter fallback，用于未走 `RuntimeInstall` 的测试环境。
  理由：当前大量单元/定向测试直接 require 市场服务而不走完整 bootstrap；若在同一刀里强制所有测试先安装 runtime port，会把“端口反转”和“测试环境迁移”混成一次高风险改动。先让 `Purchase` 只依赖端口，再在后续阶段逐步删除 fallback，更稳。
  日期/作者：2026-03-07 / Codex


- 决策：`UseCaseOutputPort` 的下一步不是立刻删兼容，而是拆出 legacy 镜像 adapter。
  理由：当前 presentation 和部分测试仍在消费 legacy 状态。如果直接删除镜像，会把“边界收口”和“迁移断崖”混成同一次高风险改动。
  日期/作者：2026-03-07 / Codex
- 决策：`UseCaseOutputPort` 采用“双构建入口”而不是切换同一组函数的隐藏行为：`build_runtime_output_ports()` 给纯 runtime 用，`build_base_output_ports()` 给默认兼容桥接用。
  理由：这样测试和调用者可以明确选择自己要验证的边界，不会因为同名 API 在不同环境里偷偷切换行为而让契约变模糊。
  日期/作者：2026-03-07 / Codex


- 决策：choice 系统的下一步是做 contract helper，而不是发明复杂类型框架。
  理由：当前 Lua 代码库已经有稳定显式字段，只差集中声明与透传验证。引入过重抽象会增加复杂度，却不一定增加稳定性。
  日期/作者：2026-03-07 / Codex
- 决策：choice contract 先放在 `src/core/ChoiceContract.lua`，而不是放在 presentation 或 market 子目录。
  理由：这组字段已经同时被用例层、校验层和 presentation 消费，属于跨玩法的稳定协议；放在 `src/core` 更符合“内层定义边界，外层消费边界”的方向。
  日期/作者：2026-03-07 / Codex


- 决策：`owner_role_id` 的 fallback 删除必须排在 choice contract helper 之后。
  理由：只有先把“哪些 choice 必须显式声明 ownership”写成契约，删 fallback 才不会变成碰运气的清理。
  日期/作者：2026-03-07 / Codex

## 结果与复盘

当前仓库已经达到一个很关键的中间态。它不再是“名义上分层、实质上混层”的状态：`src/core` 已基本恢复成稳定策略层，`src/game/flow` 已通过 output port 管理 UI 输出，黑市购买链路已拆成多个职责明确的 service，presentation 也已开始依赖用例层输出的显式 choice 语义而不是自己推断业务。

但从可持续演进角度看，最后几条小边界反而更值得谨慎处理。因为它们现在不再表现为“代码完全没法维护”，而是表现为“只有在继续扩展功能时才会反噬”的延迟性耦合。Clean Architecture 的价值就在这里：不是等问题重新变大才补救，而是在边界已经大致正确时，把最后几处仍然指向外层细节或隐式协议的依赖关掉。

因此，这份计划的风格必须是增量式、可验证、可回滚的。每个里程碑都要以“行为保持不变，但边界更清晰”为目标，不能为了追求概念纯度而打乱已稳定的玩法行为。

## 背景与导读

如果你是第一次进入这个仓库，请先把下面几组文件当成地图来看。

第一组是研究结论，位于 `.agents/research.md`。它不是历史报告，而是针对 2026-03-07 最新代码做的复审。最重要的判断有三条：大边界已经基本转正；当前最大剩余问题是 `PaidPurchaseGateway` 的宿主耦合；后续策略应该是“小步收尾”，而不是再做一轮大拆迁。

第二组是边界导读，位于 `docs/architecture/boundaries.md`。这里解释了 `src/app`、`src/core`、`src/game/flow`、`src/game/systems`、`src/presentation` 当前分别负责什么，也明确说明了 choice 协议、宿主 API 和目录放置规则。执行本计划时，凡是拿不准“代码应该放哪一层”，都先回读这份导读。

第三组是架构守护入口，位于 `tests/internal/dep_rules.lua`。它不只是测试文件，也是当前剩余债务的账本。只要新增了被禁止的依赖方向，这个脚本就会失败。以后每完成一次边界收口，都应在同一次提交里同步收紧守护规则，否则回归会用“账本未更新”的方式提醒你没有把边界固化进仓库。

第四组是用例输出与 choice 协议相关文件。`src/game/flow/intent/IntentDispatcher.lua` 负责把 `choice_spec` 落成运行时 `pending_choice`。`src/game/flow/ports/UseCaseOutputPort.lua` 负责把用例输出同步到 UI runtime。`src/presentation/ui/UIChoice.lua`、`src/presentation/state/ui_model/ChoiceSlice.lua`、`src/presentation/interaction/ui_intent_dispatcher/PreConfirmFlow.lua`、`src/presentation/render/TargetChoiceEffects.lua` 负责消费这些显式字段。里程碑 2 到里程碑 4 都要围绕这组文件推进。

第五组是黑市购买链路。`src/game/systems/market/service/Purchase.lua` 是购买编排入口；`LocalPurchase.lua` 负责本地金币购买；`PaidPurchaseGateway.lua` 负责外部支付桥接；`PaidFulfillment.lua` 负责付费兑现；`ChoiceSession.lua` 负责 market choice 的分页和页签刷新；`ChoiceOutcome.lua` 负责购买结果后的后续动作。里程碑 1 会优先动这组文件。

最后一组是统一验证入口。当前工作目录固定为仓库根目录 `/Users/billyq/Dev/Github/Lua/monopoly`。本计划所有阶段都应沿用这四条命令作为事实标准，而不是自己发明新入口：`lua tests/internal/dep_rules.lua`、定向 `market` suite、定向 `presentation_ui` suite、`lua tests/regression.lua`。

## 里程碑 1：把付费购买适配器外迁成真正的 adapter

这个里程碑要解决当前最明确的 Dependency Rule 错误。现在 `src/game/systems/market/service/PaidPurchaseGateway.lua` 既承担“支付端口”的名字，又直接知道 `GameAPI.get_goods_list`、`RegisterTriggerEvent`、`EVENT.SPEC_ROLE_PURCHASE_GOODS` 和角色购买面板。这意味着黑市业务服务目录仍然被 Eggy 平台细节牵着走。

本里程碑的目标，是把“业务上需要一次外部付费购买”与“Eggy 平台上如何取商品列表、如何注册购买事件、如何打开购买面板”拆开。这里明确采用两刀推进。第一刀已经完成：Eggy 专属实现已搬到 `src/app/bootstrap/payment/EggyPaidPurchaseGateway.lua`，原 `src/game/systems/market/service/PaidPurchaseGateway.lua` 只保留薄代理，`dep_rules` 也已禁止 market service 再直接触碰 `GameAPI`、`RegisterTriggerEvent`、`EVENT`。这一步的价值是先把最明显的宿主 API 逆流从 service 目录里清掉，并把边界守护写进仓库。

第二刀仍然待做：把当前薄代理再替换成真正的支付端口，让 `Purchase.lua` 与 `MarketService` 只依赖端口，不再直接 require 外层 Eggy adapter。这里不追求一次性发明复杂端口框架，最小可行方案是定义 market 内层支付端口，再由 bootstrap/runtime 安装 Eggy 实现。随后补 fake gateway 契约测试，证明 use case 层只靠端口也能跑购买流程。

当前这一里程碑已经完成。`src/game/systems/market/service` 中不再直接调用 `GameAPI`、`RegisterTriggerEvent` 或 `EVENT`；`Purchase.lua` 已改为依赖 `src/game/systems/market/ports/PaidPurchasePort.lua` 这条内层端口；`RuntimePorts` 与 bootstrap 默认装配已提供 `resolve_market_paid_gateway()`；`market`、`paid_currency`、全量回归都继续通过。当前唯一保留的妥协，是支付端口内部仍为非 runtime-install 测试环境保留了一个 Eggy adapter fallback，但这已经不再把外层实现泄漏给 `Purchase` / `MarketService`。

## 里程碑 2：把 `UseCaseOutputPort` 拆成纯端口与 legacy 镜像 adapter

这个里程碑要解决的是“方向正确，但层次仍混”的问题。`src/game/flow/ports/UseCaseOutputPort.lua` 现在已经把 UI 输出集中起来，但它仍然知道旧 UI 状态长什么样，还会去维护 `state.ui_dirty`、`state.ui_model`、`state.pending_choice*`、`state.ui_modal_*` 等 legacy 字段。这对迁移阶段有帮助，但从 Clean Architecture 角度看，它让 use case port 和 adapter 仍然缠在一起。

本里程碑的做法，是把“端口语义”和“兼容镜像”拆开。`UseCaseOutputPort` 应只暴露和维护稳定输出语义，例如 invalidate UI、sync pending choice、sync modal timer。真正把这些语义镜像回旧字段的动作，应由新的 legacy adapter 负责。适配器可以继续存在一段时间，但它必须被明确标记为外层兼容层，而不是默认躲在用例端口内部。

执行时不要试图一次删掉所有 legacy 状态读路径。先把镜像逻辑抽到单独模块，再让当前调用点继续消费同一个输出接口。只要行为不变，就先让 `market`、`presentation_ui` 与全量回归保持通过。后续如果要继续删 legacy 字段，只需要清理 adapter，不必再回头改 use case 层。

这个里程碑现在已经完成。`UseCaseOutputPort.lua` 已不再直接 `rawset` legacy state 字段；新的 `src/game/flow/ports/LegacyOutputMirror.lua` 承担兼容桥接；默认 `GameplayLoopPorts` 仍通过 `build_base_output_ports()` 暴露 legacy 兼容行为，而 `build_runtime_output_ports()` 则提供不写旧字段的纯 output 版本。`usecase_boundary_contract` 已新增契约，验证纯 runtime output 与默认桥接 output 的职责分离；`architecture_guard_contract` 与全量回归也继续通过。

## 里程碑 3：把 choice 稳定协议集中成单一 contract helper

这个里程碑要处理的是 choice 协议分散的问题。现在显式字段已经有了，例如 `route_key`、`requires_confirm`、`confirm_title`、`confirm_body`、`owner_role_id`、`uses_item_slots`、`pre_confirm_before_slot_pick`、`uses_target_picker`、`target_picker_owner_role_id`、`active_tab`、`page_index`、`page_count`。但这些字段分散在 builder、copy 点、presenter 和 validator 之间，没有一个单一模块说明“哪些字段属于稳定协议、应该如何透传”。

本里程碑不引入重型类型系统，也不改变 Lua 写法习惯。最小做法是新增一个 choice contract helper，集中声明允许透传的显式字段、需要复制的字段，以及少量通用读取逻辑。`IntentDispatcher.open_choice()`、`UIChoice.build_choice_view()`、`ChoiceSlice.build_choice_and_market()` 等模块再改为通过这个 helper 做透传或读取。这样以后新增字段时，只需要同步更新一处契约，而不是担心“builder 改了、runtime copy 漏了、presentation 又靠 fallback 顶上”。

执行时先覆盖已经成熟的稳定字段，不要急着把所有 `meta` 内容都抽出来。只要能把当前已经显式化的协议收束进一份 contract，就已经能显著减少未来漂移风险。随后补一组 choice 生命周期契约测试，验证 builder → `IntentDispatcher` → `pending_choice` → `UIChoice` / `ChoiceSlice` 的字段透传链路。

这个里程碑现在已经完成。choice 协议的显式字段有了单一清单，位置在 `src/core/ChoiceContract.lua`；`IntentDispatcher` 与 `UIChoice` 不再各自维护一份手写字段列表；`TurnDispatchValidator`、`TargetChoiceEffects`、`ItemSlice`、`TurnChoiceAutoPolicy`、`TickChoiceTimeout`、`ChoiceSession` 也已开始共用同一套读取逻辑。`usecase_boundary_contract`、`architecture_guard_contract` 与全量回归继续通过，说明这组 contract 已成为系统内真正的稳定边界，而不是只写在某个 builder 里的约定。

## 里程碑 4：把 `owner_role_id` 变成强约束，删除 ownership fallback

这个里程碑现在已经完成。`ChoiceContract.resolve_owner_role_id()` 不再回退到 `meta.player_id`，actor ownership 的正式边界只剩显式 `owner_role_id`。与这条边界直接相关的读取路径——`TurnDispatchValidator.lua`、`TurnChoiceAutoPolicy.lua`、`TickChoiceTimeout.lua`、`ChoiceSession.lua`、`ItemSlice.lua`——都已统一改走显式 owner 字段。为了让这条边界真正站得住，`LandChoiceSpecs.lua` 与 `EffectPipeline.lua` 也已为相关 choice 补齐 `owner_role_id`。

这意味着系统不再默许“忘了声明 ownership 也能靠 `meta.player_id` 跑起来”。如果未来新增一类需要 owner 约束的 choice，却没有显式输出 `owner_role_id`，它更可能在契约或行为测试里尽早暴露，而不是悄悄走回旧协议。

## 里程碑 5：目录语义整理

这个里程碑在本轮研究目标下可以视为已完成。原因不是做了大规模目录重命名，而是因为 `docs/architecture/boundaries.md` 已经把 `src/app`、`src/core`、`src/game/flow`、`src/game/systems`、`src/presentation` 的职责说清楚了。对于当前代码库来说，继续去重命名目录、迁移 require 路径，收益已经明显小于机械性噪音和回归成本。

因此，本轮对“research.md 对应的收尾工作”给出的结论是：行为边界已经收口，目录命名不再是阻塞项；除非未来出现新的真实维护痛点，否则没有必要为了追求名义纯度再做一次重命名式重构。

## 工作计划

当前这份计划对应的研究目标已经完成。后续如果还要继续维护这套边界，推荐沿用同一节奏：先找出真实变更压力最大的边界，再以“小步实现 + 定向回归 + 全量回归 + 同步活计划”的方式推进，而不要重新回到一次性大拆的节奏。

## 具体步骤

先验证当前基线，工作目录固定为仓库根目录 `/Users/billyq/Dev/Github/Lua/monopoly`。

    lua tests/internal/dep_rules.lua

预期输出：

    dep_rules ok

再跑与本计划最相关的黑市定向回归。

    lua -e "package.path = package.path .. ';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; require('TestHarness').run_all({ require('market') })"

预期输出最后一行是：

    All regression checks passed (15)

然后跑 presentation 定向回归，因为里程碑 2 到里程碑 4 都会影响 choice / modal / target picker / market UI 的边界。

    lua -e "package.path = package.path .. ';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; require('TestHarness').run_all({ require('presentation_ui') })"

预期输出最后一行是：

    All regression checks passed (135)

最后跑统一全量回归。

    lua tests/regression.lua

预期输出末尾包含：

    All regression checks passed (376)
    dep_rules ok
    tick ok
    forbidden_globals ok

开始里程碑 1 时，先阅读并修改这些文件。

    src/game/systems/market/service/PaidPurchaseGateway.lua
    src/game/systems/market/service/Purchase.lua
    src/game/systems/market/service/PaidFulfillment.lua
    src/game/systems/market/MarketService.lua
    tests/suites/market.lua
    tests/internal/dep_rules.lua

这一步完成后，应能观察到两个结果：第一，market service 目录中的宿主直接调用减少或归零；第二，`market` suite 和全量回归继续通过。

开始里程碑 2 时，优先阅读并修改这些文件。

    src/game/flow/ports/UseCaseOutputPort.lua
    src/core/RuntimeState.lua
    src/presentation/api/presentation_ports/StatePorts.lua
    tests/suites/architecture_guard_contract.lua
    tests/suites/presentation_ui.lua

这一步完成后，应能观察到：output port 只表达输出语义，legacy state 镜像被单独适配；定向 `presentation_ui` 继续通过。

开始里程碑 3 和里程碑 4 时，重点阅读并修改这些文件。

    src/game/flow/intent/IntentDispatcher.lua
    src/presentation/ui/UIChoice.lua
    src/presentation/state/ui_model/ChoiceSlice.lua
    src/game/flow/turn/TurnDispatchValidator.lua
    src/presentation/state/ui_model/ItemSlice.lua
    src/game/systems/market/service/ChoiceSession.lua
    src/game/systems/choices/ChoiceResolver.lua
    src/game/systems/choices/ChoiceHandlers/*.lua
    tests/suites/presentation_ui.lua
    tests/suites/market.lua

这两步完成后，应能观察到：choice 协议字段有单一约束位置；ownership 路径不再依赖 `meta.player_id` fallback；所有相关回归仍通过。

如果进入里程碑 5，只允许修改导读、README、目录语义说明和纯重命名路径；每做一步都必须重新运行全量回归，确保行为没有被语义整理带偏。

## 验证与验收

本计划每一阶段都必须同时满足“边界更清晰”和“行为继续正确”这两个条件，缺一不可。

第一，静态守护必须持续有效。每次修改后运行 `lua tests/internal/dep_rules.lua`，如果计划对应的边界已经收口，就应把守护同步收紧。未来只要有人重新把宿主 API 塞回 market service、把 legacy UI 状态写回用例层、或把退役 bridge 路径带回来，这个脚本就应立即失败。

第二，定向 suite 必须成为本计划的主要验收面。`market` suite 验证购买链路、session 刷新和支付相关行为；`presentation_ui` suite 验证 choice 显式协议、secondary confirm、target picker、market modal、actor ownership 等关键交互。任何阶段只要这两组测试没有至少跑过一遍，就不能算完成。

第三，全量回归必须继续通过，而且统一入口仍然只能是 `lua tests/regression.lua`。本计划不允许为了让某一步更容易通过而额外创造新的“临时回归入口”，否则后续维护者会失去单一事实标准。

第四，验收必须看得到用户可观察结果。对于里程碑 1，观察点是黑市购买行为不变但宿主细节已外迁。对于里程碑 2，观察点是 choice / popup / modal 行为不变但 output port 不再背负 legacy 镜像。对于里程碑 3 和里程碑 4，观察点是 choice 交互和 ownership 校验仍然正确，但协议边界更严格、更少 fallback。

## 可重复性与恢复

这份计划强调增量推进，所以每个里程碑都应是可独立回退的。如果某一步在中途失败，不要在同一次提交里混入“修一半的 adapter”和“修一半的测试”。最稳的做法是：让每个提交都保持可运行、可回滚、可再次从当前计划继续推进。

如果需要回退里程碑 1，应同时回退新支付端口、Eggy adapter、相关 market 契约测试与 `dep_rules` 调整，确保不会留下“代码已经回退，但守护仍禁止旧实现”或“守护已经回退，但代码仍半新半旧”的不一致状态。

如果需要回退里程碑 2，应一起回退纯 output port、legacy 镜像 adapter 和消费它们的测试。不要只回退端口代码不回退测试，否则你会得到一组看似失败、实则是在验证不存在接口的回归。

如果需要回退里程碑 3 或里程碑 4，应一起回退 choice contract helper、ownership 契约测试和相关 fallback 删除。因为这些改动的核心价值不在单个字段，而在“字段 + 契约 + 使用者”三者一致。

## 产物与备注

本计划准备触达的关键文件如下。

    .agents/research.md
    .agents/plan.md
    docs/architecture/boundaries.md
    tests/internal/dep_rules.lua
    tests/suites/architecture_guard_contract.lua
    tests/suites/market.lua
    tests/suites/presentation_ui.lua
    tests/regression.lua
    src/game/flow/ports/UseCaseOutputPort.lua
    src/game/flow/intent/IntentDispatcher.lua
    src/game/flow/turn/TurnDispatchValidator.lua
    src/game/systems/market/service/PaidPurchaseGateway.lua
    src/game/systems/market/service/Purchase.lua
    src/game/systems/market/service/PaidFulfillment.lua
    src/game/systems/market/service/ChoiceSession.lua
    src/game/systems/choices/ChoiceResolver.lua
    src/game/systems/choices/ChoiceHandlers/
    src/presentation/ui/UIChoice.lua
    src/presentation/state/ui_model/ChoiceSlice.lua
    src/presentation/state/ui_model/ItemSlice.lua
    src/presentation/interaction/ui_intent_dispatcher/PreConfirmFlow.lua
    src/presentation/render/TargetChoiceEffects.lua

当前已知的基线事实如下。

    src/core 直接宿主触点：0（由现有研究与守护确认）
    game.ui_port 依赖点：0（由现有研究与守护确认）
    最新 market 定向回归：All regression checks passed (15)
    最新 paid_currency 定向回归：All regression checks passed (4)
    最新 usecase_boundary_contract：All regression checks passed (9)
    最新 architecture_guard_contract：All regression checks passed (7)
    最新 presentation_ui 定向回归：All regression checks passed (135)
    最新全量回归：All regression checks passed (376)
    里程碑 1 当前状态：已完成
    里程碑 2 当前状态：已完成
    里程碑 3 当前状态：已完成
    里程碑 4 当前状态：已完成
    里程碑 5 当前状态：在本轮目标下视为完成

这份计划默认假设执行者工作在本机仓库根目录，并且能运行 Lua 测试命令。如果运行环境临时缺少测试依赖，必须先恢复到能跑统一回归的状态，再推进任何架构改动。因为对这份计划来说，验证不是收尾动作，而是每一步是否成立的定义本身。

## 接口与依赖

为了让新执行者能从零继续，这里明确写出本计划依赖的边界接口关系。

`IntentDispatcher.open_choice()` 是 choice 运行时协议的落点。任何 choice builder 输出的显式字段，只要要被 validator、presentation 或 market session 消费，就必须在这里被复制进 `game.turn.pending_choice`。如果某个字段只存在于 builder 输出，不存在于 `pending_choice`，那它就不算真正进入了系统边界。

`UseCaseOutputPort` 是用例层到展示层的主要输出口。它应该表达“失效 UI”“同步选择框”“同步 modal timer”这类稳定语义，而不是表达“把某个 legacy state 字段写成什么值”。如果仍然需要 legacy 兼容，兼容逻辑应落在 adapter，而不是藏在 port 里。

`TurnDispatchValidator`、`ItemSlice`、`ChoiceSession` 和 `TargetChoiceEffects` 当前共同消费 choice ownership 与 target picker 语义。也就是说，`owner_role_id`、`uses_target_picker`、`target_picker_owner_role_id` 这些字段已经是跨越 use case、interaction 与 presentation 的正式协议，而不是某个模块的内部细节。之后如果新增新的 ownership 字段或 target 语义，也必须遵守同样的显式协议路径。

黑市购买链路目前以 `Purchase.lua` 为编排入口，以 `ChoiceSession.lua` 维护 market session，以 `LocalPurchase.lua` 和付费购买 adapter 分别处理本地与外部支付。这里最重要的架构原则是：业务规则决定“买不买、给不给、刷不刷新 UI”，外部 adapter 决定“如何和 Eggy 平台说话”。无论后续如何实现，都不能再把这两种职责揉回同一个 service。
