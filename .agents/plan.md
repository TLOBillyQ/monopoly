# 基于 `.agents/research.md` 的研究交付可执行计划

本可执行计划是活文档。实施过程中必须持续更新“进度”“意外与发现”“决策日志”“结果与复盘”。

本文件必须遵循 `.agents/harness/PLANS.md` 维护，讨论、实施、暂停和重启都以该规范为准。本文已内嵌当前仓库完成这轮研究交付所需的背景，不依赖聊天历史。

## 目的 / 全局视角

`.agents/research.md` 当前定义了 8 条待交付项，范围集中在地雷、黑市遮挡、租地道具提示、骰子转向、道具广播和“无法行动”回合处理。用户需要的不是一份泛泛的问题清单，而是一份能让新接手的人从零把这 8 条逐项修完、逐项验证的执行文档。

这轮交付完成后，玩家在完整对局中应看到这些可观察变化：地雷不会炸到埋设者自己；黑市关闭按钮在行动日志与托管开关存在时仍可点击；强征卡和免费卡只在满足条件时才弹确认；移动不会从起点就错误掉头；其他玩家出牌时全员都能看到是什么牌；被扣留或其他“本回合无法行动”的场景会自动跳过，不再要求玩家额外交互；地雷卡可在行动前使用，能与清障/路障策略联动。验收不以“改了哪些文件”为准，而以这些行为可以被测试和手工复现为准。

## 进度

- [x] (2026-03-06 14:18+08:00) 已重读 `.agents/research.md`、`.agents/harness/PLANS.md` 和旧 `.agents/plan.md`，确认旧计划属于上一轮 20 项修复，已不适用于本轮 8 项研究交付。
- [x] (2026-03-06 14:27+08:00) 已完成问题映射：地雷对应 `src/game/systems/items/ItemPostEffects.lua` 与 `src/game/systems/effects/MineEffect.lua`；强征/免费卡对应 `src/game/systems/land/landing_effects/BaseLandEffects.lua` 与 `src/game/systems/land/LandRules.lua`；转向问题对应 `src/game/systems/board/Board.lua`。
- [x] (2026-03-06 14:31+08:00) 已确认 UI 与回合主链落点：黑市遮挡集中在 `src/presentation/*`，无法行动跳过集中在 `src/game/flow/turn/TurnStart.lua`、`src/game/flow/turn/TurnTimerPolicy.lua` 与相关 presentation 状态投影。
- [x] (2026-03-06 14:41+08:00) 已将计划从“按波次”细化到“按研究项编号”颗粒度，补齐每条问题的目标文件、建议测试落点、验收口径和依赖顺序。
- [x] (2026-03-06 14:49+08:00) 已将“进度”章节改为细颗粒执行清单，后续按“测试补齐 -> 规则修复 -> 表现修复 -> 回归封板”逐项更新，不再只记录粗波次。
- [x] (2026-03-06 13:48+08:00) 已补齐执行映射并按支线落地：BUG-01/OPT-01 首选 `tests/suites/item.lua` + `tests/suites/gameplay.lua`；BUG-04 首选 `tests/suites/item.lua`；BUG-05/BUG-08/BUG-07 首选 `tests/suites/gameplay.lua`；BUG-02/BUG-06 首选 `tests/suites/presentation_ui.lua`，租地卡广播补 `tests/suites/landing.lua`。
- [x] (2026-03-06 13:48+08:00) BUG-01 / OPT-01 已完成测试、修复与验收，提交 `2918a4e Fix mine arming and pre-action availability`。证据：`tests/suites/item.lua` 覆盖地雷卡出现在 `pre_action`；`tests/suites/gameplay.lua` 覆盖埋雷者离开前不自伤、其他玩家触发已武装地雷；目标套件通过。
- [x] (2026-03-06 13:48+08:00) BUG-04 已完成测试、修复与验收，提交 `58e2ce1 Hide rent cards outside valid landing contexts`。证据：`tests/suites/item.lua` 覆盖自己地块隐藏强征卡/免费卡、他人地块保留提示；目标套件通过。
- [x] (2026-03-06 13:48+08:00) BUG-05 / BUG-08 已完成测试、修复与验收，提交 `3bc36fd Ignore stale move_dir on fresh rolls`。证据：`tests/suites/movement.lua` 新增 fresh roll 忽略陈旧 `move_dir` 断言；目标套件通过。
- [x] (2026-03-06 13:48+08:00) BUG-07 已完成测试、修复与验收，提交 `67b5342 Skip detained turns without blocking`。证据：`tests/suites/gameplay.lua` 覆盖无法行动回合立即跳过；`tests/suites/presentation_ui.lua` 覆盖自动跳过后医院/深山状态仍可投影；两套件分别通过 `41` 与 `126` 检查。
- [x] (2026-03-06 13:48+08:00) BUG-02 已完成测试、修复与验收，提交 `1f3c98a Prioritize market close over always-show controls`。证据：`tests/suites/presentation_ui.lua` 新增黑市激活时托管按钮/行动日志让出触摸优先级断言；套件通过 `126` 检查。实机点击尚未在引擎里复核，但纯 Lua 触控路由已收口。
- [x] (2026-03-06 13:48+08:00) BUG-06 主链已完成测试、修复与验收，提交 `ed89f99 Broadcast used items to all players`。证据：`tests/suites/item.lua` 覆盖普通道具、目标道具、后续选择型道具与偷窃成功广播；`tests/suites/presentation_ui.lua` 既有 `item_card` 全员可见断言继续通过。
- [x] (2026-03-06 13:48+08:00) BUG-06 租地/税务旁路已补齐并提交 `8e54288 Broadcast rent and tax cards to all players`。证据：`src/game/systems/land/LandRules.lua` 已接入统一 `ItemUseBroadcast`，`tests/suites/landing.lua` 新增强征卡/免费卡/免税卡广播断言并通过 `16` 检查。
- [ ] (2026-03-06 13:48+08:00) 全量回归已执行两次，当前仍卡在 `lua tests/regression.lua` 的单一失败：`chance.chance_move_backward_pass_intersection`（`tests/suites/chance.lua:58`）。最新结果为 `Regression failed (1/314)`；本轮目标支线相关套件均已通过，但全量未全绿。
- [x] (2026-03-06 13:48+08:00) 文档已回填当前真实状态：已记录提交、套件结果、剩余回归风险与未做的实机项，不再保留“尚未实施修复”的过期描述。

