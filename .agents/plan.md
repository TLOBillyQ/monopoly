# 开发反馈全量修复可执行计划（基于 `.agents/research.md`）

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件必须遵循 `.agents/harness/PLANS.md` 维护，实施与讨论都要以该规范为准。本文已经内嵌当前仓库完成这项工作所需的背景，不依赖外部上下文。

## 目的 / 全局视角

当前仓库已经有较完整的大富翁主流程与回归测试，但 `.agents/research.md` 汇总的 21 条反馈仍存在真实缺陷、配置错误、流程割裂和体验问题。目标是把这些反馈按可验证行为全部落地修复，并保证回归不倒退。改动完成后，玩家能够在完整对局中稳定经历正确的税务、黑市、道具、破产和 UI 流程，不再出现“无条件破产”“商城购买后卡住”“出局玩家仍需操作”等错误行为。

本计划不是“改代码清单”，而是“可被新手从零执行并验证”的完整实施说明。每个修复都必须对应可观察行为，必须有测试或复现场景证明，且全量回归要通过。

## 进度

- [x] (2026-03-05 18:34+08:00) 已完成输入梳理：读取 `.agents/research.md`、`.agents/harness/PLANS.md`、`docs/eggy/*.md`，确认计划约束与反馈范围。
- [x] (2026-03-05 18:35+08:00) 已完成计划重建：将 `.agents/plan.md` 切换为“开发反馈全量修复”主题并覆盖旧 release 主题。
- [ ] 波次 0 / SA-1：建立 21 项“反馈 -> 复现用例 -> 验收断言”矩阵，并在测试目录落地占位用例。
- [ ] 波次 0 / SA-2：扩展 `tests/internal/forbidden_globals.lua` 扫描范围到 `src + tests + scripts`，形成数值 API 守门。
- [ ] 波次 0 / SA-3：固化付费宿主契约桩（`get_goods_list/show_goods_purchase_panel/SPEC_ROLE_PURCHASE_GOODS`），补齐失败路径模拟。
- [ ] 波次 0 / SA-4：外部商品映射核对记录（goods_id、币种、回调语义）写入文档证据；与代码任务并行，不阻塞非付费支线。
- [ ] 波次 1A / SA-5（依赖波次0）：修复 BUG-07a 税务局误破产与 BUG-07b 机会卡目标互换，联动 `land/config_sanity` 套件。
- [ ] 波次 1A / SA-6（依赖波次0）：修复 BUG-08 出局玩家仍出现倒计时/点骰子流程，补全回合跳过验证。
- [ ] 波次 1A / SA-7（依赖波次0）：修复 BUG-06 路障动画与状态推进不同步，补动作完成后状态推进断言。
- [ ] 波次 1B / SA-8（依赖波次0）：先验真再修补 BUG-10 黑市分页链路（choice 构建、翻页 intent、UI 展示、越界/空页）。
- [ ] 波次 1B / SA-9（依赖 SA-8）：修复 BUG-11 黑市 landing 结束回合链路，消除“额外点骰子结束回合”。
- [ ] 波次 1B / SA-10（依赖 SA-3, SA-8, SA-9）：修复 BUG-03 官方充值回流后自动重试购买并关闭黑市。
- [ ] 波次 1C / SA-11（依赖波次0）：修复 BUG-01 二次确认弹窗可见性隔离，确保仅当前操作玩家可见。
- [ ] 波次 1C / SA-12（依赖波次0）：修复 BUG-13 单道具确认后自动使用，多道具保持原流程。
- [ ] 波次 2A / SA-13（依赖波次1A/1C完成）：修复 BUG-04 皇冠显示、BUG-09 头像降级渲染、OPT-03 颜色一致性。
- [ ] 波次 2A / SA-14（依赖波次1C完成）：修复 BUG-05 手机端道具外框错位与 OPT-02 称号上移（多分辨率验证）。
- [ ] 波次 2B / SA-15（依赖 SA-8）：修复 OPT-07 去掉黑市座驾分页，保证市场页签收敛。
- [ ] 波次 2B / SA-16（依赖 SA-10, SA-15）：实现 OPT-06 连续购买规则：一次一张、买完不关、满 5 张自动退出并提示。
- [ ] 波次 2B / SA-17（依赖 SA-8, SA-15）：实现 TASK-01 测试价开关化（test profile/运行时覆盖），不污染正式 Generated 配置。
- [ ] 波次 2C / SA-18（依赖波次1A完成）：实现 OPT-01 展示时长基线调整，统一相关断言。
- [ ] 波次 2C / SA-19（依赖 SA-18）：实现 OPT-04 收钱动效 + 音效调用桥接。
- [ ] 波次 2C / SA-20（依赖 SA-5, SA-18）：实现 OPT-05 破产页展示延长 2 秒并锁定超时口径。
- [ ] 波次 3 / SA-21（依赖波次2全部完成）：执行目标套件回归（land/market/paid_currency/presentation_ui 系列）并修正失败项。
- [ ] 波次 3 / SA-22（依赖 SA-21）：执行 `lua tests/regression.lua` 全量回归并留存关键输出证据。
- [ ] 波次 3 / SA-23（依赖 SA-22）：执行手工 UI 走查矩阵（多玩家可见性、支付回流、黑市连续购买上限、移动端适配）。
- [ ] 波次 3 / SA-24（依赖 SA-23）：更新“结果与复盘”，并在文末追加最终变更说明，完成交付封板。

