# 基于 `.agents/research.md` 的音效特效交付可执行计划

本可执行计划是活文档。实施过程中必须持续更新“进度”“意外与发现”“决策日志”“结果与复盘”。

本文件必须遵循 `.agents/harness/PLANS.md` 维护。讨论、实施、暂停和重启都只依赖这份计划本身，不依赖聊天历史，也不要求读者先了解旧的缺陷修复文档。

## 目的 / 全局视角

`.agents/research.md` 现在定义了一组新的交付目标：把大富翁的落地结算、回合推进、神明附身、破产和逐格移动补成“看得见、听得到”的反馈链。用户真正关心的不是仓库里新增了几个 Lua 文件，而是这些场景发生时，玩家能立即感知到对局状态变化：停在宝箱位有亮光，升级建筑有烟雾和延迟音效，交钱有爆金币，医院、深山、地雷和税务局都能打出对应特效，财神与天使附身有角色围绕特效，逐格移动会每格播一次前扑音效，破产和回合开始也各自有稳定提示。

这轮工作完成后，可观察结果应该是这样的：在编辑器实机中，按需求表触发 12 个场景时，至少会出现一条对应的可见特效或可闻音效；在纯 Lua 测试里，规则层会发出稳定的 cue，表现层会把 cue 翻译成 `GameAPI.play_sfx_by_key`、`GameAPI.play_3d_sound`、`GlobalAPI.bind_sfx_to_unit` 或等价端口调用，并且不会因为资源 key 缺失而直接崩溃。验收不是“调用过某个 API”就算完成，而是“自动化能证明路由正确，编辑器里能证明玩家真的看到了效果”。

## 进度

- [x] (2026-03-06 15:30+08:00) 已重读 `.agents/research.md` 与 `.agents/harness/PLANS.md`，确认本轮目标已经从旧的缺陷修复切换为音效特效交付，旧 `.agents/plan.md` 不再适用。
- [x] (2026-03-06 15:31+08:00) 已完成现状摸底：`src/presentation/render/ActionAnim.lua` 只覆盖 `roll`、`roadblock`、`mine`、`upgrade_land`、`cash_receive`、`missile`、`clear_obstacles`，其中 `cash_receive` 目前是空实现。
- [x] (2026-03-06 15:32+08:00) 已确认仓库缺口：`src/presentation/api/HostRuntimePort.lua` 还没有任何音效或特效端口；仓库也没有专门保存音效 key 或特效 key 的配置表。
- [x] (2026-03-06 15:33+08:00) 已通过官方页面核实 Eggy 当前可用的核心接口：`GameAPI.play_sfx_by_key(_sfx_key, _pos, _rot, _scale, _duration, _rate, _with_sound)`、`GlobalAPI.bind_sfx_to_unit(_sfx_id, _unit, _socket_name, _pos, _bind_type)`、`GlobalAPI.destroy_sfx(_sfx_id, _fade_out)`、`GameAPI.play_3d_sound(_position, _sound_key, _duration, _volume)`、`GameAPI.stop_sound(_assigned_id)`。
- [x] (2026-03-06 15:34+08:00) 已把需求表逐条映射到现有代码触发点，覆盖 `TurnStart`、`Movement.move`、`BaseLandEffects`、`LandRules`、`SpecialTileEffects`、`MineEffect`、`ItemPostEffects`、`Bankruptcy`、`UIEventHandlers` 和 `MoveAnim`。
- [x] (2026-03-06 15:35+08:00) 已确定本计划采用“运行时端口 + 表现配置目录 + 规则事件补点 + 表现层翻译”的实现路线，并将测试落点收口到 `tests/suites/presentation_ui_action_anim.lua`、`tests/suites/presentation_ui_event_handlers.lua`、`tests/suites/item.lua`、`tests/suites/landing.lua`、`tests/suites/gameplay.lua` 与 `tests/regression.lua`。
- [ ] (2026-03-06 15:35+08:00) 尚未开始代码实现。下一步先做运行时端口和反馈配置目录，再补现有动画与事件链的接入点。

## 意外与发现