## 意外与发现

- 观察：当前 `.agents/research.md` 只有 8 条研究结论，但旧 `.agents/plan.md` 仍是上一轮“20 项反馈已完成”的封板文档，直接继续维护会误导实施顺序和验收口径。
  证据：旧计划正文大量引用“20 项反馈”“296 checks 全绿”等上一轮结论，且进度几乎全部打勾。

- 观察：地雷当前通过 `src/game/systems/items/ItemPostEffects.lua` 的 `_handle_place_mine_here` 直接埋在 `player.position`，而触发在 `src/game/systems/effects/MineEffect.lua` 与 `src/game/systems/land/landing_effects/SpecialTileEffects.lua`。
  证据：`place_mine_here` 直接执行 `game.board:place_mine(player.position)`；地雷命中由 `board:has_mine(position)` 驱动。

- 观察：租地提示链当前只判断“有没有卡”和“钱够不够强征”，没有先判断当前地块是否允许强征或免费。
  证据：`src/game/systems/land/landing_effects/BaseLandEffects.lua` 的 `_apply_pay_rent` 在发现 `strong_idx` 或 `free_idx` 后直接进入 prompt/使用分支，研究项指出“自己地块上不该弹确认”。

- 观察：棋盘朝向问题不是 UI 动画问题，而是规则层路径推进问题；`src/game/systems/board/Board.lua` 同时负责按 facing 精确推进和黑市出口转向。
  证据：`step_forward_by_facing` 在入口点、黑市出口和普通邻接三段逻辑里都计算 `next_id` 和 `step_dir`。

- 观察：当前日志系统 `src/core/Logger.lua` 会出 tip，但“其他玩家使用了什么牌”是否能全员看到，仍取决于 presentation 是否把道具展示做成全角色可见的 popup 或全局提示。
  证据：`logger.event` 只调用 `GlobalAPI.show_tips`；而可被全员看到的卡牌展示目前由 `PopupRenderer` 处理 `chance_card`、`item_card`、`bankruptcy`。

- 观察：`detained_wait_active` 在旧链路里同时承担输入阻塞、倒计时和“本回合无法行动”提示三种职责，导致 BUG-07 很难只修规则不动 UI。
  证据：`TurnStart.lua` 会进入 `detained_wait`；`TurnTimerPolicy.lua` 用它驱动 5 秒跳过；`PanelSlice.lua` 与 `status3d_service/status.lua` 又用同一标记做表现判断。