## 意外与发现

- 观察：`research.md` 中“黑市翻页缺失”与现状不完全一致，仓库已有分页字段与翻页 intent，问题更可能出在链路一致性而不是纯缺功能。
  证据：`src/game/systems/market/service/Choice.lua` 已有 `page_index/page_count`；`src/presentation/render/MarketView.lua` 已有前后页按钮控制。

- 观察：税务局破产 BUG 是确认的代码缺陷，不是配置问题。
  证据：`src/game/systems/land/LandRules.lua` 的 `execute_pay_tax` 无条件写入 `bankrupt_reason`，而 `src/game/systems/land/LandEvents.lua` 只要收到该字段就执行破产。

- 观察：机会卡医院/税务局跳转错误是确认的数据互换。
  证据：`Config/Generated/ChanceCards.lua` 中 3031/3033 目的地与 `Config/Generated/Tiles.lua` 的 tile 类型不匹配。

- 观察：支付链路与宿主 API 强耦合，若不先固化契约会出现“本地绿、线上红”的假通过。
  证据：`PaidCurrencyBridge` 依赖 `role.show_goods_purchase_panel`、`GameAPI.get_goods_list` 与 `EVENT.SPEC_ROLE_PURCHASE_GOODS`。

- 观察：当前 `tests/internal/forbidden_globals.lua` 只扫描 `src`，无法兜住测试与脚本目录中的数值 API 违规。
  证据：脚本里 `_collect_lua_files("src")` 为硬编码。

## 决策日志

- 决策：本次按 `.agents/research.md` 全量 21 项执行，不裁剪到 P0/P1。
  理由：用户明确要求“用 research 写新 plan”，计划必须完整覆盖研究结论而不是局部摘录。
  日期/作者：2026-03-05 / Codex

- 决策：已实现或疑似已实现项一律“先验真再修补”，先补复现用例再改逻辑。
  理由：避免对现有可用链路重复改造，降低回归风险。
  日期/作者：2026-03-05 / Codex

- 决策：官方商城充值完成后采用“自动重试并完成购买，成功后关闭黑市”。
  理由：这是当前产品偏好，且能直接消除“买完不关”的核心体感问题。
  日期/作者：2026-03-05 / Codex

- 决策：`TASK-01` 不直接改 `Config/Generated/Market.lua` 常态数据，改为 test profile 或运行时开关覆盖。
  理由：避免临时测试价污染正式配置，符合可回滚与发布安全要求。
  日期/作者：2026-03-05 / Codex

- 决策：`OPT-06` 采用“一次只能买一张，买完不自动关闭，手牌满 5 张自动退出黑市并提示”。
  理由：这是用户给定目标，复杂度远低于购物车式多选，且能满足操作效率诉求。
  日期/作者：2026-03-05 / Codex

## 结果与复盘

当前阶段仅完成计划重建，尚未开始代码实施。本节在每个里程碑完成后更新阶段结果、遗留风险与经验教训。最终完成时必须对照“目的 / 全局视角”逐条验收。

