# 架构重构路线图与阶段0守护

本可执行计划是活文档。实施过程中必须持续更新“进度”“意外与发现”“决策日志”“结果与复盘”。

本文件必须遵循 `.agents/harness/PLANS.md` 维护。讨论、实施、暂停和重启都只依赖这份计划本身，不依赖聊天历史。

## 目的 / 全局视角

这份计划服务的是一次渐进式架构收口，而不是推倒重写。用户真正需要的是：在继续开发玩法、UI 和宿主适配时，仓库不会再偷偷长出新的跨层依赖；后续阶段的重构可以在守护网内推进，而不是一边搬边继续欠债。阶段0完成后，最直接的可观察结果是三条边界开始被自动化守住：`src/core` 不能继续增加对 Eggy 全局 API 的直接触点，`src/game` 不能继续扩散 `game.ui_port` 读取点，`src/game/flow` 不能继续新增 `state.ui_*` 写入点。任何突破这三条边界的提交，都会在本地回归和 GitHub Actions 中失败。

这次计划还必须帮助下一位执行者继续阶段1，而不是只描述“今天改了什么”。因此本文既记录阶段0已完成的守护，也明确后续阶段1到阶段6要改的模块、顺序、验收方式和为什么这样拆。

## 进度

- [x] (2026-03-06 20:08 +0800) 已研读 `.agents/research.md`、`.agents/harness/PLANS.md`、`docs/eggy/lua_env.md`、`docs/eggy/ui_manager_lib.md`、`docs/eggy/eggy_lua_agent_memory.md`，并核对真实代码分布。
- [x] (2026-03-06 20:18 +0800) 已完成阶段0静态守护：`tests/internal/dep_rules.lua` 新增三组“衰减式基线”规则，冻结 `src/core` 宿主 API 触点、`game.ui_port` 读取点、`state.ui_*` 写入点的当前规模。
- [x] (2026-03-06 20:25 +0800) 已完成阶段0动态守护：新增 `tests/suites/architecture_guard_contract.lua`，验证 `GameplayLoop.set_game` 注入的是 DTO 形态的 `ui_port`，并拦截 `TurnDispatch` 关键路径上的 `state.ui_*` 写入。
- [x] (2026-03-06 20:27 +0800) 已将阶段0守护接入默认回归：`tests/regression.lua` 现在会运行 `architecture_guard_contract`。
- [x] (2026-03-06 20:29 +0800) 已补 CI 入口：新增 `.github/workflows/regression.yml`，在 `push` 和 `pull_request` 上执行 `lua tests/regression.lua`。
- [x] (2026-03-06 20:33 +0800) 已完成阶段0验收：`lua tests/internal/dep_rules.lua` 通过，定向守护 suite 通过，全量 `lua tests/regression.lua` 通过并输出 `All regression checks passed (364)`。
- [x] (2026-03-06 22:46 +0800) 已完成阶段1：新增 `src/game/flow/ports/UseCaseOutputPort.lua`，把 `GameplayLoop`、`TurnDispatch`、`TickChoiceTimeout`、`TickTimeout` 的 `state.ui_* / pending_choice* / ui_model` 写入收拢到 output port，并让 `tests/internal/dep_rules.lua` 中 `src/game/flow` 的 `state.ui_*` 预算降到 0。
- [x] (2026-03-06 22:49 +0800) 已补阶段1契约：`architecture_guard_contract` 新增 output-port 路由断言，`usecase_boundary_contract` 新增 output 默认桥接与 override 优先级测试；全量回归现输出 `All regression checks passed (367)`。
- [x] 阶段2：动画门控、popup 发射、tile feedback、choice elapsed 反读等 `game.ui_port` 依赖都已拆走，最后一刀已把 `GameplayLoop.set_game()` 的 catch-all runtime DTO 改成窄化的 `board_scene_port`，并删除 `GameStateTiles` 对 `ui_port` 的兜底读取；`tests/internal/dep_rules.lua` 中 `game.ui_port` 预算现已从 23 压到 0。
- [x] (2026-03-07 03:07 +0800) 已完成阶段2当前最窄的一刀：`TurnDecision.decide_choice_action()` 不再通过 `game.ui_port.state` 回读 `pending_choice_elapsed`；runtime coroutine session 现显式持有 `choice_elapsed_seconds`，`dep_rules` 中 `src/game/flow/turn/TurnDecision.lua` 的 `game.ui_port` 预算已降到 0。
- [x] (2026-03-07 03:19 +0800) 已完成阶段2第二刀的 popup 链路起点收口：`GameplayLoop` 现在注入专用 `game.popup_port`，`IntentDispatcher.push_popup()` 已优先走 popup_port，旧测试与非 `set_game` 路径则通过 `Game:ensure_popup_port()` 做兼容镜像；`dep_rules` 中 `src/game/flow/intent/IntentDispatcher.lua` 的 `game.ui_port` 预算已降到 0。
- [x] (2026-03-07 03:27 +0800) 已把 `Bankruptcy`、`LandingPresenter`、`ItemInventory`、`ItemUseBroadcast` 的 popup 发射路径切到 `popup_port`/兼容桥，`dep_rules` 中这四个文件的 `game.ui_port` 预算均已降到 0。
- [x] (2026-03-07 03:34 +0800) 已把 `ItemPhase` 的 `game.ui_port` 断言删除并把预算收紧到 0；当前阶段2剩余的高价值 `game.ui_port` 读路径主要收敛到 `BaseLandEffects` 的 `on_tile_upgraded` 直推和 `GameplayLoop` 自身保留的 runtime DTO 安装。
- [x] (2026-03-07 03:42 +0800) 已把 `BaseLandEffects` 的 `on_tile_upgraded` 直推改成 `tile_feedback_port`/兼容桥，`dep_rules` 中 `src/game/systems/land/landing_effects/BaseLandEffects.lua` 的 `game.ui_port` 预算已降到 0。
- [x] (2026-03-07 00:04 +0800) 已完成阶段2最后一刀：`GameplayLoop.set_game()` 不再注入泛化 `game.ui_port`，改为只注入 `board_scene_port`、`popup_port`、`tile_owner_notifier`、`anim_gate_port` 这些窄端口；`StatePorts` 已优先消费 `board_scene_port`，`GameStateTiles` 删除 `self.ui_port` fallback，`dep_rules` 中 `game.ui_port` 总预算已降到 0。
- [x] (2026-03-07 00:28 +0800) 已完成阶段3：`RuntimeGlobalAliases` 已外迁到 `src/app/bootstrap/runtime_install/`；`Logger`、`DefaultPorts`、`RuntimeEditorExports`、`RuntimeContext` 都已改成 host hook 或 runtime context env 读取；`src/core` 宿主触点预算已从 47 压到 0。
- [x] 阶段4：Market 购买链路已完成七刀并确认“行为上已收口”。`PaidPurchaseGateway.lua`、`Fulfillment.lua`、`PurchasePolicy.lua`、`Feedback.lua`、`ChoiceOutcome.lua`、`LocalPurchase.lua`、`ChoiceSession.lua` 已把支付桥接、兑现、副作用反馈、购买结果协调、本地金币购买编排和 session 状态更新拆开；当前 `Purchase.lua` 与 `MarketChoiceHandler.lua` 只保留薄编排职责，不再要求继续细切才能证明边界收口。
- [x] (2026-03-07 03:07 +0800) 已把 `Purchase.execute()` 的本地金币购买分支外提到 `src/game/systems/market/service/LocalPurchase.lua`，并把 `MarketChoiceHandler` 的购买结果协调外提到 `src/game/systems/market/service/ChoiceOutcome.lua`；`Purchase.lua` 与 `MarketChoiceHandler.lua` 继续向纯编排器收缩。
- [x] (2026-03-07 00:04 +0800) 已完成阶段4第七刀：新增 `src/game/systems/market/service/ChoiceSession.lua`，把 `rebuild_pending()`、`apply_navigation()`、`refresh_after_paid_callback()` 从 `Choice.lua` 中移走；`Choice.lua` 现只保留 market choice builder，`MarketService`、`ChoiceOutcome`、`PaidFulfillment` 已改接 session service，并新增 market 定向测试验证“build 保持纯函数，session 才负责 dirty/pending 更新”。
- [x] (2026-03-07 01:27 +0800) 已启动阶段5第一刀：`src/game/systems/market/service/Choice.lua` 现在给 option 输出 `requires_pre_confirm/pre_confirm_kind`，`PreConfirmFlow.lua` 不再回查 `Config.Generated.Market` 判断皮肤商品，而是只消费用例层提供的 option 级确认语义；已补 `market` 与 `presentation_ui` 回归，验证“有 flag 才进二次确认，没有 flag 即使 product_id 像皮肤也直接派发”。
- [x] (2026-03-07 01:43 +0800) 已完成阶段5第二刀：`choice_screen_service.common` 现在优先消费 `option.confirm_title/confirm_body` 与 `choice.confirm_title/confirm_body`；`ItemPhase` 已同时为 choice 本身和每个 item option 产出确认文案，`LandChoiceSpecs.tax_prompt`、`EffectPipeline` 的 landing optional choice、market skin option 也都直接产出确认文案，presentation 仅保留 fallback 兼容逻辑。
- [x] (2026-03-07 02:02 +0800) 已完成阶段5第三刀的第一小片：`ItemPhase.build_choice_spec()` 现在额外输出 `uses_item_slots/pre_confirm_before_slot_pick`；`PreConfirmFlow`、`ItemPhaseAskFlow`、`UIModalPresenter`、`item_slots`、`item_slot_intents` 已优先消费这些显式语义，`choice.kind == "item_phase_choice"` 的散落判断被收敛到 `choice_screen_service.common` helper 中保底兼容。
- [x] (2026-03-07 02:10 +0800) 已完成阶段5第三刀的第二小片：`presentation_ui` 里的手工 `item_phase_choice` 测试数据已补齐显式 flag 与确认文案，`choice_screen_service.common` 已移除 `item_phase_choice` 的 `kind`-fallback 与旧确认文案推导，只保留显式字段路径。
- [x] (2026-03-07 02:18 +0800) 已完成阶段5第三刀的第三小片：`presentation_ui` 里的手工 `tax_card_prompt`、`landing_optional_effect` choice 也已补齐 `confirm_*` 字段，`choice_screen_service.common` 不再为 tax 和 buy/upgrade land 推导默认确认文案，确认 UI 全部优先消费用例层显式输出。
- [x] (2026-03-07 02:27 +0800) 已完成阶段5第四刀的第一小片：`LandChoiceSpecs.tax_prompt()` 与 `EffectPipeline` 生成的纯 buy/upgrade land optional choice 已显式输出 `route_key=\"secondary_confirm\"` 与 `requires_confirm=true`；`ChoiceRoutePolicy` 已移除对 `tax_card_prompt` 和 `buy_land/upgrade_land` 的 secondary-confirm 推断，presentation route 开始只消费用例层声明。
- [x] (2026-03-07 02:36 +0800) 已完成阶段5第四刀的第二小片：`ItemHandlers`、`ItemDemolish`、`market/service/Choice` 已分别为 `item_target_player`、`remote_dice_value`、`roadblock_target`、`demolish_target`、`market_buy` 显式输出 `route_key`；`ChoiceRoutePolicy` 已移除这些 kind 的默认 route 推断，`remote/player/target/market` 路由开始统一由 use-case 输出声明。
- [x] (2026-03-07 02:49 +0800) 已完成阶段5第四刀的第三小片：`LandChoiceSpecs.build_use_skip()` 现默认显式输出 `route_key=\"base_inline\"` 与 `requires_confirm=false`，`item_phase_choice` 的手工测试 choice 也已补齐 `route_key=\"base_inline\"`；`ChoiceRoutePolicy` 已不再为 `item_phase_choice` 特判 base-inline，当前只保留真正未知 choice 的 fallback。
- [x] (2026-03-07 00:39 +0800) 已完成阶段5收尾：`IntentDispatcher.open_choice()`、`UIChoice.build_choice_view()` 现在会把 `owner_role_id`、`confirm_*`、item-slot flag、target-picker flag、market 分页状态等显式字段贯通到 `pending_choice` 与 `ui_model.choice`；`PreConfirmFlow` 改成按显式 route 判断 market，`ChoiceSlice` / `MarketModalRenderer` / `ItemSlice` / `TargetChoiceEffects` 已删除对 `choice.kind/meta` 的业务推断，只消费 use-case 声明的稳定字段。
- [x] (2026-03-07 00:39 +0800) 已完成阶段6：新增 `docs/architecture/directory_semantics.md`，把 `src/app`、`src/core`、`src/game/flow`、`src/game/systems`、`src/game/runtime`、`src/presentation`、`src/presentation/read_model` 的职责边界写成仓库内导读；本阶段未夹带行为改动，只补目录语义与后续放置规则。