2026-03-06 15:31+08:00：当前仓库虽然有 `src/game/systems/effects/*`，但那一层处理的是落地效果选择器，不是 Eggy 的音效与特效播放系统。真正的视觉表现入口在 `src/presentation/render/ActionAnim.lua` 和 `src/presentation/api/UIEventHandlers.lua`。证据是 `EffectPipeline` 只负责 rule executor 与 choice，而 `ActionAnim` 才会调用 `HostRuntimePort` 生成 overlay 或提示。

2026-03-06 15:31+08:00：`cash_receive` 已经是一个既有动画 kind，但现在没有任何视觉实现，意味着“购买/交钱”和“收到金币”不需要发明新语义，优先把它补成真正的金币反馈即可。证据是 `src/game/systems/chance/handlers/CashHandlers.lua` 已经在加钱时排队 `kind = "cash_receive"`，而 `src/presentation/render/ActionAnim.lua` 的 `cash_receive` handler 直接返回时长。

2026-03-06 15:32+08:00：仓库没有任何“音效 key / 特效 key”配置，只有 `Data/Prefab.lua` 中少量 prefab 和现有 UI 动效节点。这意味着第一版必须引入一份手写 catalog，并允许 key 缺失时安全降级，否则实现会卡死在资源编号未交付。证据是全文搜索只有 `Data/Prefab.lua`、`Data/UIManagerNodes.lua` 和官方 API 文档命中了 `sfx`、`sound`。

2026-03-06 15:33+08:00：官方页面确认了这轮必须依赖的引擎 API，但没有给出“回合开始音效”这种玩法级封装，所以仓库仍然需要自己的中间层把玩法 cue 翻译成引擎调用。证据是官方页面只列了通用接口签名，没有任何大富翁专用 helper。

2026-03-06 15:34+08:00：需求表里的“玩家停下位置（光2-宝箱）”在仓库中找不到同名 tile、同名 prefab 或同名 UI 节点，因此第一版不能把场景命名写死到业务逻辑里。证据是全文搜索 `光2`、`宝箱` 没有结果，而 `Config/Generated/Tiles.lua` 只有 `chance`、`item`、`hospital`、`mountain`、`tax` 等通用 tile type。

2026-03-06 15:34+08:00：逐格前扑音效不需要新增规则事件，因为 `Movement.move` 已经返回 `visited` 路径，`MoveAnim.play_sequence` 也会逐步调度每一段移动。证据是 `src/game/flow/turn/TurnMove.lua` 把 `move_result.visited` 放进动画上下文，而 `src/presentation/render/MoveAnim.lua` 会基于 `visited` 拆出每一步。

## 决策日志

2026-03-06 / Codex：这轮不把音效与特效 key 塞进 `Config/Generated`，而是新建 `src/presentation/render/BoardFeedbackCatalog.lua`。理由是仓库当前没有音效资源自动导出链，若放在 `Generated` 会误导后续维护者以为这些 key 来自表格导出；手写 catalog 更符合现状，也更容易在资源未齐时安全占位。

2026-03-06 / Codex：运行时接入采用新文件 `src/presentation/api/host_runtime/SfxRuntime.lua`，并由 `src/presentation/api/HostRuntimePort.lua` 暴露统一端口。理由是现有 `HostRuntimePort` 已经承担“表现层唯一引擎入口”的职责，继续沿这个方向扩展，可以避免业务代码直接写 `GameAPI` 或 `GlobalAPI`。

2026-03-06 / Codex：逐格前扑音效放在 `src/presentation/render/MoveAnim.lua` 的步进调度里，而不是在 `Movement.move` 里新增自定义事件。理由是“每格 1 次”本质上是表现层节奏，不是规则状态；复用 `visited` 可以减少事件噪声，也能天然对齐动画节拍。

2026-03-06 / Codex：已有的 domain event 优先复用，只有在现有事件无法表达需求时才新增 `feedback.*` 事件。理由是 `land.tile_upgraded`、`land.rent_paid`、`land.tax_paid`、`land.mine_hit`、`chance.applied` 已经覆盖了半数以上需求；把所有东西都塞进新事件域只会让事件目录膨胀。

