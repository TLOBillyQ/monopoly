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
- [ ] 阶段2：已完成第一刀动画门控外提：`ActionAnimPort`、`TurnRoll`、`TurnMove` 改读 `game.anim_gate_port`，`game.ui_port` 预算已从 23 收紧到 16；剩余 `push_popup` 与 `ui_port.state` 读路径仍待迁移。
- [x] (2026-03-07 00:28 +0800) 已完成阶段3：`RuntimeGlobalAliases` 已外迁到 `src/app/bootstrap/runtime_install/`；`Logger`、`DefaultPorts`、`RuntimeEditorExports`、`RuntimeContext` 都已改成 host hook 或 runtime context env 读取；`src/core` 宿主触点预算已从 47 压到 0。
- [ ] 阶段4：已完成五刀。第一刀新增 `src/game/systems/market/service/PaidPurchaseGateway.lua`，承接 paid-currency 的 goods mapping、purchase panel 启动、待兑现队列和购买回调注册。第二刀把 paid callback 后的 market choice 刷新移到 `src/game/systems/market/service/Choice.lua` 的 `refresh_after_paid_callback()`。第三刀新增 `src/game/systems/market/service/Fulfillment.lua`，统一 item/vehicle/skin 的兑现副作用。第四刀新增 `src/game/systems/market/service/PurchasePolicy.lua`，把商品可买性校验和座驾替换确认 intent 组装从 `Purchase.lua` 中抽走。第五刀新增 `src/game/systems/market/service/Feedback.lua`，把 market buy_failed 事件与黑市 popup 文案出口从 `Purchase.lua`、`Choice.lua` 中抽离。剩余工作主要是观察 `Purchase.lua` 是否还值得继续拆本地金币购买结果编排，还是直接把精力转到阶段5 的 presentation 规则回收。
- [x] (2026-03-07 01:27 +0800) 已启动阶段5第一刀：`src/game/systems/market/service/Choice.lua` 现在给 option 输出 `requires_pre_confirm/pre_confirm_kind`，`PreConfirmFlow.lua` 不再回查 `Config.Generated.Market` 判断皮肤商品，而是只消费用例层提供的 option 级确认语义；已补 `market` 与 `presentation_ui` 回归，验证“有 flag 才进二次确认，没有 flag 即使 product_id 像皮肤也直接派发”。
- [x] (2026-03-07 01:43 +0800) 已完成阶段5第二刀：`choice_screen_service.common` 现在优先消费 `option.confirm_title/confirm_body` 与 `choice.confirm_title/confirm_body`；`ItemPhase` 已同时为 choice 本身和每个 item option 产出确认文案，`LandChoiceSpecs.tax_prompt`、`EffectPipeline` 的 landing optional choice、market skin option 也都直接产出确认文案，presentation 仅保留 fallback 兼容逻辑。
- [x] (2026-03-07 02:02 +0800) 已完成阶段5第三刀的第一小片：`ItemPhase.build_choice_spec()` 现在额外输出 `uses_item_slots/pre_confirm_before_slot_pick`；`PreConfirmFlow`、`ItemPhaseAskFlow`、`UIModalPresenter`、`item_slots`、`item_slot_intents` 已优先消费这些显式语义，`choice.kind == "item_phase_choice"` 的散落判断被收敛到 `choice_screen_service.common` helper 中保底兼容。
- [x] (2026-03-07 02:10 +0800) 已完成阶段5第三刀的第二小片：`presentation_ui` 里的手工 `item_phase_choice` 测试数据已补齐显式 flag 与确认文案，`choice_screen_service.common` 已移除 `item_phase_choice` 的 `kind`-fallback 与旧确认文案推导，只保留显式字段路径。
- [x] (2026-03-07 02:18 +0800) 已完成阶段5第三刀的第三小片：`presentation_ui` 里的手工 `tax_card_prompt`、`landing_optional_effect` choice 也已补齐 `confirm_*` 字段，`choice_screen_service.common` 不再为 tax 和 buy/upgrade land 推导默认确认文案，确认 UI 全部优先消费用例层显式输出。
- [x] (2026-03-07 02:27 +0800) 已完成阶段5第四刀的第一小片：`LandChoiceSpecs.tax_prompt()` 与 `EffectPipeline` 生成的纯 buy/upgrade land optional choice 已显式输出 `route_key=\"secondary_confirm\"` 与 `requires_confirm=true`；`ChoiceRoutePolicy` 已移除对 `tax_card_prompt` 和 `buy_land/upgrade_land` 的 secondary-confirm 推断，presentation route 开始只消费用例层声明。
- [x] (2026-03-07 02:36 +0800) 已完成阶段5第四刀的第二小片：`ItemHandlers`、`ItemDemolish`、`market/service/Choice` 已分别为 `item_target_player`、`remote_dice_value`、`roadblock_target`、`demolish_target`、`market_buy` 显式输出 `route_key`；`ChoiceRoutePolicy` 已移除这些 kind 的默认 route 推断，`remote/player/target/market` 路由开始统一由 use-case 输出声明。
- [x] (2026-03-07 02:49 +0800) 已完成阶段5第四刀的第三小片：`LandChoiceSpecs.build_use_skip()` 现默认显式输出 `route_key=\"base_inline\"` 与 `requires_confirm=false`，`item_phase_choice` 的手工测试 choice 也已补齐 `route_key=\"base_inline\"`；`ChoiceRoutePolicy` 已不再为 `item_phase_choice` 特判 base-inline，当前只保留真正未知 choice 的 fallback。
- [ ] 阶段6：在边界稳定后整理目录语义和命名，避免目录改动与行为改动叠加。

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