## 意外与发现

- 观察：仓库此前没有任何现成的 CI 配置文件，阶段0若只改本地脚本，守护无法变成团队级约束。
  证据：仓库根目录原先不存在 `.github/workflows/*`，本次新增了 `.github/workflows/regression.yml`。

- 观察：如果直接把研究报告里的边界规则改成“零容忍”，当前代码会立刻失败，因为存量债务还没有迁完。
  证据：真实代码基线是 `src/core` 宿主全局 API 触点 47 处，`game.ui_port` 依赖点 23 处，`src/game/flow` 中 `state.ui_*` 写入 13 处。

- 观察：`GameplayLoop.set_game` 触发的初始化会顺带安装市场支付映射，因此即便只跑守护契约测试，也会看到既有的 `market paid goods mapping missing` 告警。
  证据：定向运行 `architecture_guard_contract` 时，最终通过，但终端仍打印现有 market 告警。

- 观察：全量回归目前在本机的默认模式是 `release_trimmed`，因此阶段0验收输出是 `All regression checks passed (364)`，不是研究报告里的旧数字。
  证据：`lua tests/regression.lua` 开头打印 `[regression] mode=release_trimmed`，结尾打印 `All regression checks passed (364)`。

- 观察：阶段1落地后，`src/game/flow` 里的 `state.ui_*` 直写已经清零，但为了不同时打断 presentation 和旧测试，仍需要在 `RuntimeState.ensure_ui_runtime(state)` 中保留一层镜像缓存。
  证据：`rg -n "state\\.(ui_[A-Za-z0-9_]+|pending_choice(?:_[A-Za-z0-9_]+)?|ui_model)\\s*=" src/game/flow` 已无命中；`src/core/RuntimeState.lua` 现在会初始化 `ui_runtime.ui_dirty/ui_model/pending_choice/ui_modal_*`。

- 观察：仓库内置的 `forbidden_globals` 守护会拒绝 `rawget`，即便它只是为了绕开 metatable 观测；因此兼容层读取必须退回普通字段访问。
  证据：第一次阶段1回归在 `src/game/flow/ports/UseCaseOutputPort.lua` 上报 `forbidden_globals ... uses rawget`，改回 `state[key]` 后恢复通过。

- 观察：测试支撑默认会给 `support.new_game()` 预装一个 `ui_port`，如果阶段2最后一刀继续在生产代码里显式清空这个字段，静态守护仍会把它算作“还在碰旧边界”。
  证据：本轮第一次全量回归在 `tests/internal/dep_rules.lua` 报 `src/game/flow/turn/GameplayLoop.lua` 仍命中 `game.ui_port`；改成让测试支撑通过 `install_ui_port = false` 显式选择旧桥后，预算恢复为 0 且全量继续通过。

- 观察：`Choice.lua` 一旦同时承担 builder 与 pending-choice 更新，最容易让后续调用方继续把“输出模型构造”和“运行时状态变更”混为同一职责；但这两类行为在测试层的验证方式完全不同。
  证据：本轮把 `rebuild_pending/apply_navigation/refresh_after_paid_callback` 移到 `ChoiceSession.lua` 后，新增的 market 定向测试可以单独证明 `build()` 不会碰 `game.dirty`，而 session 调用才会标记 `dirty.turn/dirty.any`；`market` 定向回归提升到 `All regression checks passed (15)`，全量提升到 `All regression checks passed (376)`。

- 观察：阶段2最窄的突破口确实是动画等待门控，因为 `TurnRoll`、`TurnMove` 和 `ActionAnimPort` 都只需要只读布尔配置，不依赖 popup 或 choice 语义。
  证据：迁出这三处后，`tests/internal/dep_rules.lua` 中 `src/core/ActionAnimPort.lua`、`src/game/flow/turn/TurnMove.lua`、`src/game/flow/turn/TurnRoll.lua` 的 `game.ui_port` 预算均已降为 0，同时新增契约测试仍可在 `game.ui_port = nil` 时通过。