- 观察：BUG-06 的广播漏点不只在 `ItemExecutor` 主链，`LandRules.execute_strong_card`、`execute_free_card`、`execute_tax_free_card` 也会直接消费卡片并绕过通用广播。
  证据：三条函数都直接 `inventory.consume(...)`，直到本轮补入 `ItemUseBroadcast` 前都没有任何 `push_popup` 语义。

- 观察：全量回归当前唯一失败是 `chance.chance_move_backward_pass_intersection`，和本轮已修改文件没有直接交叉，但它仍阻塞“封板全绿”。
  证据：`lua tests/regression.lua` 两次均报 `Regression failed (1/314)`，失败断言固定在 `tests/suites/chance.lua:58`。

## 决策日志

- 决策：本轮 `.agents/plan.md` 完全按 `.agents/research.md` 当前 8 条结论重建，不继承旧计划里的“已完成”状态。
  理由：旧计划目标和研究范围已经变更，继续局部修补会让“本轮待交付项”与“历史封板状态”混在一起，失去活文档价值。
  日期/作者：2026-03-06 / Codex

- 决策：先补复现入口，再修规则，再修表现，最后统一回归。
  理由：BUG-01、BUG-04、BUG-05、BUG-07、BUG-08 都是规则层问题，若没有先固化复现，后续表现层改动会掩盖真实回归面。
  日期/作者：2026-03-06 / Codex

- 决策：OPT-01 与 BUG-01 一并处理，统一放在“道具/地雷”支线收口。
  理由：两项都落在地雷使用时机和地雷命中语义上，拆开做容易在 Item timing、路径推进和测试夹具上重复返工。
  日期/作者：2026-03-06 / Codex

- 决策：计划执行单元按 5 条支线拆解，而不是继续只写“规则层/表现层”大波次。
  理由：本轮问题量不大，但跨规则、UI、回合和广播链路；若不细化到编号级别，执行时仍要临场二次拆任务，降低可重启性。
  日期/作者：2026-03-06 / Codex

- 决策：进度跟踪按“每个编号的测试、修复、验收”三段拆开记录，不再只维护波次级状态。
  理由：用户要求“进度细化”，而且本轮真正影响执行效率的是每条研究项做到哪一步，而不是只知道还处在某个大波次。
  日期/作者：2026-03-06 / Codex

- 决策：BUG-07 不再复用 `detained_wait_active` 作为阻塞态，而是新增 `no_action_notice_*` 作为纯展示信号。
  理由：规则层需要立即跳过，但医院/深山等状态仍需在切到下一玩家前留一帧可见提示；拆信号比继续滥用等待态更稳。
  日期/作者：2026-03-06 / Codex

- 决策：BUG-02 只在 `market_active == true` 时收回始终显示区的可点击权限，不重写黑市关闭事件。
  理由：研究项的核心是“关闭按钮不被抢点击”，用触控优先级收口比改事件绑定和面板层级更小、更可测。
  日期/作者：2026-03-06 / Codex

- 决策：BUG-06 统一走 `src/game/systems/items/ItemUseBroadcast.lua` 发 `kind="item_card"` 的 popup，并把 `LandRules` 里的租地/税务卡消费旁路也接进来。
  理由：`PopupRenderer` 已经把 `item_card` 定义为全员可见；复用它能最小化改动面，同时避免每个 item handler 各自拼广播 payload。
  日期/作者：2026-03-06 / Codex

## 结果与复盘

本轮计划对应的 8 条研究项已经实质执行完毕，且已拆成 7 个逻辑提交：`2918a4e`、`58e2ce1`、`3bc36fd`、`67b5342`、`1f3c98a`、`ed89f99`、`8e54288`。规则层已收口地雷、租地卡提示、朝向、无法行动自动跳过；表现层已收口黑市触控优先级和 `item_card` 全员广播。

自动化证据方面，目标套件当前结果是：`tests/suites/item.lua` 通过 `22` 检查，`tests/suites/landing.lua` 通过 `16` 检查，`tests/suites/gameplay.lua` 通过 `41` 检查，`tests/suites/presentation_ui.lua` 通过 `126` 检查。未完成项只剩两类：一是 `lua tests/regression.lua` 仍有 `chance.chance_move_backward_pass_intersection` 单点失败，因此还不能宣称全量封板；二是黑市关闭按钮还缺一次引擎内实机热区确认。

当前剩余风险比计划初稿显著收窄。真正需要继续跟踪的只有两项：第一，黑市关闭按钮虽然在纯 Lua 触控路由里已不会被始终显示区抢点击，但仍建议在引擎里做一次实机热区确认；第二，机会卡倒退穿过交叉口的旧失败仍需单独处理或与用户确认是否属于本轮范围。