- 观察：阶段2最窄的突破口确实是动画等待门控，因为 `TurnRoll`、`TurnMove` 和 `ActionAnimPort` 都只需要只读布尔配置，不依赖 popup 或 choice 语义。
  证据：迁出这三处后，`tests/internal/dep_rules.lua` 中 `src/core/ActionAnimPort.lua`、`src/game/flow/turn/TurnMove.lua`、`src/game/flow/turn/TurnRoll.lua` 的 `game.ui_port` 预算均已降为 0，同时新增契约测试仍可在 `game.ui_port = nil` 时通过。

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

- 决策：阶段5第二刀不新建“ConfirmViewModel”模块，先直接把 `confirm_title/confirm_body` 字段并入现有 choice/option 结构。
  理由：当前确认语义已经通过 `choice` 和 `option` 跨层传递，增加一层新 DTO 只会扩大改动面。先用兼容字段把 `ItemPhase`、`tax_prompt`、`landing_optional_effect`、market skin 的确认文案前移，能更快验证“presentation 只消费输出”这条方向，并保留 fallback 让旧 choice 不会一次性全坏。
  日期/作者：2026-03-07 / Codex

- 决策：阶段5第三刀先把 `item_phase_choice` 的 slot 交互语义抽成 `uses_item_slots/pre_confirm_before_slot_pick` 两个显式字段，并在 presentation 侧通过 helper 消费，而不是立刻删除所有 `choice.kind == "item_phase_choice"` fallback。
  理由：这条语义同时影响 modal、item slot、highlight 动画和 ask-flow；先让生产 builder 稳定产出显式标记，再把消费方统一到 helper，上层责任已经前移，但测试和旧手工 choice 仍能兼容运行。这样下一刀才能更安全地继续删 fallback。
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

## 结果与复盘