- 观察：`TurnDecision` 里的 `ui_port.state` 回读其实比 popup 链路更适合先拔，因为它只是在 coroutine `wait_choice` 上借道 UI runtime 取 elapsed，不涉及任何渲染或广播副作用。
  证据：把 `wait_choice` elapsed 改成由 runtime coroutine session 显式持有并传给 `TurnDecision.decide_choice_action()` 后，`TurnDecision.lua` 的 `game.ui_port/ui_port.state` 命中可以直接归零，而 `gameplay/gameplay_coroutine` 与全量回归继续通过。

- 观察：`IntentDispatcher.push_popup()` 虽然是阶段2剩余里最容易下手的一条 `game.ui_port` 读路径，但测试和若干非 `GameplayLoop.set_game` 入口并不会自动得到新端口，所以必须同时补一层兼容镜像，否则会把大量老测试一次性打碎。
  证据：第一次把 `push_popup` 直接切到 `game.popup_port` 后，`landing`、`item`、`gameplay` 多个套件都因 `missing popup_port` 失败；给 `Game:ensure_popup_port()` 和 `TestSupport.new_game()` 补兼容镜像后，同一改法重新通过定向和全量回归。

- 观察：一旦 `IntentDispatcher` 切到 `popup_port`，最值得顺手继续迁的不是 `ItemPhase` 这种混着交互语义的模块，而是 `Bankruptcy`、`LandingPresenter`、`ItemInventory`、`ItemUseBroadcast` 这种只负责发 popup 的单用途适配器。
  证据：这四个模块只需要从 `game.ui_port.push_popup` 改成 `popup_port`/兼容桥，不涉及 choice、动画或 UI 状态读回；迁出后对应 `dep_rules` 预算可以直接降到 0，且 `item/landing/gameplay` 定向回归与全量回归继续通过。

- 观察：`ItemPhase` 的那条 `assert(game.ui_port ~= nil)` 并不是真正的运行时需求，而是旧架构时期留下的“人类回合一定有 UI”防御式假设；在 choice 输出已经端口化后，这条断言只会制造虚假耦合。
  证据：删除断言并把 `dep_rules` 预算收紧到 0 后，`item/gameplay/gameplay_coroutine` 定向回归与全量回归继续通过，说明 `ItemPhase` 本身并不依赖 `ui_port` 才能构建 choice。

- 观察：`BaseLandEffects` 的 `on_tile_upgraded` 直推和 `popup_port` 改造是同一种单用途适配器问题，适合沿用同样的“专用端口 + 兼容桥”策略，而没必要把它强行并进更大的 state port 设计。
  证据：给 `GameplayLoopRuntime` 增加 `tile_feedback_port`、给 `Game` 增加 `ensure_tile_feedback_port()` 后，`BaseLandEffects` 去掉 `ui_port.on_tile_upgraded` 直推，`landing/gameplay` 定向回归与全量回归都继续通过，预算也能直接收紧到 0。

- 观察：阶段3把 `DefaultPorts` 改成只认 `runtime_context.current().env` 后，最容易出问题的不是业务逻辑，而是那些自己 patch 全局、却不会同步重建 runtime context 的测试 helper。
  证据：`presentation_ui_action_anim` 的本地 `_with_patches` 与 `TestSupport` 都需要补“重建 runtime context + 接线 logger/scheduler”的逻辑，回归才重新稳定。

- 观察：一旦把运行时默认实现改成“只认 context env”，阶段3真正的回归成本主要落在测试基础设施，而不是业务代码。
  证据：`RuntimeContext`、`RuntimeGlobalAliases`、`DefaultPorts` 的生产改动完成后，实际回归失败集中在 `TestSupport` 和 `presentation_ui_action_anim` 的 patch helper；补完测试态 alias/runtime context 重建后，全量再次通过。

- 观察：阶段4若想最小风险落地，应该先拆 paid-currency 的宿主购买通道，而不是先碰 market choice 刷新或本地金币购买兑现。
  证据：把 `Purchase.lua` 的 goods mapping、purchase panel 启动、待兑现队列、trigger callback 注册移入 `PaidPurchaseGateway.lua` 后，`paid_currency`、`market` 和全量回归都保持通过，而 `_fulfill_paid_goods_purchase` 与 `_refresh_market_choice_after_paid_callback` 无需同批重写。

- 观察：`PaidPurchaseGateway` 这种被测试频繁热重载的 adapter，不能在模块级缓存 `Context` 这类同样会被热重载的依赖，否则会出现“单条复现正常、整组回归失败”的隐蔽问题。
  证据：第一次阶段4回归里，单独复现 paid callback 能正常兑现，但 `paid_currency`/`market` 套件批量运行失败；把 gateway 改成按调用时 `require("...Context")` 后恢复通过。

- 观察：`Purchase.lua` 的 item/vehicle/skin 分支在 paid callback 和本地即时购买两条路径里重复承载了同一种兑现副作用，这种重复会拖慢后续任何一侧的边界收口。
  证据：在抽出 `Fulfillment.lua` 前，`_fulfill_paid_goods_purchase()` 与 `execute()` 的本地购买分支都各自处理 inventory、seat、skin helper、action anim、market 事件；改成复用 `Fulfillment.apply()` 后，`paid_currency`、`market` 和全量回归都保持通过。

- 观察：`Purchase.lua` 在兑现逻辑被抽走后，剩下最明显的混合职责就变成“前置可买性校验 + 座驾替换确认 intent 组装”，它们更接近应用决策而不是购买执行。
  证据：把这些逻辑抽到 `PurchasePolicy.lua` 后，`Purchase.lua` 中与 `market_vehicle_replace`、`vehicle_disabled`、`sold_out`、`disabled` 相关的字符串与 choice spec 构造显著减少，而 `market`、`paid_currency` 与全量回归继续通过。

- 观察：随着 `Purchase.lua` 本身逐步变薄，market 购买链路里下一处最明显的混合职责已经从 purchase service 转移到了 `MarketChoiceHandler.lua`，也就是“根据购买结果决定刷新 market、弹满包提示、派发 follow-up intent 还是关闭 choice”。
  证据：在第六刀前，这些分支集中在 `MarketChoiceHandler._handle_market_buy()`；抽成 `ChoiceOutcome.resolve_purchase()` 后，`paid_currency`、`market` 和全量回归继续通过，说明这层结果协调可以独立存在而不需要继续绑在 choice handler 上。

- 观察：如果 `PreConfirmFlow` 继续根据 `Config.Generated.Market` 和 `product_id` 自己判断“这是不是皮肤”，presentation 就会把业务分类知识重新缓存一份，和 use-case 输出形成双轨语义。
  证据：阶段5第一刀前，`src/presentation/interaction/ui_intent_dispatcher/PreConfirmFlow.lua` 会在模块加载时扫描 `Config.Generated.Market` 建 `market_kind_by_product_id`；改成读取 choice option 上的 `requires_pre_confirm` 后，新增回归可以证明 `option_id=5001` 但缺 flag 时会直接派发，不再被 presentation 私自拦截。

- 观察：把确认文案继续留在 `choice_screen_service.common` 里按 `choice.kind/option_id` 现算，会让 presentation 同时持有“何时确认”和“确认说什么”两套应用语义；而这两套语义其实都能稳定地跟着 choice/option 一起输出。
  证据：阶段5第二刀后，`market`、`land`、`item` 测试都能直接断言 choice/option 上存在 `confirm_title/confirm_body`，而 `presentation_ui` 仍通过同样的文案断言，说明渲染结果没有变化但责任已经前移。

- 观察：`item_phase_choice` 在 presentation 层的特殊处理不只是一两个入口，而是横跨 modal 打开、slot click、outline 高亮和 ask-flow 快捷分支；如果直接全删 `choice.kind` 判断，测试里构造的简化 choice 会大面积失效。
  证据：阶段5第三刀扫描命中显示 `UIModalPresenter`、`ItemPhaseAskFlow`、`item_slots`、`item_slot_intents` 都依赖这条判断；本轮先把生产路径改成输出 `uses_item_slots/pre_confirm_before_slot_pick`，再把老判断收进 helper 做兼容，定向与全量回归仍保持通过。

- 观察：一旦生产 builder 已稳定输出显式 flag，阻碍继续删 fallback 的主要来源就不再是生产代码，而是 `presentation_ui` 这类手工构造 choice 的测试数据。
  证据：本轮实际只改了 `choice_screen_service.common` 与 `tests/suites/presentation_ui.lua`；补齐测试 choice 上的 `uses_item_slots/pre_confirm_before_slot_pick/confirm_*` 后，删除 `item_phase_choice` 的 helper fallback 仍能通过定向回归。