2026-03-06 / Codex：Generic 行“被窃取/交钱等负面效果 -> 被淘汰”按“没有更明确场景行时才兜底”解释。理由是需求表已经为“购买/交钱”单列了金币特效和金币音效，若再让所有交钱都播“被淘汰”会与显式场景冲突。

2026-03-06 / Codex：资源 key 缺失时允许记录日志并跳过实际播放，不允许因为 nil key 直接中断对局。理由是这轮交付既包含代码链路也包含内容资源，计划必须支持“代码先落地、资源后补齐”的增量推进。

## 结果与复盘

截至 2026-03-06 15:35+08:00，本计划只完成了调研、路线拍板和文件级拆解，还没有开始实现。真正的风险不在 Lua 规则本身，而在资源 key 缺失、播放端口未封装以及“哪些 cue 应该走动画队列，哪些 cue 应该走自定义事件”这三个边界。下面的工作计划就是围绕这三个风险拆出来的；实施过程中如果路线改变，必须立刻回填本节与“决策日志”，不能只改代码不改文档。

## 背景与导读

对这个仓库完全陌生的人，先记住四层关系。第一层是规则层。`src/game/flow/turn/TurnStart.lua`、`src/game/flow/turn/TurnRoll.lua`、`src/game/flow/turn/TurnMove.lua` 驱动一个回合怎样开始、投骰、移动和结算。`src/game/systems/land/landing_effects/BaseLandEffects.lua`、`src/game/systems/land/landing_effects/SpecialTileEffects.lua`、`src/game/systems/land/LandRules.lua` 负责买地、升级、交租、税务、医院、深山和地雷。`src/game/systems/items/ItemPostEffects.lua` 负责地雷、财神、天使、穷神等道具落地后的副作用。`src/game/core/runtime/Bankruptcy.lua` 负责破产。

第二层是规则到表现的桥。这个仓库有两条桥。第一条是动作动画队列，入口在 `src/core/ActionAnimPort.lua`，最终由 `game:queue_action_anim` 把 payload 放到 `game.turn.action_anim_queue`。第二条是自定义事件，入口在 `src/core/events/MonopolyEvents.lua`，最终由 `src/presentation/api/UIEventHandlers.lua` 注册监听。当前桥上已经存在的稳定信号包括 `land.tile_upgraded`、`land.rent_paid`、`land.tax_paid`、`land.mine_hit`、`chance.applied`、`movement.passed_start` 以及各种 popup intent。

第三层是表现层。`src/presentation/render/ActionAnim.lua` 负责解释动作动画 kind。`src/presentation/render/ActionAnimUnitOverlay.lua` 会在地块上生成地雷、路障、导弹和清障机器人等 overlay。`src/presentation/render/MoveAnim.lua` 负责逐步移动。`src/presentation/render/status3d_service/*` 负责医院、深山、财神和天使的状态显示。`src/presentation/api/UIViewService.lua` 与 `src/presentation/ui/*` 负责 popup 和画布。`src/presentation/api/HostRuntimePort.lua` 则是表现层唯一允许碰引擎 API 的入口，但它现在还没有音效或特效相关接口。

第四层是测试。`tests/suites/item.lua` 适合守住道具后效和动画 kind。`tests/suites/landing.lua` 适合守住地块结算和升级广播。`tests/suites/gameplay.lua` 适合守住回合、破产和跨模块行为。`tests/suites/presentation_ui_action_anim.lua` 适合验证动画 payload 如何落到表现层。`tests/suites/presentation_ui_event_handlers.lua` 适合验证自定义事件如何翻译成表现层调用。`tests/regression.lua` 会把这些 suite 汇总成一次回归。

这轮还必须记住两个仓库约束。第一，数值和时长比较不能靠 `tonumber` 或 `type(x) == "number"`，要统一用 `src/core/NumberUtils.lua`。第二，Eggy 运行时要求浮点字面量写成 `1.0` 这种形式，所以新加的 scale、duration、volume 都要显式写成定点风格，不要写裸整数再期望引擎自动转换。

## 工作计划

### 里程碑一：建立可复用的音效特效运行时端口和目录