## 背景与导读

这轮工作主要跨三块区域。第一块是规则层，负责玩家状态、地块结算和精确移动，核心文件在 `src/game/systems/` 与 `src/game/flow/turn/`。其中 `src/game/systems/items/ItemPostEffects.lua` 处理行动前后道具的立即效果，`src/game/systems/effects/MineEffect.lua` 处理地雷命中结果，`src/game/systems/land/landing_effects/BaseLandEffects.lua` 处理落到别人地块、税务局等结算，`src/game/systems/board/Board.lua` 负责按朝向推进一步，`src/game/flow/turn/TurnStart.lua` 和 `src/game/flow/turn/TurnTimerPolicy.lua` 负责回合开始和“被扣留等待”收口。

第二块是表现层，负责黑市、行动日志、全局弹窗和多角色可见性，主要在 `src/presentation/`。`src/presentation/render/MarketView.lua` 负责黑市面板刷新和关闭，`src/presentation/interaction/UIEventBindings.lua` 与 `src/presentation/interaction/UITouchPolicy.lua` 负责始终显示区按钮注册和触控开关，`src/presentation/ui/PopupRenderer.lua` 负责“机会卡/道具卡/破产”展示。

第三块是测试层，位于 `tests/suites/`。`tests/suites/item.lua` 适合覆盖地雷卡与行动前后道具时机，`tests/suites/gameplay.lua` 适合覆盖移动、转向和回合推进，`tests/suites/landing.lua` 适合覆盖落地结算与 popup，`tests/suites/presentation_ui.lua` 适合覆盖黑市按钮、画布层级、popup 可见性与关闭链路。全量回归入口是 `tests/regression.lua`。

术语说明如下。“误触”不是 UI 点击误触，而是系统在不满足使用条件时仍然弹出“是否使用”确认。“掉头”指玩家沿棋盘移动时，行进方向在不该发生转弯的位置被错误改成反方向。“无法行动”指玩家因住院、深山、扣留或其他状态，本回合应该直接结束，而不是继续等待按钮或倒计时。“广播”在本计划中指所有玩家都能看到这次出牌的名称与展示，不只是本地行动玩家收到一条日志。

## 里程碑

里程碑一是“建立可信复现”。完成后，每条研究项至少有一个稳定入口可以证明问题存在或行为未被覆盖。这里不要求一次修好全部问题，但要求后续每个修复都能绑定到对应测试。验收方式是在仓库根目录运行目标套件，新增测试在改动前失败、改动后通过。

里程碑二是“收敛规则层”。完成后，地雷、自伤、强征/免费卡误提示、骰子转向和无法行动自动跳过都必须在逻辑层收口，不依赖 UI 特判。验收方式是 `tests/suites/item.lua`、`tests/suites/gameplay.lua`、`tests/suites/landing.lua` 的相关断言通过，并在最小手工局里复现出正确行为。

里程碑三是“收敛表现层”。完成后，黑市关闭按钮可点，道具使用会向全员展示，且不破坏现有 popup/choice/market 的模态切换。验收方式是 `tests/suites/presentation_ui.lua` 通过，并在实际 UI 中验证关闭按钮不再被始终显示区覆盖。

里程碑四是“封板与回填”。完成后，`lua tests/regression.lua` 全绿，本文件四个活文档章节已补齐，剩余必须手工验证的事项被明确记录，不留口头约定。

## 工作计划

实施顺序按依赖收敛，但执行单位改成五条支线。第一条是 BUG-01 与 OPT-01 的“地雷支线”，先把地雷自伤和行动前释放一起收口。第二条是 BUG-04 的“租地道具提示支线”，只处理强征卡和免费卡的出现条件。第三条是 BUG-05 与 BUG-08 的“朝向推进支线”，统一处理掉头和转向判定。第四条是 BUG-07 的“无法行动支线”，只处理回合自动跳过与 UI 投影。第五条是 BUG-02 与 BUG-06 的“表现支线”，处理黑市关闭按钮和出牌广播。

每条支线都遵守同一个顺序：先补一个能稳定失败的测试或最小复现场景，再改目标文件，再跑受影响套件，最后回填文档证据。这样即使中途停止，下一位接手者也能直接从当前支线恢复，不需要再猜“这一波到底做到哪”。