- 观察：`tax_card_prompt` 与 `landing_optional_effect` 的确认文案 fallback 也已经进入同样状态，真正依赖旧分支的同样只剩手工 choice 测试，而不是生产 builder。
  证据：`LandChoiceSpecs.tax_prompt()` 与 `EffectPipeline` 早已输出 `confirm_title/confirm_body`；本轮把 `presentation_ui` 中的手工 tax/landing choice 补齐这些字段后，删除 common 里的对应 fallback，定向回归继续通过。

- 观察：secondary-confirm 路由推断和确认文案推断是同一类问题的两半，如果只前移文案而保留 route 推断，presentation 仍然在暗中持有“哪些 choice 应该走二次确认”的业务知识。
  证据：`ChoiceRoutePolicy` 在本轮前仍根据 `tax_card_prompt` 和 `landing_optional_effect + buy_land/upgrade_land` 推断 `secondary_confirm`；让 builder 显式输出 `route_key/requires_confirm` 后，删掉这些推断分支，`item/land/presentation_ui/gameplay` 定向回归与全量回归都继续通过。

- 观察：当 `secondary_confirm` 已经显式化后，`ChoiceRoutePolicy` 里剩余的 `remote/player/target/market` kind 推断也不再有结构性理由继续存在，因为这些选择同样都来自稳定 builder，而不是临时拼接。
  证据：本轮为 `ItemHandlers`、`ItemDemolish`、market choice builder 补上 `route_key` 后，删除 policy 对 `remote_dice_value`、`item_target_player`、`roadblock_target`、`demolish_target`、`market_buy` 的 route 推断，`item/land/presentation_ui/gameplay/market` 定向回归与全量回归都继续通过。

- 观察：在 `remote/player/target/market/secondary_confirm` 都显式化后，`ChoiceRoutePolicy` 中最后一个“看起来 harmless 的默认值”其实是 `item_phase_choice -> base_inline`；但它和 `steal_prompt` 这类 `build_use_skip()` choice 一样，本质上也只是 builder 没声明 route。
  证据：给 `LandChoiceSpecs.build_use_skip()` 加上显式 `base_inline`，并把手工 `item_phase_choice` 测试 choice 补齐 `route_key` 后，`ChoiceRoutePolicy` 删掉 `item_phase_choice` 特判仍能通过定向与全量回归，日志里只剩 `unknown_choice_kind` 的预期 fallback。

## 决策日志

- 决策：阶段0采用“衰减式基线”而不是“立即清零”的静态规则。
  理由：`src/core`、`game.ui_port`、`state.ui_*` 都还有存量违规点；阶段0目标是先停止债务增长，而不是在没有完成阶段1到阶段3前让仓库无法通过回归。
  日期/作者：2026-03-06 / Codex

- 决策：动态守护单独放在 `tests/suites/architecture_guard_contract.lua`，不塞进玩法 suite。
  理由：阶段0关注的是边界契约，不是玩法结果。独立 suite 更容易在阶段1到阶段3逐步替换、扩展和定位失败原因。
  日期/作者：2026-03-06 / Codex

- 决策：CI 直接运行现有统一入口 `lua tests/regression.lua`。
  理由：`tests/regression.lua` 已经串联了 suites、`dep_rules`、`tick`、`forbidden_globals`，用一个入口最不容易出现“本地和 CI 跑的不是同一套东西”。
  日期/作者：2026-03-06 / Codex

- 决策：阶段1优先收口 `GameplayLoop`、`TurnDispatch` 和 `TickTimeout`，不先动 Market 或 presentation 细节。
  理由：`state.ui_*` 写入最集中、最影响后续所有边界，如果不先把输出协议定下来，阶段2到阶段5都会继续围着共享状态打补丁。
  日期/作者：2026-03-06 / Codex

- 决策：阶段1的 output port 采用“显式端口 + 兼容镜像”而不是一次性删除 legacy state 字段。
  理由：`presentation`、倒计时和部分旧测试仍要读取 `state.ui_model`、`pending_choice*` 的镜像；先用 `UseCaseOutputPort` 统一写入口，再逐步缩减读取面，风险比一次性断掉共享字段低得多。
  日期/作者：2026-03-06 / Codex

- 决策：阶段2先引入 `game.anim_gate_port`，而不是继续扩 `game.ui_port` 或一次性设计完整 NotificationPort。
  理由：`wait_action_anim / wait_move_anim` 是最纯粹的只读布尔门控，先拆这条路径可以立即压缩 `game.ui_port` 预算，又不会卷入 popup、market 和 `ui_port.state` 这类更复杂的反向读依赖。
  日期/作者：2026-03-06 / Codex

- 决策：阶段3对 `src/core` 采用两种收口模式并存，按模块职责选择最小方案。
  理由：`Logger` 更适合 host hook 注入，因为它只需要提示、调度和时间格式化；`DefaultPorts` 更适合显式读取 `runtime_context.current().env`，因为它本来就是 runtime port 默认实现。这比强行把所有模块做成同一种模板更稳。
  日期/作者：2026-03-06 / Codex

- 决策：`RuntimeEnvBindings` 不在 `src/core` 内继续保留兼容壳，直接改名外迁为 `src/app/bootstrap/runtime_install/RuntimeGlobalAliases.lua`。
  理由：这段逻辑的唯一职责就是把宿主对象安装成全局别名；继续留在 `src/core` 只会让目录语义继续失真。真实启动路径和测试都可以显式调用外层安装器，没必要保留 core 包装层。
  日期/作者：2026-03-07 / Codex

- 决策：阶段4第一刀新增 `PaidPurchaseGateway.lua`，但不同时改本地即时兑现与 choice 刷新。
  理由：宿主支付通道与回调桥是最脏的跨层细节，且能与 `_fulfill_paid_goods_purchase` 清晰切分；先拆这组职责可以显著收口 `Purchase.lua`，又不会一次性把 market 购买用例、UI 刷新和支付兑现混成大重构。
  日期/作者：2026-03-07 / Codex

- 决策：阶段4第二刀先把 `_refresh_market_choice_after_paid_callback` 挪到 `Choice.lua`，而不是继续把更多本地购买分支抽走。
  理由：这个职责本质上是 market choice adapter 的重建与刷新，靠近 `Choice.rebuild_pending()` 更自然；同时它能在不改变购买兑现语义的前提下，继续减轻 `Purchase.lua` 的跨层职责密度。
  日期/作者：2026-03-07 / Codex

- 决策：阶段4第三刀新增 `Fulfillment.lua`，让 paid callback 和本地即时购买共用一套兑现副作用实现。
  理由：兑现副作用本身不关心触发来源，只关心 entry/player/game 和是否需要 charge。把它们抽成独立 service 后，`Purchase.lua` 不再需要同时维护两套 item/vehicle/skin 兑现分支，也更容易继续把前置验证与 UI 协调拆走。
  日期/作者：2026-03-07 / Codex

- 决策：阶段4第四刀新增 `PurchasePolicy.lua`，承接可买性校验与 vehicle replace intent。
  理由：这两类逻辑都属于“购买前的应用决策”，和宿主支付、兑现副作用、choice 刷新是不同层面的职责。先把它们移走，可以进一步把 `Purchase.lua` 压缩成单纯的 orchestration service。
  日期/作者：2026-03-07 / Codex

- 决策：阶段4第五刀先抽 `Feedback.lua`，阶段5第一刀再让 market choice option 显式声明 `requires_pre_confirm`，而不是直接继续大拆 `PreConfirmFlow` 的所有分支。
  理由：`buy_failed` 事件出口本身仍是 `Purchase.lua`/`Choice.lua` 中重复出现的横切关注点，先抽它可以继续瘦身 market service；随后只对 market choice 的二次确认语义做一刀 option 级显式化，就能以最小改动把一个明确的 presentation 业务判断回收到用例输出，避免阶段5一开始就把 item/land/tax 等所有确认分支绑成大提交。
  日期/作者：2026-03-07 / Codex

- 决策：阶段4第六刀先抽 `ChoiceOutcome.lua`，承接 `MarketChoiceHandler` 里的购买结果协调，而不是继续把更多本地购买判断塞回 `Purchase.lua`。
  理由：`Purchase.lua` 经过前五刀后已经基本只剩购买前后编排；反而 `MarketChoiceHandler` 还同时负责输入解码和结果后处理。把 stay/finish、choice rebuild、满包 popup、follow-up intent 派发抽成独立 service，可以继续压缩 market 事务脚本的横向职责面，而且不必重新打开 payment/fulfillment 那些已稳定的边界。
  日期/作者：2026-03-07 / Codex