阶段0和阶段1现在都已经完成，阶段2也已经切开第一刀，阶段3则已经完整完成，阶段4已完成五刀，阶段5 也已经完成前两刀。当前最重要的可观察结果有七条。第一，`src/game/flow` 已经没有任何直接的 `state.ui_*` 写入；用例层现在通过 `UseCaseOutputPort` 发出 UI 失效、choice 生命周期和 modal timer 输出。第二，`game.ui_port` 的预算已经从 23 降到 16，其中 `TurnRoll`、`TurnMove`、`ActionAnimPort` 这三处动画等待门控已经改走 `game.anim_gate_port`。第三，`src/core` 已经不再直接认识 Eggy 宿主全局，相关安装器和别名逻辑都已外移或改成显式注入。第四，`Purchase.lua` 的 paid-currency 宿主购买通道已经被抽到 `PaidPurchaseGateway.lua`，paid callback 后的 market choice 刷新已经移到 `Choice.lua`，item/vehicle/skin 的兑现副作用已经集中到 `Fulfillment.lua`，购买前决策已经集中到 `PurchasePolicy.lua`，失败反馈事件出口已经集中到 `Feedback.lua`。第五，market choice 现在会在 option 上显式声明 `requires_pre_confirm/pre_confirm_kind`，presentation 的 `PreConfirmFlow` 不再靠 `Config.Generated.Market` 和 `product_id` 再做一轮业务判断。第六，`ItemPhase`、`tax_prompt`、`landing_optional_effect` 和 market skin option 已经直接携带 `confirm_title/confirm_body`，`choice_screen_service.common` 只在缺字段时做兼容 fallback。第七，默认回归仍保持通过，并把这些收口一起锁住。

这轮推进的经验同样直接。第一，阶段1不需要等 presentation 全部清干净才开始，先把“写入口”统一就能显著降低后续修改的耦合面。第二，守护测试必须允许内部兼容镜像存在，否则会把 `ui_runtime` 这种过渡性状态误判成旧债。第三，阶段2应该继续坚持“每次只拔一小束读路径”，因为 `push_popup`、`ui_port.state` 和 market 链路的风险明显高于动画布尔门控。第四，阶段3一旦把 `src/core` 改成显式注入，测试基础设施也必须同步升级为显式构造 runtime context，否则旧的全局 patch 习惯会反噬回归。

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

这个里程碑已经开始，但尚未完成。当前已经完成的第一刀是动画等待门控：`src/core/ActionAnimPort.lua`、`src/game/flow/turn/TurnRoll.lua`、`src/game/flow/turn/TurnMove.lua` 不再读取 `game.ui_port.wait_action_anim / wait_move_anim`，改为读取 `game.anim_gate_port`。`GameplayLoop.set_game` 现在会注入这个更窄的 DTO，新的契约测试也证明这三处在 `game.ui_port = nil` 时仍能运行。

里程碑 2 剩余的高风险路径还包括 `IntentDispatcher`、`Bankruptcy`、`ItemPhase` 等处的 `push_popup`，以及 `TurnDecision` 通过 `ui_port.state` 回读 `pending_choice_elapsed`。这些是下一阶段的主目标，不应该和动画门控这条已经落地的窄路径混在同一提交里继续扩大。

## 里程碑 3：完成 runtime 适配器外迁

这个里程碑要把 `src/core` 恢复成“只包含策略、规则和跨宿主抽象”的目录，不再直接摸 Eggy 宿主 API。优先迁 `src/core/RuntimeEnvBindings.lua`、`src/core/runtime_ports/DefaultPorts.lua`、`src/core/RuntimeContext.lua`、`src/core/RuntimeEditorExports.lua`、`src/core/Logger.lua`。目标位置应落在 `src/app/bootstrap` 或新的 `src/infrastructure` 风格目录，关键原则是让 `src/core` 只定义接口或纯逻辑，不负责绑定全局。

实施时先迁环境安装，再迁默认端口，再迁编辑器导出与日志。`Logger` 必须改成注入 sink，而不是继续直接找 `GlobalAPI.show_tips`。每完成一项，就让 `tests/internal/dep_rules.lua` 中 `src/core` 宿主 API 的预算下降，并在同一提交里更新预算数字。

验收标准是：`src/core` 宿主 API 预算明显缩小，且 `runtime_ports_contract` 或新增契约测试能证明新的 bootstrap 适配器提供了同样的行为。

## 里程碑 4：拆分 Market 购买链路

这个里程碑要处理当前最典型的跨层事务脚本。`src/game/systems/market/service/Purchase.lua` 同时做商品映射、平台支付、事件注册、购买兑现和 UI 刷新，任何一个点出问题都会让测试和宿主耦合在一起。完成后，业务规则应留在 `src/game/systems/market` 下的 domain 或 service，平台支付应移到独立 gateway，UI 刷新应回到 presentation 或 output port。