规则层优先于表现层，因为本轮大部分问题都不是 UI 表象，而是规则条件不准确。地雷、自伤、强征/免费卡误提示、掉头和无法行动都必须先在规则层收口，否则 presentation 层只是在掩盖症状。表现层只在规则层验证通过后再接上，避免在错误状态机上补 UI 特判。

黑市遮挡和出牌广播放在最后，不是因为它们不重要，而是因为它们更依赖已经稳定的 choice、popup 和 market 状态。只有当前面的回合推进与道具逻辑固定后，表现层断言才不会频繁漂移。

## 按研究项拆解

### BUG-01 与 OPT-01：地雷自伤 + 行动前释放

这一支线的目标是同时解决“埋下的雷会炸到自己”和“地雷卡只能在行动后使用”两个问题。实现时先检查 `Config/Generated/Items.lua` 中地雷卡 `timing` 与 `src/game/systems/items/ItemPhase.lua` 的过滤逻辑是否一致。如果仅靠配置即可把地雷纳入 `pre_action`，优先走配置修正；如果 `manual` 在仓库中还有其他语义，再在 `ItemPhase` 或相关道具选择逻辑中为地雷卡补一个明确的行动前入口，但不要破坏现有道具阶段。

自伤问题优先在 `src/game/systems/items/ItemPostEffects.lua`、`src/game/systems/effects/MineEffect.lua` 和可能的移动/落地入口之间排查。需要把“埋雷当回合的落脚点”和“其他玩家经过该格触发地雷”的语义明确区分。若当前棋盘覆盖物只记录布尔值，就要在不破坏现有接口的前提下补最小必要的来源信息，例如埋设者或生效时机；但新增字段必须维持 `board:get_overlays()` 的兼容返回结构，不能把 presentation 层一起拖进大改。

测试先补在 `tests/suites/item.lua` 与 `tests/suites/gameplay.lua`。`item.lua` 负责验证地雷卡能出现在行动前道具阶段，并且使用后仍会返回现有地雷动画标记。`gameplay.lua` 负责驱动一个最小回合：玩家 A 埋雷后结束回合，再轮到玩家 A 或玩家 B 行动，分别验证“自己不会被刚埋的雷炸到”和“其他玩家经过时仍会正常触发”。验收通过后，再把 OPT-01 的行为写进本计划“结果与复盘”。

### BUG-04：强征卡 / 免费卡误触

这一支线只收口提示条件，不重写强征和免费卡的执行规则。目标文件是 `src/game/systems/land/landing_effects/BaseLandEffects.lua`，因为当前 prompt 是从 `_apply_pay_rent` 发起的。`src/game/systems/land/LandRules.lua` 保持为执行层，继续负责“已经决定使用后怎么扣钱/转移地块/免租”。

细化口径如下。只有玩家落到他人地块、当前确实存在租金结算、强征卡支付金额可覆盖、免费卡能免除本次租金时，才允许出现相应 prompt。落在自己地块、无主地块、被深山跳租的地块、或本次无须支付租金的场景，都不应出现强征卡/免费卡确认。若强征不可用但免费卡可用，应只出现免费卡 prompt，而不是先弹强征再级联到免费卡。

测试建议落在 `tests/suites/landing.lua` 与必要的 choice handler 定向用例。最少需要三个场景：自己地块不弹；他人地块且可强征时弹强征；强征不可用但可免租时只弹免费卡。若 `src/game/systems/choices/ChoiceHandlers/LandChoiceHandler.lua` 现有链路会在 skip 后自动切到免费卡，也要加一条断言，证明不会再从一个本不该出现的强征 prompt 兜转到免费卡 prompt。

### BUG-05 与 BUG-08：骰子方向判断错误 + 频繁掉头

这条支线统一处理 `src/game/systems/board/Board.lua` 的 `step_forward_by_facing`。当前函数同时承载普通前进、入口点切换和黑市出口转向，因此细化时必须先把这三种情况拆开看，而不是直接在兜底选邻居逻辑上做热补丁。

这里的核心决策是：移动开始后，玩家应先沿当前 facing 继续前进；只有走到真正需要转弯的拓扑节点时，才允许更新 `step_dir`。这意味着“当前位置的 facing”和“下一步的方向”不能被 `_pick_any_dir` 这种兜底逻辑提前覆写。若必须兜底，也只能在 facing 不存在、地图邻接缺失或测试构造的极小地图不完整时使用，并且要优先避免反向。