- 决策：阶段2当前优先清 `TurnDecision` 的 `ui_port.state` 反读，而不是直接去拔 popup 链路。
  理由：这条依赖只影响 coroutine `wait_choice` 的 elapsed 读取，改成 session 显式持有后几乎不碰渲染、副作用和旧 UI 契约；相比之下 `push_popup` 链路横跨 `IntentDispatcher`、`LandingPresenter`、`Bankruptcy`、道具广播，风险明显更高，适合放到后面单独切。
  日期/作者：2026-03-07 / Codex

- 决策：阶段2接下来先从 `IntentDispatcher.push_popup()` 切出 `popup_port`，并显式保留 `Game:ensure_popup_port()` 兼容桥，而不是等整条 popup 链全改完再统一落地。
  理由：`IntentDispatcher` 是 popup 广播链路里最中心、最容易量化收益的一处依赖点；先把它从 `game.ui_port` 脱开，可以立刻压缩预算并验证专用 popup 端口方向是否成立。兼容桥虽然是过渡层，但它比一次性要求所有旧测试和旧入口同步接线更稳。
  日期/作者：2026-03-07 / Codex

- 决策：`popup_port` 落地后，优先继续迁移只负责发 popup 的单用途适配器，而不是马上碰 `ItemPhase` 或 `BaseLandEffects` 这种混合模块。
  理由：单用途适配器的迁移收益明确、测试面窄，而且不会把 popup 端口改造和其它业务判断绑在一个提交里。先把这些低风险收益收完，再去处理剩余高耦合点更稳。
  日期/作者：2026-03-07 / Codex

- 决策：在单用途 popup 适配器迁完后，顺手删掉 `ItemPhase` 的 `ui_port` 断言并收紧预算，而不是把它留到更晚再清。
  理由：这不是新的端口设计问题，只是一条已经失去作用的旧防御式假设。既然它不牵涉行为改动，应该尽早从预算账本里抹掉，避免后续阶段2盘点时继续把它当成真实剩余债务。
  日期/作者：2026-03-07 / Codex

- 决策：`BaseLandEffects` 的升级通知采用 `tile_feedback_port`/兼容桥，而不是直接塞进已有 `popup_port` 或临时继续走事件桥。
  理由：升级地块通知和 popup 是不同语义，混到一个端口会让接口变脏；而直接只走事件桥又会失去当前“优先直推、失败再广播”的优化。单独的 `tile_feedback_port` 能最小成本保持原行为，同时把 `ui_port` 读依赖继续压缩。
  日期/作者：2026-03-07 / Codex

- 决策：阶段5第二刀不新建“ConfirmViewModel”模块，先直接把 `confirm_title/confirm_body` 字段并入现有 choice/option 结构。
  理由：当前确认语义已经通过 `choice` 和 `option` 跨层传递，增加一层新 DTO 只会扩大改动面。先用兼容字段把 `ItemPhase`、`tax_prompt`、`landing_optional_effect`、market skin 的确认文案前移，能更快验证“presentation 只消费输出”这条方向，并保留 fallback 让旧 choice 不会一次性全坏。
  日期/作者：2026-03-07 / Codex

- 决策：阶段5第三刀先把 `item_phase_choice` 的 slot 交互语义抽成 `uses_item_slots/pre_confirm_before_slot_pick` 两个显式字段，并在 presentation 侧通过 helper 消费，而不是立刻删除所有 `choice.kind == "item_phase_choice"` fallback。
  理由：这条语义同时影响 modal、item slot、highlight 动画和 ask-flow；先让生产 builder 稳定产出显式标记，再把消费方统一到 helper，上层责任已经前移，但测试和旧手工 choice 仍能兼容运行。这样下一刀才能更安全地继续删 fallback。
  日期/作者：2026-03-07 / Codex

- 决策：阶段2最后一刀选择引入 `board_scene_port`，而不是继续保留一个“裁剪后的 ui_port DTO”。
  理由：到这一步，`push_popup`、`tile owner changed`、`tile upgraded`、动画门控都已经各自有专用端口；继续保留 `ui_port` 只会把已经拆开的职责重新捆回共享对象图。`board_scene_port` 只暴露 bankruptcy 清理所需的 scene getter，更符合阶段2“按专用端口收口”的方向。
  日期/作者：2026-03-07 / Codex

- 决策：阶段4下一刀优先拆 `Choice.lua` 里的 pending-choice session 更新，而不是继续追打 `Purchase.lua` 的本地金币分支。
  理由：`Purchase.lua` 经过前几刀后已经接近纯编排器，而 `Choice.lua` 还同时承担输出模型构造、pending_choice 原地更新、tab/page 导航和 paid callback 后刷新。先把这些运行时更新移到 `ChoiceSession.lua`，能更干净地区分“纯 builder”和“状态适配器”，也为后续阶段5继续压缩 market / target choice 语义提供更稳的边界。
  日期/作者：2026-03-07 / Codex

- 决策：阶段5第三刀的第二小片优先删 `choice_screen_service.common` 中 `item_phase_choice` 的 helper fallback，而不是继续新增更多 helper 包装。
  理由：生产路径和主要消费点已经全部接上显式字段；继续保留 `kind`-fallback 只会拖慢真正的边界收口。测试数据补齐后，这条 fallback 已经没有必要继续存在。
  日期/作者：2026-03-07 / Codex

- 决策：阶段5第三刀的第三小片继续沿同一路径删除 `tax_card_prompt` 和 `buy_land/upgrade_land` 的确认文案 fallback，而不是在 common 中保留“最后几条默认文案”。
  理由：一旦确认文案还留在 presentation fallback 里，责任边界就仍旧不干净。既然生产 builder 和关键测试都能改成显式字段，就应该继续把 common 收缩成纯消费层。
  日期/作者：2026-03-07 / Codex

- 决策：阶段5第四刀先处理 secondary-confirm 路由显式化，而不是先去碰 `ChoiceRoutePolicy` 里其它 route fallback。
  理由：`secondary_confirm` 是阶段5当前最典型的 presentation 应用规则泄漏点，而且 tax 与 landing optional 的生产 builder 已经非常接近显式声明，改动最小、收益最高。先收这条路由语义，比同时重做 remote/player/target 的 route 判定更稳。
  日期/作者：2026-03-07 / Codex

- 决策：阶段5第四刀第二小片继续把 `remote/player/target/market` 路由也改成 builder 显式输出，而不是在 `ChoiceRoutePolicy` 中保留“这些只是 harmless 默认值”的例外。
  理由：这些 route 同样属于 presentation 适配知识，只是之前看起来更“无害”。既然相关 choice 都由稳定 builder 生成，继续依赖 kind 推断只会让 route 语义继续分散在 policy 中，不利于把 presentation 压成纯消费层。
  日期/作者：2026-03-07 / Codex

- 决策：阶段5第四刀第三小片优先把 `build_use_skip()` 和 `item_phase_choice` 的 base-inline 路由也显式化，而不是保留一个“默认 inline choice”例外。
  理由：一旦其余 route 都靠显式字段声明，保留 `item_phase_choice` 特判只会让 `ChoiceRoutePolicy` 继续知道业务 kind。把 `base_inline` 也改成输出层声明后，policy 就只剩未知 choice 的兜底职责，职责边界更干净。
  日期/作者：2026-03-07 / Codex

- 决策：choice 的显式 presentation 协议必须由 `IntentDispatcher.open_choice()` 一次性复制进 `pending_choice`，不能只停留在 `choice_spec`。
  理由：如果运行时态看不到这些字段，presentation 层最终仍会退回 `kind/meta` 推断；真正的边界收口要保证“use case 定义了什么，运行时就持有什么”。
  日期/作者：2026-03-07 / Codex

- 决策：target picker 采用 `route_key="target" + uses_target_picker + target_picker_owner_role_id` 这组显式语义，而不是继续让 UI 根据 `roadblock_target/demolish_target` 和 `meta.player_id` 猜行为。
  理由：`route_key` 只能说明打开哪个 screen，不能说明这个 screen 是否需要场景拾取和归属角色约束；把这两层语义显式拆开后，presentation 才能稳定复用而不沦为业务解释器。
  日期/作者：2026-03-07 / Codex