这一步完成后，仓库里会第一次出现一个明确的“玩法 cue -> 引擎 API”接入层，后续任何音效和特效都不需要直接在规则文件里碰 `GameAPI`。要新建 `src/presentation/api/host_runtime/SfxRuntime.lua`，把 `GameAPI.play_sfx_by_key`、`GameAPI.play_3d_sound`、`GameAPI.stop_sound`、`GlobalAPI.bind_sfx_to_unit`、`GlobalAPI.destroy_sfx` 包成安全函数；然后扩展 `src/presentation/api/HostRuntimePort.lua` 暴露这些函数。并行新建 `src/presentation/render/BoardFeedbackCatalog.lua`，只保存这次需求需要的 cue 名称、资源 key、默认缩放、持续时间、音量、是否绑定玩家单位、以及缺资源时是否允许静默跳过。

这一里程碑还要把资源缺口写成代码契约，而不是口头说明。`BoardFeedbackCatalog` 中每个 cue 都应该允许 key 为 nil，此时服务必须记录日志并返回 false，而不是 assert。这样即使策划晚一点才把“放置烟雾”“爆金币”“眩晕星星”“触电”“爆炸-烈焰”“格子波动”“风沙缠绕”“治愈光圈”“砸地重击”这些资源 key 补进来，测试仍然可以先验证路由和降级逻辑。

这一里程碑的自动化证据应该来自 `tests/suites/presentation_ui_action_anim.lua` 与 `tests/suites/presentation_ui_event_handlers.lua`。前者新增对 runtime 端口的 stub，验证 catalog 中的 scale、duration 和 key 会被正确透传；后者验证 key 缺失时只是跳过播放并保留日志，不会抛异常。做到这一步，就说明“能不能调到 Eggy 播放接口”这个最大不确定性已经被清掉了。

### 里程碑二：把已有动作动画链补成真正的音效特效反馈

这一步完成后，现有已经会排队的动画不再只是 tip 文本，而是能带出实际效果。`src/presentation/render/ActionAnim.lua` 与 `src/presentation/render/ActionAnimHandlers.lua` 需要扩展，让 `upgrade_land`、`cash_receive`、`mine` 以及必要时新增的 `bankruptcy_hit`、`status_hit`、`deity_apply` 支持调用 `BoardFeedbackService`。可以新增 `src/presentation/render/BoardFeedbackService.lua` 作为表现层内部服务，专门负责“按 tile 中心播放 one-shot 特效”“按玩家单位绑定短时特效”“按位置播放 3D 音效”“在定时结束后销毁绑定特效”。

这一里程碑里，旧的 `cash_receive` 空实现必须被补齐。购买、交租、交税和从机会卡获得金币，需求里都依赖金币表现；因此 `cash_receive` 至少要支持一个默认金币爆发特效和一个金币音效。升级建筑场景要在 `upgrade_land` 里增加“放置烟雾，缩放三倍”的视觉，并在同一个 cue 上支持“先播收到金币，延迟一秒再播回合胜利”的双音效链。延迟必须通过现有 `host_runtime.schedule` 或 `runtime_ports.schedule` 来做，而不是在业务层散落新的计时器。

这一步还要补 `src/presentation/render/MoveAnim.lua`。当前它已经拿得到 `visited` 路径和每一步的调度时刻，所以应当在每个 step 落点时调用 `BoardFeedbackService.play_step_tile_sound(...)`，从而实现“进入每一格地块时，蛋仔前扑音效每格一次”。这是纯表现层节奏，不需要往规则层新增事件。自动化证据应当在 `tests/suites/presentation_ui_action_anim.lua` 中看到：一次多格移动会触发与 `visited` 长度一致的步进音效调用，且不会在 `from_index == to_index` 的空步上误播。

### 里程碑三：把规则结果补成可翻译的 cue

这一步的目标是把需求表里还没有稳定表现入口的场景补成明确 cue。优先复用已有事件：`BaseLandEffects._apply_upgrade` 已经会触发 `land.tile_upgraded`，`LandRules.execute_pay_rent` 与 `execute_pay_tax` 已经会产出 `land.rent_paid`、`land.rent_bankrupt`、`land.tax_paid`，`MineEffect.apply` 已经会发 `land.mine_hit`，`ChanceHandlers.CashHandlers` 已经会发 `chance.applied`。这些地方不要再发第二套重复事件，而是让 `UIEventHandlers` 订阅并翻译成 `BoardFeedbackService` 调用。