建议先定义 `PaymentGatewayPort`，再把平台映射与回调桥接移到外层实现，最后让用例层只接收“支付已完成”事件。不要在这个阶段顺手做 presentation 文案清理，那是阶段5的职责。

## 里程碑 5：整理 presentation 应用规则

这个里程碑完成后，presentation 只负责把 ViewModel 渲染出来，不再根据 `choice.kind` 和 `meta` 再做一轮业务判断。优先处理 `src/presentation/interaction/ui_intent_dispatcher/PreConfirmFlow.lua`，然后收口 `src/presentation/ui/choice_screen_service/common.lua` 和 target choice 相关渲染模块。最终目标是让 choice DSL 只存在于用例层定义的稳定输出模型中，而不是散落在 UI 适配器里。

验收标准是：presentation 中对 `choice.kind` 的分支显著减少，且新增的确认弹窗文案来自用例层提供的完整 ViewModel。

## 里程碑 6：目录语义整理

这个里程碑只在前五个阶段都稳定后再做。届时才能安全重命名目录、补 ADR、整理 `src/core` / `src/game/flow` / `src/presentation/read_model` 的职责解释。这里不要夹带行为改动，只做命名、导读和收尾清理，否则很容易把阶段1到阶段5的回归和目录变动混在一起。

## 工作计划

如果现在继续推进，不要再回头扩阶段0。下一步就是开始阶段1。先在 `src/game/flow/ports` 下定义一个稳定的输出端口模块，把它接到 `src/game/flow/turn/GameplayLoopPorts.lua` 的 grouped ports 中。随后分三批迁移当前的直接 UI 写入。第一批只迁 `state.ui_dirty` 这类失效信号，因为风险最低。第二批迁 `pending_choice` 和 `ui_model` 的构建与关闭路径，因为它们决定了选择框和 market 的主流程。第三批再迁 `TickTimeout.lua` 里的 `ui_modal_elapsed`、`ui_modal_ref`，让倒计时状态也进入端口化管理。

阶段1一旦有一条路径完成，就立刻补测试，而不是等全部文件都迁完。最先应该增加的是“Fake Output Port 下运行 GameplayLoop 一帧并收到预期输出”的契约测试。等阶段1把 `state.ui_*` 的预算压下去后，再进入阶段2；阶段2开始前不要把 `game.ui_port` 和 `state.ui_*` 两类边界同时大改，否则很难知道回归是从哪一类泄漏进来的。

阶段2和阶段3都要沿用同一个节奏。每次只迁一小组文件，迁完立刻缩预算、补契约、跑全量。阶段4到阶段6则建立在前面三阶段已经让边界稳定的前提上，否则 Market 和 presentation 的重构会重新把边界拉回去。

## 具体步骤

先验证阶段0当前状态。工作目录固定为仓库根目录 `/Users/billyq/Dev/Github/Lua/monopoly`。

    lua tests/internal/dep_rules.lua

预期输出：

    dep_rules ok

再跑阶段0的定向守护契约。

    lua -e "package.path = package.path .. ';./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua'; require('TestHarness').run_all({ require('architecture_guard_contract') })"

预期输出最后一行是：

    All regression checks passed (7)

然后跑全量回归，确认默认入口已经包含阶段0守护。

    lua tests/regression.lua

预期输出末尾包含：

    All regression checks passed (372)
    dep_rules ok
    tick ok
    forbidden_globals ok

开始阶段1时，先新建或修改这些文件，并在每一步后重复上面的三条命令：

    src/game/flow/ports/UseCaseOutputPort.lua
    src/game/flow/turn/GameplayLoopPorts.lua
    src/game/flow/turn/GameplayLoop.lua
    src/game/flow/turn/TurnDispatch.lua
    src/game/flow/turn/TickTimeout.lua
    tests/suites/architecture_guard_contract.lua
    tests/internal/dep_rules.lua