- 决策：阶段6先补 `docs/architecture/boundaries.md`，暂不立刻做目录重命名。
  理由：当前边界虽然稳定，但重命名会引入大量 `require` 路径噪音；先把目录职责和禁止事项写成仓库内导读，可以在不混入行为风险的前提下完成语义收尾。
  日期/作者：2026-03-07 / Codex

## 结果与复盘

阶段0到阶段6现在已经全部完成。当前最重要的可观察结果有八条。第一，`src/game/flow` 已经没有任何直接的 `state.ui_*` 写入；用例层通过 `UseCaseOutputPort` 发出 UI 失效、choice 生命周期和 modal timer 输出。第二，`game.ui_port` 预算已经压到 0；动画等待改走 `anim_gate_port`，popup 改走 `popup_port`，地块升级通知改走 `tile_feedback_port`，tile owner 变更改走 `tile_owner_notifier`，board scene 读取收窄成 `board_scene_port`。第三，`src/core` 已经不再直接认识 Eggy 宿主全局，运行时安装器与默认端口实现已迁到外层 bootstrap / runtime context。第四，Market 购买链路已经稳定分拆：`Purchase.lua` 只保留编排，`LocalPurchase.lua`、`PaidPurchaseGateway.lua`、`PaidFulfillment.lua`、`PurchasePolicy.lua`、`Feedback.lua`、`ChoiceOutcome.lua`、`ChoiceSession.lua` 分别承接本地购买、支付桥接、兑现、资格校验、失败反馈、购买后续动作和 session 刷新。第五，choice 稳定协议已经真正落进 `pending_choice`：`IntentDispatcher.open_choice()` 会保留 `owner_role_id`、确认文案、item-slot 语义、target-picker 语义和 market 分页字段，presentation 不再被迫回头解析 `choice_spec.meta`。第六，`PreConfirmFlow`、`ChoiceSlice`、`UIChoice`、`TargetChoiceEffects`、`ChoiceSession` 现在优先消费显式字段；target/market 关键交互已经不再依赖 `choice.kind/meta` 推断核心 UI 语义。第七，`docs/architecture/boundaries.md` 已把目录职责和禁止跨层访问写成仓库内导读，后续维护者不用再从提交历史反推这些边界。第八，默认回归、定向 `market`、定向 `presentation_ui` 与 `dep_rules` 全部通过，并把这次收口锁住。

这轮推进留下三条直接经验。第一，真正稳定的 presentation 重构，关键不在 UI 层删多少 `if choice.kind`，而在 use case 层是否把稳定协议完整带进 `pending_choice`。第二，target picker 这类“看起来只是 route”的交互，仍然需要显式 owner/feature flag；否则 UI 只能退回 `meta` 和 `kind` 猜业务。第三，阶段6最稳妥的做法不是立刻改目录名，而是先把目录职责、禁止事项和 choice 协议写成仓库内文档；这样下一次再做重命名时，行为边界已经有文字锚点，不会把整理命名和重新设计行为混成一次风险提交。

## 背景与导读

如果你第一次进入这个仓库，只需要先理解五组文件。

第一组是当前的研究结论，位于 `.agents/research.md`。它给出的核心判断是：这个仓库已经有了正确的分层骨架，但三个边界仍在泄漏。第一，`src/core` 仍直接认识 Eggy 宿主全局，如 `GameAPI`、`GlobalAPI`、`SetTimeOut`。第二，`src/game` 仍通过 `game.ui_port` 读取动画等待、弹窗和 UI 状态。第三，`src/game/flow` 仍直接写 `state.ui_dirty`、`state.ui_model`、`state.ui_modal_elapsed` 这类 UI 协调字段。

第二组是阶段0的静态守护文件，位于 `tests/internal/dep_rules.lua`。它原本只负责一些禁止 require 和禁止旧桥接路径的检查；现在还承担“冻结当前债务规模”的职责。这里的“衰减式基线”意思是：允许已有债务继续存在，但不允许增长；如果债务减少，就必须同步收紧基线，让文件重新回到“精确描述当前剩余债务”的状态。

第三组是阶段0的动态守护文件，位于 `tests/suites/architecture_guard_contract.lua`。它做两件事。第一，验证 `src/game/flow/turn/GameplayLoop.lua` 在 `set_game` 时给 `game` 注入的是经过裁剪的运行时 `ui_port` DTO，而不是把整个 `state` 原样挂出去。第二，给 `src/game/flow/turn/TurnDispatch.lua` 包一层 `__newindex` 拦截，确认关键输入路径只会发出 `ui_dirty` 这种粗粒度失效信号，而不会再静默写出新的 `state.ui_*` 字段。

第四组是阶段0之后最先要动的用例层文件。`src/game/flow/turn/GameplayLoop.lua` 负责主循环和初始化，`src/game/flow/turn/TurnDispatch.lua` 负责玩家输入落地，`src/game/flow/turn/TickTimeout.lua` 负责倒计时和弹窗超时，`src/game/flow/intent/IntentDispatcher.lua` 负责用例层向 UI 发出选择与弹窗意图。阶段1必须先把这几处对 UI 状态的直接读写抽到稳定端口上。

第五组是运行和验证入口。`tests/regression.lua` 是本地与 CI 的统一回归脚本；`.github/workflows/regression.yml` 是本次新增的 CI 接线。只要阶段1到阶段6仍沿用这条入口，守护就不会失效。

## 里程碑 0：架构守护（已完成）

这个里程碑的目标不是“把边界修好”，而是“停止继续变坏”。完成后，仓库第一次具备了自动化的架构健身函数，也就是能持续判断系统有没有朝错误方向长。你可以通过三步看到它已经生效：先跑 `lua tests/internal/dep_rules.lua`，它会验证静态边界；再跑定向守护 suite；最后跑全量回归，确认守护已经接入默认入口。

这个里程碑已改动的文件只有四个。`tests/internal/dep_rules.lua` 记录了三组基线。`tests/suites/architecture_guard_contract.lua` 记录了动态契约。`tests/regression.lua` 把新 suite 接入默认回归。`.github/workflows/regression.yml` 把同一入口接到 GitHub Actions。这个范围刻意很小，因为阶段0的价值在于“守住现状”，而不是带着大规模业务改动一起提交。

验收标准已经成立：本地全量回归通过，`dep_rules ok` 会在默认入口里出现，GitHub Actions 会在 `push` 和 `pull_request` 上运行同样的命令。

## 里程碑 1：定义用例输出协议（已完成）

这个里程碑完成后，用例层将不再直接认为自己拥有 UI 状态结构，而是只知道“我要发出什么输出”。这里的“输出协议”不是网络协议，而是一组稳定的 Lua 端口函数和数据结构，用来描述“请求选择”“显示弹窗”“排队动作动画”“标记 UI 失效”等意图。完成后，`GameplayLoop`、`TurnDispatch`、`TickTimeout` 应该能在没有真实 UI 状态表的情况下运行。

具体从 `src/game/flow/turn/GameplayLoop.lua`、`src/game/flow/turn/TurnDispatch.lua`、`src/game/flow/turn/TickTimeout.lua` 下手。新增一个端口模块，建议路径是 `src/game/flow/ports/UseCaseOutputPort.lua`。先让 `GameplayLoopPorts` 解析出 `output` 分组，再把 `state.ui_dirty`、`state.ui_model`、`state.ui_modal_elapsed`、`state.pending_choice*` 的直接写入逐步替换为 `output` 调用。presentation 侧继续保留兼容实现，先让老路径和新端口同时工作，再移除旧写入。

这个里程碑已经完成。实际新增的输出端口文件是 `src/game/flow/ports/UseCaseOutputPort.lua`，并且它已经接入 `GameplayLoopPorts` 的 `output` 分组。`GameplayLoop` 的初始化 choice、`TurnDispatch` 的 invalidation 与 clear choice、`TickChoiceTimeout` 的 pending choice 生命周期、`TickTimeout` 的 modal timer 都改成走 output port。为了兼容旧的 presentation 与测试，`src/core/RuntimeState.lua` 中新增了 `ui_runtime` 镜像缓存，但 `src/game/flow` 里的 `state.ui_*` 直接写入已经降到 0。

这个里程碑的验收也已经成立。第一，`architecture_guard_contract` 现在不仅验证 DTO 注入，还验证 `set_game`、`choice_select`、`next` 都会通过 output port 发出输出，而不是继续直接写 `state.ui_*`。第二，`usecase_boundary_contract` 新增了 output port 默认桥接和 override 优先级测试。第三，`tests/internal/dep_rules.lua` 中 `src/game/flow` 的 `state.ui_*` 预算已被收紧到空账本，也就是任何新增直写都会立刻失败。