真正需要补新 cue 的地方只有当前没有稳定事件语义的场景。`TurnStart.lua` 需要在玩家回合真正开始时发一个 `feedback.turn_started`，用于“自己的回合开始 -> 回合胜利音效”。`ItemPostEffects._handle_deity` 需要发 `feedback.deity_applied`，payload 至少包含 `player_id` 和 `deity = "rich" | "angel"`，让财神与天使能播放围绕角色的短时效果。`SpecialTileEffects` 中的医院和深山需要在效果真正生效时发 `feedback.status_applied`，用于触电和眩晕星星。`Bankruptcy.eliminate` 需要发 `feedback.bankruptcy`，让破产能够补出“砸地重击 + 回合失败”。

这里还要解决需求表里“负面效果”与“交钱”的优先级冲突。实现时必须遵守“更具体的场景先于通用兜底”。也就是说，`rent_paid`、`tax_paid`、`tile_upgraded` 等已经明确列在表里的事件，按各自行映射，不受“被窃取/交钱等负面效果”影响。只有像偷窃失败、查税卡命中、穷神类负面卡这类没有单独行、但显然属于负面反馈的情况，才使用统一的负面音效 cue。这个优先级要写进 catalog 或 event translation 代码里，不能靠维护者记忆。

### 里程碑四：把需求表 12 个场景逐条落到代码和验收

这一里程碑完成后，`.agents/research.md` 里的每一行都会在计划里有明确的代码归属。玩家停在“光2-宝箱”这一行，由于仓库里不存在同名资源，第一版按“停在对应 tile 时在 tile 中心播光效”交付，映射到 `feedback.item_stop_highlight`；如果后续地图资源补了专用锚点，再把 catalog 的锚定策略从 tile 中心切到具名锚点，不改规则层。升级建筑继续走 `upgrade_land`。购买/交钱优先走 `rent_paid`、`tax_paid` 和 `cash_receive`。深山、医院、地雷、税务局分别走 `feedback.status_applied` 或 `land.mine_hit`。财神驾到和天使附身走 `feedback.deity_applied`。每格前扑走 `MoveAnim`。破产走 `feedback.bankruptcy`。被窃取或其他负面效果走通用负面 cue。回合开始走 `feedback.turn_started`。

到这一步时，计划中的每条需求都必须能回答四个问题：谁发 cue、谁翻译 cue、用哪种引擎 API、用哪套测试守住。任何一个场景如果还回答不出这四件事，就说明它还没有真正进入可执行状态。

### 里程碑五：做编辑器实机验证并收口资源表

自动化只能证明“逻辑路由正确”，不能证明“策划认可视觉和听感”。因此最后必须进 Eggy 编辑器做实机验证。建议用现有启动 profile 缩短验证路径。`src/app/bootstrap/StartupPolicy.lua` 允许在非 release 启动时读取 `STARTUP_TEST_PROFILE`，所以可以使用 `STARTUP_TEST_PROFILE = "items_deity_status"` 快速验证财神、天使、税务局和神明相关卡；需要破产时使用现成 `scenario_bankruptcy`；需要医院、深山和地雷时，直接在 profile 或调试背包里给 1 号玩家对应卡牌并把位置放到目标地块附近。

这一里程碑的结果不是再改架构，而是收口 `BoardFeedbackCatalog` 里真正的资源 key、持续时间和缩放。需求表明确写了“放置烟雾，缩放 ×3”和“爆金币，缩放 ×3”，这两个值最终要直接固化在 catalog 中，并通过测试断言保护。验证结束后，把实机观察到的最终 key、明显偏大的缩放或过长的时长都回填到本计划的“结果与复盘”。

## 具体步骤

以下命令默认在仓库根目录 `/Users/billyq/Dev/Github/Lua/monopoly` 执行。每做完一个里程碑，都必须回填“进度”“意外与发现”“决策日志”“结果与复盘”。

先建立一个只跑目标 suite 的快速回归命令，方便每次做小步验证。

    lua -e 'package.path = package.path .. ";./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua"; require("TestHarness").run_all({ require("presentation_ui_action_anim"), require("presentation_ui_event_handlers"), require("item"), require("landing"), require("gameplay"), require("movement") })'