如果在阶段1里成功减少了某个预算值，必须在同一提交里更新 `tests/internal/dep_rules.lua` 中对应的数字，否则 `dep_rules` 会因为“预算陈旧”而失败。这是有意设计的约束，不是误报。

## 验证与验收

阶段0的验收标准已经满足，并且今后每次重构都必须继续满足。

第一，静态守护必须失败于任何新增边界泄漏。验证方法是运行 `lua tests/internal/dep_rules.lua`；只要新增了 `src/core` 宿主全局触点、`game.ui_port` 读路径或 `state.ui_*` 写入，命令就应失败并给出文件名。

第二，动态守护必须证明“关键路径上只暴露 DTO 和粗粒度输出”。验证方法是运行 `architecture_guard_contract`；它应继续证明 `GameplayLoop.set_game` 没有把原始 `state` 挂给 `game.ui_port`，且 `TurnDispatch` 没有继续扩写新的 `state.ui_*` 字段。

第三，默认回归必须包含这两类守护。验证方法是运行 `lua tests/regression.lua`；结果必须通过，并继续打印 `dep_rules ok`。

第四，CI 必须跑同一入口。验证方法是检查 `.github/workflows/regression.yml`，它只能调用 `lua tests/regression.lua`，不要维护第二套回归命令。

阶段1之后的验收要更严格。每推进一阶段，都要同时看到两件事：一个新的业务或架构契约测试加入默认回归，以及 `tests/internal/dep_rules.lua` 中至少一组预算值下降。没有预算下降，说明只是搬代码，没有真正收口边界。

## 可重复性与恢复

阶段0的命令都是幂等的，可以重复运行，不会修改工作树。真正需要小心的是预算文件。`tests/internal/dep_rules.lua` 现在既是守护脚本，也是剩余债务的账本。以后如果你删除了一处旧的 `game.ui_port` 读取或 `state.ui_*` 写入，却忘了同步收紧预算，`dep_rules` 会失败。这不是回归，而是提醒你把账本和代码一起更新。

如果要回退阶段0本身，只需要回退四处变更：`tests/internal/dep_rules.lua`、`tests/suites/architecture_guard_contract.lua`、`tests/regression.lua`、`.github/workflows/regression.yml`。回退之后要重新运行 `lua tests/regression.lua`，确认仓库回到“没有阶段0守护”的旧状态。不要只回退测试或只回退 workflow，那会留下本地与 CI 不一致的坏状态。

## 产物与备注

阶段0到阶段5第一刀当前的关键产物如下。

    tests/internal/dep_rules.lua
    tests/suites/architecture_guard_contract.lua
    tests/suites/usecase_boundary_contract.lua
    tests/regression.lua
    .github/workflows/regression.yml
    src/game/flow/ports/UseCaseOutputPort.lua
    src/game/systems/market/service/PaidPurchaseGateway.lua
    src/game/systems/market/service/Fulfillment.lua
    src/game/systems/market/service/PurchasePolicy.lua
    src/game/systems/market/service/Feedback.lua

当前冻结的债务基线如下。

    src/core 直接宿主触点：0
    game.ui_port 依赖点：16
    src/game/flow 的 state.ui_* 写入：0

本次实际验证输出如下。

    dep_rules ok

以及：

    All regression checks passed (7)

以及：

    All regression checks passed (375)
    dep_rules ok
    tick ok
    forbidden_globals ok

以及：

    All regression checks passed (179)

## 接口与依赖

阶段0已经引入了两类必须保留的接口约束。

第一类是 `tests/internal/dep_rules.lua` 中的三组预算规则。它们不是业务接口，但它们定义了当前允许存在的边界泄漏上限。以后如果代码减少了这些泄漏，预算值必须同步下降；以后如果代码想新增这些泄漏，测试必须失败。

第二类是 `tests/suites/architecture_guard_contract.lua` 固定下来的运行时契约。当前至少要维持下面三条事实：

    gameplay_loop.set_game(state, game)
    -- 结果：game.ui_port 是裁剪后的 DTO，而不是原始 state

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