## 里程碑 2：移除 `game.ui_port` 隐式挂载

这个里程碑要解决的是依赖方向问题，而不是语法问题。当前 `game.ui_port` 让领域和用例层“知道外层对象长什么样”，这会把 presentation 的细节一路拖进 `src/game`。完成后，`TurnRoll`、`TurnMove`、`TurnDecision`、`IntentDispatcher`、`Bankruptcy`、`ItemPhase` 等模块应只认识显式注入的端口，例如 `NotificationPort`、`AnimGatePort` 或更小的专用端口。

实施顺序要从最窄的读路径开始。先把只读布尔判断迁出，比如 `wait_action_anim`、`wait_move_anim`，再迁 `push_popup` 这类行为端口，最后处理 `ui_port.state` 这种最危险的反向回读。每迁完一个文件，就同步缩小 `game.ui_port` 的基线预算。不要一次性替换所有使用点，否则很难定位回归。

这个里程碑已经完成。第一刀是动画等待门控：`src/core/ActionAnimPort.lua`、`src/game/flow/turn/TurnRoll.lua`、`src/game/flow/turn/TurnMove.lua` 已改读 `game.anim_gate_port`。第二刀到第五刀把 `IntentDispatcher`、`Bankruptcy`、`LandingPresenter`、`ItemInventory`、`ItemUseBroadcast`、`BaseLandEffects`、`TurnDecision` 等路径分别迁到 `popup_port`、`tile_feedback_port` 和显式 coroutine session 字段。最后一刀则把 `GameplayLoop.set_game()` 中残留的 catch-all `ui_port` DTO 拆掉，改成只注入 `board_scene_port`、`popup_port`、`tile_owner_notifier`、`anim_gate_port`；同时 `StatePorts` 已优先消费 `board_scene_port`，`GameStateTiles` 不再读取 `self.ui_port`。

这个里程碑的验收现在也已经成立。`tests/internal/dep_rules.lua` 中 `game.ui_port` 预算已经收紧到 0；`architecture_guard_contract` 现在验证 `set_game()` 注入的是一组窄端口而不是 `ui_port` 共享 DTO；全量 `lua tests/regression.lua` 继续通过，说明旧行为没有因为边界收口而回退。

## 里程碑 3：完成 runtime 适配器外迁

这个里程碑要把 `src/core` 恢复成“只包含策略、规则和跨宿主抽象”的目录，不再直接摸 Eggy 宿主 API。优先迁 `src/core/RuntimeEnvBindings.lua`、`src/core/runtime_ports/DefaultPorts.lua`、`src/core/RuntimeContext.lua`、`src/core/RuntimeEditorExports.lua`、`src/core/Logger.lua`。目标位置应落在 `src/app/bootstrap` 或新的 `src/infrastructure` 风格目录，关键原则是让 `src/core` 只定义接口或纯逻辑，不负责绑定全局。

实施时先迁环境安装，再迁默认端口，再迁编辑器导出与日志。`Logger` 必须改成注入 sink，而不是继续直接找 `GlobalAPI.show_tips`。每完成一项，就让 `tests/internal/dep_rules.lua` 中 `src/core` 宿主 API 的预算下降，并在同一提交里更新预算数字。

验收标准是：`src/core` 宿主 API 预算明显缩小，且 `runtime_ports_contract` 或新增契约测试能证明新的 bootstrap 适配器提供了同样的行为。

## 里程碑 4：拆分 Market 购买链路

这个里程碑要处理当前最典型的跨层事务脚本。`src/game/systems/market/service/Purchase.lua` 同时做商品映射、平台支付、事件注册、购买兑现和 UI 刷新，任何一个点出问题都会让测试和宿主耦合在一起。完成后，业务规则应留在 `src/game/systems/market` 下的 domain 或 service，平台支付应移到独立 gateway，UI 刷新应回到 presentation 或 output port。

建议先定义 `PaymentGatewayPort`，再把平台映射与回调桥接移到外层实现，最后让用例层只接收“支付已完成”事件。不要在这个阶段顺手做 presentation 文案清理，那是阶段5的职责。

这个里程碑现在已经完成并收口。除了支付 gateway、兑现、购买前策略、失败反馈、结果协调这些拆分外，`ChoiceSession.lua` 也已经接管 market choice 的 pending-choice rebuild、导航刷新和 paid callback 后刷新；`Choice.lua` 只负责 `build()`，`Purchase.lua` 只负责在本地购买和外部支付之间做编排决策。

本阶段最后的判断已经拍板：不再继续把 `Purchase.lua` 的本地金币购买路径切得更碎。原因不是做不到，而是继续拆下去只会把编排器变成一串没有业务含量的转发层。当前文件边界已经足够清晰，继续推进的价值远小于阶段5把稳定 choice 协议彻底送到 presentation。

## 里程碑 5：整理 presentation 应用规则

这个里程碑现在已经完成。`PreConfirmFlow.lua`、`choice_screen_service.common.lua`、`UIChoice.lua`、`ChoiceSlice.lua`、`TargetChoiceEffects.lua`、`MarketModalRenderer.lua` 等 presentation 模块现在优先消费 `route_key`、`owner_role_id`、`confirm_title/confirm_body`、`uses_item_slots`、`pre_confirm_before_slot_pick`、`uses_target_picker`、`target_picker_owner_role_id`、`active_tab/page_index/page_count` 这些稳定字段；target 和 market 交互不再靠 `choice.kind/meta` 做核心业务推断。

本阶段真正补齐的根因是 `IntentDispatcher.open_choice()`：它现在会把这些稳定字段完整带入 `pending_choice`。没有这一步，presentation 即使愿意消费显式协议，也会因为运行时拿不到字段而退回旧推断。验收结果已经成立：`presentation_ui` 定向回归通过，且扫描可见的残留 `choice.kind/meta` 判断已经收敛回 use case / resolver 层，而不是 UI 渲染层。

## 里程碑 6：目录语义整理

这个里程碑现在也已完成，但采取的是最保守的收尾方式：先新增 `docs/architecture/boundaries.md`，把 `src/core`、`src/game/flow`、`src/game/systems`、`src/presentation` 的职责、禁止跨层访问和稳定 choice 协议写成导读，而不是立刻改目录名。这样既能把边界语义固化进仓库，又不会把“文档整理”和“重命名 / require 路径迁移”混成同一次风险提交。

## 工作计划

当前计划已经执行完毕。后续如果继续沿这条重构路线维护仓库，不需要再重新设计阶段，只需要遵循三条维护规则。

第一，新增 choice 交互时，优先把 presentation 需要的字段直接放进 choice 输出协议，并确保 `IntentDispatcher.open_choice()` 能把它们原样带入 `pending_choice`。第二，新增 runtime / host 细节时，不要把 Eggy 宿主 API 放回 `src/core`，而是通过 bootstrap、runtime context 或显式端口注入。第三，每次改边界后都跑定向回归再跑全量回归，确保“架构边界收口”和“玩法行为不回退”同时成立。

## 具体步骤

这份计划已经处于完成态。如果下一位执行者要验证或继续维护，请在仓库根目录 `/Users/billyq/Dev/Github/Lua/monopoly` 按下面顺序执行。

先跑静态边界守护。

    lua tests/internal/dep_rules.lua

预期输出：

    dep_rules ok

再跑与本次阶段4到阶段6最相关的定向 suite。

    lua -e "package.path = package.path .. ';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; require('TestHarness').run_all({ require('market') })"

预期输出最后一行是：

    All regression checks passed (15)

然后跑 presentation 定向回归。

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

如果未来再新增 choice 协议字段，必须同时检查三件事：用例层 choice spec 是否产出字段，`IntentDispatcher.open_choice()` 是否把字段带进 `pending_choice`，以及对应 presentation 模块是否优先消费该显式字段而不是退回 `kind/meta` 推断。

## 验证与验收

当前验收已经全部满足，而且以后每次继续维护这套边界都应满足同一组标准。

第一，静态守护必须继续失败于任何新增边界泄漏。运行 `lua tests/internal/dep_rules.lua` 时，应继续输出 `dep_rules ok`；如果有人把宿主 API 塞回 `src/core`、重新引入 `game.ui_port` 读取，或让 `src/game/flow` 再写新的 `state.ui_*` 字段，这个命令就应该失败并指向具体文件。