预期会输出一串 `.`，最后出现 `All regression checks passed (...)`。如果这里先失败，要先把失败信息抄回“意外与发现”，不要直接开始叠加新功能。

然后实现运行时端口与 catalog。

    rg -n "play_sfx_by_key|play_3d_sound|bind_sfx_to_unit|destroy_sfx|stop_sound" docs/eggy/api src
    rg -n "HostRuntimePort|ActionAnim|UIEventHandlers|MoveAnim" src/presentation

改动后再次运行上面的 targeted suite。预期新增测试能证明 `HostRuntimePort` 已经暴露音效特效接口，且 key 缺失时不会崩溃。

接着补动作动画链与逐格音效。

    lua -e 'package.path = package.path .. ";./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua"; require("TestHarness").run_all({ require("presentation_ui_action_anim"), require("movement") })'

预期新增用例能证明三件事：`cash_receive` 不再是空 handler；`upgrade_land` 会触发烟雾与双音效调度；`MoveAnim` 会按 `visited` 长度逐格播“蛋仔前扑”，不会多播或漏播。

然后补规则层 cue 与事件翻译。

    lua -e 'package.path = package.path .. ";./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua"; require("TestHarness").run_all({ require("presentation_ui_event_handlers"), require("item"), require("landing"), require("gameplay") })'

预期新增用例能证明 `TurnStart`、`ItemPostEffects`、`SpecialTileEffects`、`Bankruptcy` 和 `UIEventHandlers` 已经串通；触发医院、深山、财神、天使、税务局、破产时，都会生成稳定 cue 并翻译到正确的运行时调用。

最后做全量回归。

    lua tests/regression.lua

预期结果应是所有 suite 通过。如果这里出现与音效特效无关的旧失败，也必须记入“结果与复盘”，说明它与本次改动是否相关，不允许含糊地写“回归有红”。

实机验证前，在编辑器启动参数或全局变量里设置测试 profile。

    STARTUP_TEST_PROFILE = "items_deity_status"

如果需要模拟 release 启动下仍允许 test profile，再加：

    RELEASE_ALLOW_TEST_PROFILE = true

然后进编辑器触发财神、天使、税务局和神明相关场景；医院、深山、地雷和破产可以切到其他现成 profile，或按本计划中的规则入口手动发牌、调位置验证。实机验证完成后，把最终观察到的资源 key、播放时长和需要修正的视觉参数写回本文件。

## 验证与验收

验收要严格对着 `.agents/research.md` 的需求表，而不是抽象地说“音效特效正常”。升级建筑的验收是：触发 `upgrade_land` 时，先出现缩放三倍的烟雾，再在一秒内依次播“收到金币”和“回合胜利”。购买和交钱的验收是：金币相关结算触发金币爆发，并播一次“收到金币”。深山、医院、地雷、税务局的验收是：对应场景发生时，规则层发出稳定 cue，表现层能在角色或地块位置上播出对应效果，并且不会因为资源 key 缺失把整局打断。财神和天使的验收是：使用对应卡牌后，角色身上出现短时绑定特效，而不是只剩 3D 状态字。逐格前扑的验收是：移动跨过 N 格，就会播 N 次步进音效。破产与回合开始的验收是：分别播“回合失败”和“回合胜利”。

自动化验收至少需要两层。第一层是 targeted suite，用来证明 cue 的路由和运行时调用正确。第二层是 `lua tests/regression.lua`，证明这套反馈链没有破坏旧的规则、UI、动画和状态同步。编辑器实机验收则用来证明资源 key、缩放、时长和绑定位置符合策划预期。只有这三层都过了，才算这份计划完成。

如果某个场景在纯 Lua 环境中只能证明“调用了正确端口”，但不能证明“画面真的好看”，就必须在“结果与复盘”里明确写成“自动化已守住路由，最终视觉仍依赖编辑器实机确认”。这不是缺点，而是把自动化边界说清楚。

## 可重复性与恢复