## 背景与导读

本计划涉及五个核心子系统。第一是回合与落地效果链，主要位于 `src/game/flow/turn/` 与 `src/game/systems/land/`，决定税务、黑市、医院、深山、破产等状态推进。第二是黑市与支付链，位于 `src/game/systems/market/` 与 `src/game/systems/commerce/`，覆盖商品可见性、翻页、购买执行和官方充值回流。第三是交互分发与 UI 画布链，位于 `src/presentation/interaction/`、`src/presentation/ui/`、`src/presentation/render/`，负责多角色可见性、二次确认、头像渲染、目标选择等体验细节。第四是配置层，位于 `Config/Generated/` 与 `src/core/config/`，承载机会卡跳转、颜色、展示时长等参数。第五是测试层，位于 `tests/suites/` 与 `tests/internal/`，承担复现、回归和规则守门。

术语说明：

“等待态”指 `turn.phase` 进入 `wait_choice`、`wait_move_anim`、`wait_action_anim` 或 `detained_wait`，回合推进被显式阻塞，直到收到动作或动画完成信号。

“回流”指官方支付面板完成后，宿主通过 `EVENT.SPEC_ROLE_PURCHASE_GOODS` 事件把结果同步回游戏逻辑。

“活文档章节”指“进度”“意外与发现”“决策日志”“结果与复盘”四个必须长期维护的章节，不能在收尾时一次性补写。

## 里程碑

里程碑一聚焦“可验证基础设施”。完成后，仓库应具备每条反馈的复现入口与测试映射，且数值 API 违规守门覆盖 `src + tests + scripts`。支付链必须有宿主能力模拟桩，能够稳定重现“API 缺失、调用失败、回调乱序/错 role”场景。这个里程碑的验收是：复现矩阵完整，基础套件可稳定运行，后续修复不再依赖口头描述。

里程碑二聚焦“核心逻辑止血”。完成后，P0/P1 项必须全部可观察修复：税务不再误破产、机会卡跳转正确、出局玩家无多余交互、黑市分页链路一致、充值后购买闭环、路障动画与状态同步、单道具自动使用、二次确认只对当前玩家可见。这个里程碑的验收是：对应测试项变更前失败、变更后通过，并能在最小手工复现场景中看到行为变化。

里程碑三聚焦“体验一致性与增强”。完成后，P2/P3 项全部落地：皇冠显示、头像降级渲染、颜色一致、破产展示时长、收钱动效与音效、称号上移、黑市连续购买、去掉座驾分页、测试价开关化。这个里程碑的验收是：UI 相关场景在桌面和移动分辨率都可复现预期，不引入脚本崩溃或画布错乱。

里程碑四聚焦“全局回归与交付封板”。完成后，`lua tests/regression.lua` 必须全绿，手工矩阵记录完整，`.agents/plan.md` 的活文档章节全部回填，任何新手只看本文件即可重复执行。

## 工作计划

实施顺序按“先守门、后修复、再增强、最后回归”推进。首先在测试层把复现和守门补齐，确保每项反馈都能被自动化或脚本化触发。然后优先处理影响胜负和流程阻断的 P0/P1 问题，其中支付链任务拆为“契约固化”和“产品闭环”两段，避免宿主不确定性直接污染业务修复。黑市相关改动集中管理，严格按“分页一致性 -> landing 收口 -> 充值回流 -> 连续购买”的顺序推进，防止多个任务互相覆盖状态机。随后处理 P2/P3 体验项，并把所有时间相关改动统一放在展示时长基线调整之后，避免断言漂移。最后做全量回归和手工走查，边跑边回填活文档证据。

并行策略采用按依赖波次分组。波次 0 可并行执行复现矩阵、守门扩展和宿主契约桩。波次 1 将逻辑修复分为“土地/回合链”“UI 可见性链”“市场分页链”三条并行支线。波次 2 在前序稳定后再并行推体验项。最终把所有分支合并到统一回归波次，完成收敛。

## 具体步骤

以下命令默认在仓库根目录 `/Users/billyq/Dev/Github/Lua/monopoly` 执行。每完成一步就更新“进度”并写入对应证据。