第二，阶段4到阶段6相关的定向 suite 必须继续通过。`market` suite 现在锁住 market session、choice build 和购买链路的收口；`presentation_ui` suite 现在锁住 secondary confirm、market pre-confirm、target picker、choice view 显式字段透传等关键行为。它们分别应继续输出 `All regression checks passed (15)` 和 `All regression checks passed (135)`。

第三，全量回归必须继续通过，而且仍通过统一入口 `lua tests/regression.lua` 串起 suites、`dep_rules`、`tick`、`forbidden_globals`。当前完成态下它应输出 `All regression checks passed (376)`。

第四，目录语义收尾必须留在仓库里而不是只留在聊天记录里。验证方法是检查 `docs/architecture/boundaries.md`；里面应继续说明 `src/core`、`src/game/flow`、`src/game/systems`、`src/presentation` 的职责边界，以及新增 choice 协议字段应该如何落地。

## 可重复性与恢复

阶段0的命令都是幂等的，可以重复运行，不会修改工作树。真正需要小心的是预算文件。`tests/internal/dep_rules.lua` 现在既是守护脚本，也是剩余债务的账本。以后如果你删除了一处旧的 `game.ui_port` 读取或 `state.ui_*` 写入，却忘了同步收紧预算，`dep_rules` 会失败。这不是回归，而是提醒你把账本和代码一起更新。

如果要回退阶段0本身，只需要回退四处变更：`tests/internal/dep_rules.lua`、`tests/suites/architecture_guard_contract.lua`、`tests/regression.lua`、`.github/workflows/regression.yml`。回退之后要重新运行 `lua tests/regression.lua`，确认仓库回到“没有阶段0守护”的旧状态。不要只回退测试或只回退 workflow，那会留下本地与 CI 不一致的坏状态。

## 产物与备注

阶段0到阶段6当前的关键产物如下。

    tests/internal/dep_rules.lua
    tests/suites/architecture_guard_contract.lua
    tests/suites/usecase_boundary_contract.lua
    tests/suites/market.lua
    tests/suites/presentation_ui.lua
    tests/regression.lua
    .github/workflows/regression.yml
    src/game/flow/ports/UseCaseOutputPort.lua
    src/game/flow/intent/IntentDispatcher.lua
    src/game/systems/market/service/Choice.lua
    src/game/systems/market/service/ChoiceSession.lua
    src/game/systems/market/service/LocalPurchase.lua
    src/game/systems/market/service/PaidPurchaseGateway.lua
    src/game/systems/market/service/PaidFulfillment.lua
    src/game/systems/market/service/PurchasePolicy.lua
    src/game/systems/market/service/Feedback.lua
    src/game/systems/market/service/ChoiceOutcome.lua
    src/presentation/ui/UIChoice.lua
    src/presentation/state/ui_model/ChoiceSlice.lua
    src/presentation/interaction/ui_intent_dispatcher/PreConfirmFlow.lua
    src/presentation/render/TargetChoiceEffects.lua
    docs/architecture/boundaries.md

当前冻结的债务基线如下。

    src/core 直接宿主触点：0
    game.ui_port 依赖点：0
    src/game/flow 的 state.ui_* 写入：0

本次实际验证输出如下。

    dep_rules ok

以及：

    All regression checks passed (15)

以及：

    All regression checks passed (135)

以及：

    All regression checks passed (376)
    dep_rules ok
    tick ok
    forbidden_globals ok

## 接口与依赖

阶段0已经引入了两类必须保留的接口约束。

第一类是 `tests/internal/dep_rules.lua` 中的三组预算规则。它们不是业务接口，但它们定义了当前允许存在的边界泄漏上限。以后如果代码减少了这些泄漏，预算值必须同步下降；以后如果代码想新增这些泄漏，测试必须失败。

第二类是 `tests/suites/architecture_guard_contract.lua` 固定下来的运行时契约。当前至少要维持下面三条事实：

    gameplay_loop.set_game(state, game)
    -- 结果：game.board_scene_port / game.popup_port / game.tile_owner_notifier / game.anim_gate_port 是窄 DTO，而不是共享的 game.ui_port

    turn_dispatch.dispatch_action(game, state, action, opts)
    -- 结果：关键输入路径通过 output port 发出 invalidate / clear choice，而不是继续扩写新的 state.ui_* 字段

    turn_roll(turn_mgr, args) / turn_move(turn_mgr, args) / action_anim_port.is_enabled(game)
    -- 结果：动画等待门控可以只依赖 game.anim_gate_port，在没有 game.ui_port 时仍能工作

2026-03-06 / Codex：本次更新把计划从“阶段1完成、阶段2第一刀已落地”的状态继续推进到“阶段3已完成三刀”的真实状态，补记了 `Logger`、`DefaultPorts`、`RuntimeEditorExports` 的外层化方式、测试基础设施的同步改法、最新预算和最新回归输出。这样下一位执行者可以直接从 `RuntimeEnvBindings` 或 `RuntimeContext` 继续推进，而不用重新推断哪些 `src/core` 触点已经收口。

阶段1开始后，请按下面这个接口方向推进，不要再发明新的共享状态入口。

在 `src/game/flow/ports/UseCaseOutputPort.lua` 中定义：

    local output_port = {
      invalidate_ui = function(state) end,
      open_choice = function(state, choice_model) end,
      close_choice = function(state, reason) end,
      sync_modal_timer = function(state, payload) end,
      push_popup = function(state, popup_model) end,
      queue_action_anim = function(state, anim_model) end,
    }

在 `src/game/flow/turn/GameplayLoopPorts.lua` 中把它挂到 grouped ports：

    ports.output.invalidate_ui(...)
    ports.output.open_choice(...)
    ports.output.close_choice(...)

这样做的原因只有一个：阶段1到阶段3都需要一个稳定的出口，让用例层只描述意图，不再直接认识 UI 状态表或宿主对象图。

2026-03-06 / Codex：本次更新完全重写 `.agents/plan.md`，把旧的 AFK 修复计划替换为当前“架构重构路线图与阶段0守护”活文档，并把今天已经完成的阶段0实现、验证命令、后续阶段顺序和验收标准全部写入。这样后续执行者无需聊天历史，只看本文件就能继续推进阶段1。

2026-03-07 / Codex：本次更新把计划推进到“阶段4五刀 + 阶段5第一刀已启动”的真实状态，补记了 `Feedback.lua` 的职责收口、market choice option 显式确认语义，以及对应的 `market/presentation_ui` 验证结果。这样下一位执行者可以直接继续决定：是再瘦一层 `Purchase.lua`，还是沿着 `PreConfirmFlow` 把更多 presentation 业务判断改成消费用例输出。

2026-03-07 / Codex：本次更新把计划推进到“阶段5第二刀已完成”的真实状态，补记了 `confirm_title/confirm_body` 这条轻量协议，以及 `ItemPhase`、`LandChoiceSpecs.tax_prompt`、`EffectPipeline`、market skin option 已前移确认文案的事实；验证结果已同步更新为最新的定向回归 `179` 和全量回归 `375`。

2026-03-07 / Codex：本次更新把计划推进到“阶段5第四刀第二小片已完成”的真实状态，补记了 `remote/player/target/market` 路由显式化，以及 `ChoiceRoutePolicy` 对这些 kind 的默认 route 推断已被删掉。这样下一位执行者可以继续收剩余 fallback，而不必重新判断哪些 route 仍靠 policy 猜。

2026-03-07 / Codex：本次更新把计划推进到“阶段2已完成”的真实状态，补记了 `board_scene_port` 这条最后的 runtime 窄端口、`GameStateTiles` 删除 `ui_port` fallback、测试支撑新增 `install_ui_port = false` 开关，以及 `game.ui_port` 债务预算已压到 0 的事实。这样下一位执行者可以直接转向阶段4里 `Choice.lua` 的 pending-choice updater 拆分，或阶段5里 `TargetChoiceEffects` 的显式 target-pick 语义收口，而不用再回头处理 `src/game` 对 `ui_port` 的旧耦合。

2026-03-07 / Codex：本次更新把计划推进到“阶段4第七刀已完成”的真实状态，补记了 `ChoiceSession.lua` 的职责边界、`Choice.lua` 已收缩成纯 builder、最新 market 定向回归 `15` 和全量回归 `376`。这样下一位执行者可以继续判断：是把阶段4到此收尾，还是沿阶段5去清 `TargetChoiceEffects`、`ChoiceSlice`、`MarketModalRenderer` 等仍然依赖 `choice.kind/meta` 推断的 presentation 逻辑。