这份计划按小步提交执行，允许反复重跑。最安全的顺序是：先写 runtime 端口与 catalog，再写表现层，再写规则层 cue，最后做实机资源校准。这样即使某个资源 key 尚未交付，代码也能靠降级逻辑和测试先落地。

如果某一步失败，优先恢复到“上一个里程碑的 targeted suite 全绿”状态，而不是用大回退覆盖未审查的改动。尤其不要在资源 key 还不确定时，把 `assert(key ~= nil)` 之类的硬约束放进业务链。对于需要短时绑定角色的特效，要保证特效 id 会在定时结束或目标被替换时清理；否则多次测试会在场景里残留脏对象。

## 产物与备注

这轮交付完成后，仓库里应该出现三类产物。第一类是表现运行时产物，包括新的音效特效端口、catalog 和播放服务。第二类是规则与事件产物，包括新增或补齐的 cue 发射点。第三类是测试产物，用来证明每个 cue 都能被翻译到正确的运行时调用。

预期的关键终端证据长这样，不需要逐字相同，但要保留关键信号。

    All regression checks passed (...)

或者在 targeted suite 中至少要看到：

    .....
    All regression checks passed (...)

如果资源 key 缺失时走降级分支，日志里应出现“跳过播放”之类的短消息，而不是 Lua traceback。

## 接口与依赖

本计划要求实现结束时，至少存在以下接口或等价接口。命名可以微调，但职责不能变。

在 `src/presentation/api/host_runtime/SfxRuntime.lua` 中定义安全封装：

    play_sfx_by_key(sfx_key, pos, rot, scale, duration, rate, with_sound) -> sfx_id | nil
    play_3d_sound(pos, sound_key, duration, volume) -> sound_id | nil
    bind_sfx_to_unit(sfx_id, unit, socket_name, pos, bind_type) -> boolean
    destroy_sfx(sfx_id, fade_out) -> boolean
    stop_sound(sound_id) -> boolean

在 `src/presentation/api/HostRuntimePort.lua` 中转发这些函数，使表现层只依赖 port，不直接依赖 `GameAPI` 或 `GlobalAPI`。

在 `src/presentation/render/BoardFeedbackCatalog.lua` 中维护 cue 配置。最少要覆盖这些 cue 名称：`item_stop_highlight`、`upgrade_land_smoke`、`cash_burst`、`mountain_stun`、`hospital_shock`、`mine_blast`、`tax_wave`、`rich_deity`、`angel_deity`、`move_step_pounce`、`bankruptcy_slam`、`generic_negative`、`turn_started`。其中每个 cue 需要能表达位置策略、是否绑定玩家单位、缩放、持续时间、声音 key、特效 key，以及资源缺失时是否允许跳过。

在 `src/presentation/render/BoardFeedbackService.lua` 中提供最小公共入口，例如：

    play_tile_cue(state, cue_name, tile_index, payload) -> boolean
    play_player_cue(state, cue_name, player_id, payload) -> boolean
    play_sound_only(state, cue_name, payload) -> boolean
    play_step_tile_sound(state, player_id, tile_index) -> boolean

在 `src/core/events/MonopolyEvents.lua` 中，若现有事件不足以表达需求，则补充 `feedback.turn_started`、`feedback.status_applied`、`feedback.deity_applied`、`feedback.bankruptcy` 这类稳定语义事件。已有的 `land.tile_upgraded`、`land.rent_paid`、`land.tax_paid`、`land.mine_hit`、`chance.applied` 则继续复用，不新增重复事件。

在 `src/presentation/api/UIEventHandlers.lua` 中，把这些事件翻译成 `BoardFeedbackService` 调用。这个翻译层必须知道“明确场景优先于通用负面兜底”的优先级，不能让同一个事件同时走两套互相冲突的 cue。

在 `src/presentation/render/MoveAnim.lua` 中，步进调度要能在每一步落点时调用 `play_step_tile_sound`，从而实现“进入每一格地块 -> 蛋仔前扑，每格 1 次”。

2026-03-06 / Codex：本次改动完全重写了 `.agents/plan.md`，把旧的缺陷修复封板文档替换为音效特效交付计划。这样做是因为当前用户需求已经切换到 `.agents/research.md` 的新表，继续维护旧计划会让读者误以为工作已经完成。