测试必须覆盖四种路径：普通直行、正常拐角、黑市出口、入口点奇偶分支。建议优先补在 `tests/suites/gameplay.lua`，因为该套件已经覆盖移动与中断链路。每个用例都需要同时断言 `next_index` 和 `step_dir`，否则容易出现“位置对了但朝向错了”的假通过。对 BUG-08，要额外留一条“连续多步移动中不出现来回反向”的回归断言，而不是只测单步。

### BUG-07：无法行动时未自动跳过

这一支线聚焦 `src/game/flow/turn/TurnStart.lua`、`src/game/flow/turn/TurnTimerPolicy.lua`、`src/game/flow/turn/GameplayLoopTickSteps.lua` 和 presentation 的 `PanelSlice`。当前实现会把 `stay_turns > 0` 的玩家送入 `detained_wait` 并停 5 秒，这对“展示本回合无法行动”是友好的，但对“规则上应立即跳过”是不符合研究结论的。

这里需要拍板的行为是：规则层立即跳过，展示层如有需要只显示短暂提示，不得阻塞 turn loop。实现时优先保证 `TurnStart` 不再把无行动权玩家停在需要 tick 等待才能结束的状态。如果 presentation 仍需要 `detained_wait_active` 来展示“本回合无法行动”，就把它视为纯展示信号，并确保不会阻塞 `step_turn` 继续推进。

测试必须至少有两层。`tests/suites/gameplay.lua` 要验证无行动权玩家进入回合后能直接结束并切换到下一玩家，而不是停在 `detained_wait`。`tests/suites/presentation_ui.lua` 要验证 UI 仍能显示“本回合无法行动”提示或住院/深山状态，不会因为规则层去掉等待而丢失表现。这样才能避免“修掉等待，同时也修没了提示”的回归。

### BUG-02：行动日志 / 自动开关遮挡黑市关闭按钮

这条支线优先保证可点击，其次再处理真实层级。目标文件集中在 `src/presentation/render/MarketView.lua`、`src/presentation/interaction/UIEventBindings.lua`、`src/presentation/interaction/UITouchPolicy.lua`、`src/presentation/interaction/UIInputLockPolicy.lua` 和始终显示区节点契约。当前已知问题不是黑市关闭逻辑本身缺失，而是始终显示区的行动日志或托管按钮在黑市打开时仍处于可交互态，导致关闭按钮被抢点击。

计划里的执行口径是双保险。第一层在纯 Lua 运行时先保证当 `ui.market_active == true` 时，冲突按钮不会拦截黑市关闭区域的输入。第二层如果引擎支持明确层级或触摸穿透设置，再补实机层级修正。这样即使最终无法在单元测试里证明 z-order，也能先保证功能正确，再把真正层级问题留给手工走查补录。

测试建议在 `tests/suites/presentation_ui.lua` 追加两类断言。一类验证黑市打开后，关闭按钮点击仍发出 `choice_cancel` 且 choice_id 不丢。另一类验证市场激活状态下，行动日志和托管相关节点的 touch policy 被正确调整，不再与关闭按钮竞争。这样比只测 `close_market_panel` 更贴近研究项本身。

### BUG-06：出牌广播缺失

这一支线的目标不是“日志里多一行字”，而是“所有玩家都知道用了什么牌”。实现时先梳理当前出牌链。卡牌使用在规则层多由 `src/game/systems/items/ItemPostEffects.lua`、`src/game/systems/items/ItemHandlers.lua`、`src/game/systems/choices/ChoiceHandlers/ItemChoiceHandler.lua` 触发；而全员可见展示主要走 `src/presentation/ui/PopupRenderer.lua` 支持的 `item_card` 类型。

本计划要求优先复用现有 popup 语义，而不是新增一套只存在于日志层的广播协议。也就是说，道具成功使用后，要有一个统一出口把“玩家名 + 道具名 + 必要图片引用”送到 popup 或等价的全员展示链路。若不同道具分散在多个 handler 中，不要每个地方各自拼 payload；应提取一个最小公共入口，避免以后继续漏广播。

测试建议双层覆盖。`tests/suites/landing.lua` 或新增定向 suite 负责断言道具使用会生成正确的展示 payload。`tests/suites/presentation_ui.lua` 负责断言该展示对当前玩家和其他玩家都可见，而不是只在本地角色上触发。验收时至少要拿一个普通道具和一个目标型道具各跑一遍，防止只修了一种出牌链。

## 具体步骤

以下命令默认在仓库根目录 `/Users/billyq/Dev/Github/Lua/monopoly` 执行。每完成一批改动，就回填“进度”和对应证据。

