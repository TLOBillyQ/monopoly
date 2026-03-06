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
- [ ] 波次 0：为 8 条研究项补齐“复现即失败”的自动化测试或最小复现场景，优先覆盖地雷自伤、强征/免费卡误触、转向掉头、无法行动自动跳过。
- [ ] 波次 1：完成规则层修复，处理 BUG-01、BUG-04、BUG-05、BUG-07、BUG-08 和 OPT-01。
- [ ] 波次 2：完成表现层修复，处理 BUG-02 与 BUG-06，并补齐多角色可见性、画布层级与点击链路验证。
- [ ] 波次 3：跑目标套件和全量回归，回填证据、风险和剩余人工走查项。

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

## 结果与复盘

当前阶段仅完成计划重建和代码落点核对，尚未开始实施修复。最大收益是把本轮工作从上一轮的“完成态文档”中剥离出来，恢复为可推进、可暂停、可重启的执行文档。接下来真正的交付风险主要有三类：一是朝向/掉头问题可能牵涉分支与黑市出口共用逻辑；二是道具广播涉及全员可见性，不能只补日志文本；三是黑市遮挡问题可能需要实机确认节点层级，而不仅是单测模拟。

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

实施顺序按依赖收敛。先在测试层把本轮研究项映射清楚。地雷支线先补两类测试：一类覆盖“埋雷后自己下一回合不会因原地命中而自伤”，另一类覆盖“地雷卡允许在行动前使用，且不会破坏既有行动后使用流程”。这些测试优先放在 `tests/suites/item.lua` 和 `tests/suites/gameplay.lua`，因为前者便于直接调用道具效果，后者便于驱动完整移动与落地。

然后处理租地与税务相关提示。`src/game/systems/land/landing_effects/BaseLandEffects.lua` 需要在弹出 `rent_prompt` 前先确认地块确实属于他人、玩家确实需要支付租金、强征卡当前可合法使用、免费卡当前有意义；`src/game/systems/land/LandRules.lua` 只保留执行规则，不承担“是否应该出现 prompt”的猜测。这里的目标是把“是否可提示”与“提示后怎么执行”拆开，避免自己地块或无效场景继续弹框。

移动转向问题集中改 `src/game/systems/board/Board.lua`。本文件当前把普通推进、黑市出口和入口分支都放在同一个 `step_forward_by_facing` 中，因此修复必须同时考虑 BUG-05 的“起步就掉头”与 BUG-08 的“频繁掉头原因不明”。处理方式是先用测试把“何时允许改变 facing”固定下来，再把“起步沿当前 facing 继续前进”和“遇到真正转弯节点时再更新 step_dir”拆成明确分支，防止用兜底邻居选择把朝向悄悄改坏。

回合跳过问题在 `src/game/flow/turn/TurnStart.lua`、`src/game/flow/turn/TurnTimerPolicy.lua` 和 presentation 面板投影之间收口。现在 `TurnStart` 对 `stay_turns > 0` 会进入 `detained_wait` 并等待 5 秒。研究项要求“无法行动时应直接跳过当前回合”，因此要把“用于表现展示的短暂停留”和“等待玩家操作”区分开：规则层应立即进入下一阶段或结束回合，展示层只能被动显示提示，不能阻塞推进。

表现层最后处理。黑市遮挡需要核对 `src/presentation/render/MarketView.lua`、`src/presentation/interaction/UIEventBindings.lua`、`src/presentation/interaction/UITouchPolicy.lua` 和始终显示区节点契约，目标是确保黑市激活时，行动日志与托管开关不会抢占黑市关闭按钮的点击。道具广播则在 `src/presentation/ui/PopupRenderer.lua` 和道具使用链路之间接桥，统一把“玩家使用了什么牌”变成全员可见的 `item_card` 或等价展示，而不是只写进行动日志。

## 具体步骤

以下命令默认在仓库根目录 `/Users/billyq/Dev/Github/Lua/monopoly` 执行。每完成一批改动，就回填“进度”和对应证据。

步骤一，固化本轮研究项的测试入口。

    rg -n "BUG-|OPT-" .agents/research.md
    lua tests/suites/item.lua
    lua tests/suites/gameplay.lua
    lua tests/suites/landing.lua
    lua tests/suites/presentation_ui.lua

预期先确认本轮只有 8 条研究项，再识别哪些问题已有测试覆盖、哪些仍需补用例。若直接执行 suite 只是导出 table，则改用 `lua tests/regression.lua` 或 `TestHarness` 驱动新增断言。

步骤二，修复地雷支线。

    lua tests/suites/item.lua
    lua tests/suites/gameplay.lua

先新增失败用例，再修改 `src/game/systems/items/ItemPostEffects.lua`、`src/game/systems/effects/MineEffect.lua`、必要时补 `src/game/systems/items/ItemPhase.lua` 或道具配置，使地雷既不会自伤，又支持研究要求的行动前使用。预期结果是：埋雷玩家留在原地或进入下一回合时不被自己刚埋的雷命中；行动前也能正常释放地雷卡。

步骤三，修复租地卡提示误触。

    lua tests/suites/landing.lua
    lua tests/suites/gameplay.lua

修改 `src/game/systems/land/landing_effects/BaseLandEffects.lua`，必要时补充 `src/game/systems/land/LandChoiceSpecs.lua` 和 `src/game/systems/land/LandRules.lua` 的测试约束。预期结果是：只有踩到他人可结算地块且卡片确实有效时，才会出现“是否使用强征卡/免费卡”。

步骤四，修复移动朝向与掉头。

    lua tests/suites/gameplay.lua

围绕 `src/game/systems/board/Board.lua` 增加最小路径场景，覆盖直行、真正转弯、黑市出口和分支入口。预期结果是：玩家不会从起步位置就反向，只有在路径拓扑要求转弯时才改变方向。

步骤五，修复“无法行动时未自动跳过”。

    lua tests/suites/gameplay.lua
    lua tests/suites/presentation_ui.lua

修改 `src/game/flow/turn/TurnStart.lua`、`src/game/flow/turn/TurnTimerPolicy.lua` 以及依赖的 UI 状态投影。预期结果是：玩家住院、深山或其他明确无行动权的状态下，回合会自动推进，不再停在等待交互的界面。

步骤六，修复黑市遮挡和出牌广播。

    lua tests/suites/presentation_ui.lua
    lua tests/suites/landing.lua

先让黑市关闭按钮被稳定点击，再把道具使用的展示广播接到全员可见链路。预期结果是：黑市打开时，“黑市_关闭”始终可用；任意玩家出牌时，其他玩家也能看到明确的牌名展示。

步骤七，完成全量回归与文档封板。

    lua tests/regression.lua

预期输出应包含全量通过的检查数。若某条研究项仍只能手工验证，例如 UI 节点真实层级与多分辨率点击热区，则必须把该项保留在“结果与复盘”，写清未自动化原因和手工验收步骤。

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