步骤一，建立复现矩阵和守门。

    rg -n "BUG-|OPT-|TASK-" .agents/research.md
    lua tests/internal/forbidden_globals.lua

预期先得到反馈项列表，再扩展 `forbidden_globals` 扫描范围到 `src + tests + scripts`。扩展后重跑，预期输出 `forbidden_globals ok`。

步骤二，固化支付宿主契约并补桩。

    lua tests/suites/paid_currency.lua

先让支付链新增失败路径用例落地，再修复桩与桥接逻辑，直到用例稳定通过。必须覆盖 `show_goods_purchase_panel` 缺失、`get_goods_list` 空返回、回调错 role、重复回调。

步骤三，完成 P0 双修复。

    lua tests/suites/land.lua
    lua tests/suites/config_sanity.lua

修改税务破产判定和机会卡目的地后，预期相关断言通过，且不影响其他土地逻辑。

步骤四，完成 P1 主链修复。

    lua tests/suites/market.lua
    lua tests/suites/gameplay.lua
    lua tests/suites/presentation_ui.lua

按“分页一致性 -> landing 收口 -> 充值回流 -> 其余交互”顺序提交。每完成一项先跑目标套件，再跑一遍受影响联动套件。

步骤五，完成 P2/P3 体验与增强。

    lua tests/suites/presentation_ui_action_anim.lua
    lua tests/suites/presentation_player_colors.lua
    lua tests/suites/test_profiles.lua

处理皇冠、头像、颜色、动画、弹窗、称号位置、连续购买、去掉座驾分页、测试价开关。每项都需最小化改动并提供可观察证据。

步骤六，全量回归与手工走查。

    lua tests/regression.lua

自动回归通过后，执行手工矩阵，至少包含：多玩家可见性、官方充值回流、黑市连续购买上限、移动端外框与称号位置、破产弹窗可见时长。

步骤七，封板。

将所有证据、风险、决策和复盘写回 `.agents/plan.md`，补齐文末变更说明，保证文档可独立重启实施。

## 验证与验收

验收以行为为准，不以“文件改过”为准。

税务局场景中，余额充足玩家必须仅扣税不破产；余额耗尽玩家才破产。机会卡“送医院”与“去税务局”必须落在正确 tile。出局玩家回合必须自动跳过，不能出现倒计时或点骰子交互。黑市分页要支持翻页、越界回退和空页处理，且充值回流后可自动完成当前购买并关闭黑市。单道具确认时必须直接使用；多道具仍保留原选择流程。连续购买规则必须满足“买完不自动关闭、点关闭退出、满 5 张自动退出并提示”。

UI 验收必须覆盖多角色隔离，确保二次确认只对当前玩家显示。头像渲染在 native-size 失败时必须可降级显示。皇冠、颜色、称号位置在桌面与移动分辨率下都要稳定。

自动化验收命令至少包括：

    lua tests/suites/land.lua
    lua tests/suites/market.lua
    lua tests/suites/paid_currency.lua
    lua tests/suites/presentation_ui.lua
    lua tests/suites/presentation_ui_action_anim.lua
    lua tests/regression.lua

全量回归必须通过，且关键新增测试要满足“变更前失败、变更后通过”的证据要求。

## 可重复性与恢复

本计划按小步提交执行，步骤可重复。每次只推进一个反馈或一个子链路，确保失败时能定位到最小改动面。遇到回归失败时，不做破坏性回退，先通过测试输出定位失败项，再按文件粒度修复并重跑目标套件。支付链联调失败时，不阻塞非支付支线，按计划继续推进并在 `T2b` 记录外部阻塞证据。

`TASK-01` 采用测试开关化后，恢复路径天然存在：关闭对应 profile 或开关即可回到正式价格，不需要手工改回 `Generated` 配置。

## 产物与备注

实施完成后，产物应包含三类内容。第一类是行为修复代码和配置修复，覆盖 21 项反馈。第二类是测试产物，包括新增或更新的 suite 断言和回归脚本证据。第三类是文档产物，即本计划内四个活文档章节的完整回填。