步骤一，先建立一份“研究项 -> 测试 -> 目标文件”的执行记录，再开始写代码。

    rg -n "BUG-|OPT-" .agents/research.md
    rg -n "mine|地雷|pre_action|post_action" tests/suites/item.lua tests/suites/gameplay.lua
    rg -n "rent_prompt|强征卡|免费卡" tests/suites/landing.lua src/game/systems/land
    rg -n "market_close|黑市_关闭|行动日志|托管按钮" tests/suites/presentation_ui.lua src/presentation
    rg -n "detained_wait|stay_turns|被扣留" tests/suites/gameplay.lua src/game/flow/turn
    lua tests/suites/item.lua
    lua tests/suites/gameplay.lua
    lua tests/suites/landing.lua
    lua tests/suites/presentation_ui.lua

预期先确认本轮只有 8 条研究项，再识别哪些问题已有测试覆盖、哪些仍需补用例。输出需要回填到本文件“进度”中，写明每条研究项的首选 suite。若直接执行 suite 只是导出 table，则改用 `lua tests/regression.lua` 或 `TestHarness` 驱动新增断言。

步骤二，只做地雷支线，收口 BUG-01 与 OPT-01，不夹带其他规则问题。

    lua tests/suites/item.lua
    lua tests/suites/gameplay.lua

先新增失败用例，再修改 `src/game/systems/items/ItemPostEffects.lua`、`src/game/systems/effects/MineEffect.lua`、必要时补 `src/game/systems/items/ItemPhase.lua` 或 `Config/Generated/Items.lua`，使地雷既不会自伤，又支持研究要求的行动前使用。完成后只跑 item/gameplay 两个套件，不急着回归全量。预期结果是：埋雷玩家留在原地或进入下一回合时不被自己刚埋的雷命中；行动前也能正常释放地雷卡。

步骤三，只做租地提示支线，收口 BUG-04。

    lua tests/suites/landing.lua
    lua tests/suites/gameplay.lua

修改 `src/game/systems/land/landing_effects/BaseLandEffects.lua`，必要时补充 `src/game/systems/land/LandChoiceSpecs.lua`、`src/game/systems/choices/ChoiceHandlers/LandChoiceHandler.lua` 和 `src/game/systems/land/LandRules.lua` 的测试约束。预期结果是：只有踩到他人可结算地块且卡片确实有效时，才会出现“是否使用强征卡/免费卡”。

步骤四，只做朝向推进支线，统一收口 BUG-05 与 BUG-08。

    lua tests/suites/gameplay.lua

围绕 `src/game/systems/board/Board.lua` 增加最小路径场景，覆盖直行、真正转弯、黑市出口和分支入口。每次改动后都重跑 gameplay 套件，直到 `next_index + step_dir` 两类断言同时稳定。预期结果是：玩家不会从起步位置就反向，只有在路径拓扑要求转弯时才改变方向。

步骤五，只做“无法行动时未自动跳过”，收口 BUG-07。

    lua tests/suites/gameplay.lua
    lua tests/suites/presentation_ui.lua

修改 `src/game/flow/turn/TurnStart.lua`、`src/game/flow/turn/TurnTimerPolicy.lua`、必要时补 `src/game/flow/turn/GameplayLoopTickSteps.lua` 与依赖的 UI 状态投影。预期结果是：玩家住院、深山或其他明确无行动权的状态下，回合会自动推进，不再停在等待交互的界面；同时 UI 仍能显示“本回合无法行动”。

步骤六，最后处理表现支线，先 BUG-02，再 BUG-06。

    lua tests/suites/presentation_ui.lua
    lua tests/suites/landing.lua

先让黑市关闭按钮被稳定点击，再把道具使用的展示广播接到全员可见链路。处理 BUG-02 时优先保证可点击，其次再看实机层级是否仍需修正。处理 BUG-06 时优先复用 `item_card` 语义，不新增分散协议。预期结果是：黑市打开时，“黑市_关闭”始终可用；任意玩家出牌时，其他玩家也能看到明确的牌名展示。

步骤七，完成全量回归与文档封板。

    lua tests/regression.lua

预期输出应包含全量通过的检查数。若某条研究项仍只能手工验证，例如 UI 节点真实层级与多分辨率点击热区，则必须把该项保留在“结果与复盘”，写清未自动化原因和手工验收步骤。同时把每条编号对应的最终证据回填到“进度”中，而不是只在结尾写一句“全部完成”。

## 验证与验收

验收必须对应 `.agents/research.md` 的 8 条项，而不是抽象地说“逻辑正常”。BUG-01 的验收是：玩家埋雷后不会在自己下一次起步或原地阶段因同格地雷而送医。BUG-02 的验收是：黑市打开时，行动日志图标和托管开关存在也不影响关闭按钮点击。BUG-04 的验收是：在自己地块或其他不满足条件的地块上，不会弹出强征卡/免费卡确认。BUG-05 与 BUG-08 的验收是：移动方向只在真正转弯时变化，不会无缘无故掉头。BUG-06 的验收是：其他玩家能看到出牌名称，而不是只有当前玩家或日志知道。BUG-07 的验收是：明确无行动权时直接跳过回合。OPT-01 的验收是：地雷卡可在行动前释放，并与已有行动流程兼容。

自动化验收最少包含以下命令：

    lua tests/suites/item.lua
    lua tests/suites/gameplay.lua
    lua tests/suites/landing.lua
    lua tests/suites/presentation_ui.lua
    lua tests/regression.lua

如果某项修复前没有测试，必须先补测试并记录“变更前失败、变更后通过”的证据。若某个 UI 层级问题只能在引擎里看见，自动化测试应至少覆盖状态、事件和触控路由，手工再补最终点击验证。

## 可重复性与恢复

本计划按小步提交推进，可重复执行。每次只修一条研究项或一条紧密耦合的支线，先跑目标套件，再跑全量回归。遇到失败时不要破坏性回退，先根据新增测试或回归输出定位是哪一层出了问题，再最小化修改重跑。表现层问题如果在纯 Lua 环境无法完全证明，应保留自动化保护并补一条明确的实机复现步骤，而不是删测试或口头跳过。

数值相关逻辑必须遵守仓库约束：新增代码禁止使用 `tonumber`、`type(...) == "number"` 或类似写法，统一使用 `src/core/NumberUtils.lua`。这项约束也适用于测试代码。

## 产物与备注

本轮交付的最终产物应只有三类。第一类是规则修复代码，落在道具、落地结算、朝向推进和回合跳过链路。第二类是表现修复代码，落在黑市关闭按钮触控链路和全员可见的道具展示。第三类是测试与文档产物，证明 8 条研究项被逐项验证，并把剩余人工项写清楚。

建议在收尾时保留以下短证据片段，写回本文件，不要只留在终端历史里：

    All regression checks passed (N)
    [event] ... 在脚下埋设地雷
    [event] ... 使用强征卡 ...
    [MarketDebug] ... view_refresh ...

## 接口与依赖

这轮改动涉及的稳定接口如下。规则层继续使用 `src/game/*` 现有入口，不要把 presentation 特判写回规则模块。黑市与 popup 相关显示统一通过 `src/presentation/*` 与 `ui_view`、`modal_presenter` 链路处理，不在业务逻辑里直接散落 UI 原生调用。需要给其他玩家展示出牌时，优先复用 `item_card` / popup 语义，而不是新造一套只存在于日志层的临时协议。

`src/game/systems/board/Board.lua` 的 `step_forward_by_facing` 是本轮高风险接口，修改时必须保证它对黑市出口、分支入口和普通路径都保持一致口径。`src/game/flow/turn/TurnStart.lua` 与 `src/game/flow/turn/TurnTimerPolicy.lua` 的职责边界也要保持清楚：前者决定当前玩家是否拥有行动权，后者只负责时间驱动，不负责替用户做规则判断。

数值判断统一使用 `src/core/NumberUtils.lua`。这是硬约束，不允许在新增代码或测试里引入 `tonumber`、`type(...) == "number"`、`type(...) ~= "number"`。

文末变更说明（2026-03-06 14:33+08:00）：将 `.agents/plan.md` 从上一轮“20 项反馈全量修复”的完成态文档，重写为基于当前 `.agents/research.md` 8 条研究结论的可执行计划。原因是旧计划与当前研究范围不一致，继续沿用会误导本轮交付、进度和验收。
文末变更说明（2026-03-06 14:41+08:00）：将计划从“按波次说明”进一步细化为“按研究项编号拆解”，为每条问题补充目标文件、测试落点、执行顺序和验收口径。原因是用户要求“计划细化”，需要把文档提升到可直接按编号执行的颗粒度。
文末变更说明（2026-03-06 14:49+08:00）：将“进度”章节从粗波次状态进一步细化为“每个编号的测试、修复、验收”清单，并同步补充对应决策与阶段描述。原因是用户要求“进度细化”，需要让后续执行与暂停恢复都能直接定位到具体步骤。