建议保留以下短证据片段，作为最终复盘中的最小证明：

    All regression checks passed (N)
    forbidden_globals ok
    [MarketDebug] ... apply_navigation done ...
    [event] ... 支付税金后破产（仅在余额耗尽场景）

## 接口与依赖

本计划实施过程中涉及的关键接口必须保持兼容。`PaidCurrencyBridge` 与 `MarketService` 的对外调用方已经分散在 game 和 presentation 两侧，新增字段优先放在 `choice.meta` 或局部返回结构，不改变现有调用参数顺序。`TurnDispatch`、`ChoiceResolver`、`UIModalPresenter` 等核心分发入口不得引入破坏性分支，任何新增状态必须可被测试覆盖。

支付回流链只允许依赖仓库已知的官方接口：`GameAPI.get_goods_list`、`Role.show_goods_purchase_panel`、`Role.get_commodity_count`、`Role.consume_commodity`、`EVENT.SPEC_ROLE_PURCHASE_GOODS`。若宿主实际行为与文档不一致，必须把差异写入“意外与发现”，并提供降级策略而非静默失败。

数值相关判断统一使用 `src/core/NumberUtils.lua` 提供的方法，禁止在新增代码中引入 `tonumber`、`type(...) == "number"`、`type(...) ~= "number"`。这是硬约束，违规则由守门脚本拦截。

### API 选择指导（依据官方 API 指引）

参考文档：`https://u5-creator.s3.game.163.com/manual/pc_md/lua/lua_api_structure.html`。该文档把 API 分为“单位与对象、技能与战斗、触发与事件、UI 与交互、场景与相机、音效与特效、存档与成就、通用工具、EVENT”九类。本计划按以下规则选型：

1. 先按能力域选 API，不跨域混用。单位位置/物理用 `GameAPI + Unit`；技能状态用 `Ability/AbilityComp`；UI 节点与购买面板用 `Role` UI API；相机与天空盒用 `GlobalAPI/Role` 相机 API；音效特效用 `GameAPI/GlobalAPI` 的 sound/sfx API。
2. 对局内部模块通信优先走仓库内事件总线（`monopoly_event` + `IntentDispatcher`），不要把内部流程直接改成 `LuaAPI.global_send_custom_event`。`LuaAPI` 触发器主要用于宿主事件接入（如 `EVENT.SPEC_ROLE_PURCHASE_GOODS`）。
3. 业务层禁止直接散落调用 UI 原生 API。presentation 层统一通过 `src/presentation/api/UIRuntimePort.lua`、`src/presentation/api/HostRuntimePort.lua`、`UIManager` 封装调用，避免多处重复处理角色隔离与降级逻辑。
4. 涉及玩家定向行为时必须先拿 `Role` 对象再调用 `Role.*`，并明确作用域（单角色或全角色）。禁止在无角色上下文时直接假设广播生效。
5. 相机、场景、3D 表现类 API 只放在 presentation/渲染路径，不侵入 `src/game/systems/*` 规则层；规则层只产生意图和状态，不直接驱动镜头。
6. 音效与特效优先复用现有桥接层（如 `ActionAnimPort`、相关 render runtime），不要在业务处理函数里直接硬编码 `play_3d_sound/play_sfx_by_key`。
7. 存档与成就 API（`Role.get/set_archive*`、`Role.*achievement*`）不用于单局临时状态；单局状态继续存放在 game runtime 与 turn state。
8. 通用与时间工具 API 统一遵循沙盒约束：优先帧驱动与运行时端口时间，不引入 `os/io/debug` 依赖；数值判定继续执行 `NumberUtils` 统一口径。

文末变更说明（2026-03-05 18:35+08:00）：本次将 `.agents/plan.md` 从“release 受控启用 test_profile”主题切换为“基于 `.agents/research.md` 的 21 项反馈全量修复”主题。原因是用户要求“用 research 写新 plan”，旧计划目标与当前任务不一致，会误导后续实施。
文末变更说明（2026-03-05 18:39+08:00）：根据官方 API 指引链接补充“API 选择指导”到“接口与依赖”章节，明确九类 API 的选型边界与本仓库调用分层。原因是后续多 sub-agent 并行实施时需要统一 API 选型口径，减少跨层误用和接口漂移。
