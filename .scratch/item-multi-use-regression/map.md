# Map: 道具卡回合内连用回归（item-multi-use-regression）

Labels: wayfinder:map

## Destination

查明「玩家可以在回合内使用任意数量合法道具卡」被哪次重构、哪个环节破坏的**根因**，并敲定**修复方案 + 回归 spec 覆盖方式**。终点是方案已定、可直接交给后续 session 执行——本地图不做修复本身。

## Notes

- 域：Lua 5.4 大富翁，清洁架构七层 + foundation；回合/选择流程在 `src/turn/` 与 `src/rules/items/`（`use_flow*.lua`、`availability.lua`、`phase.lua`）。
- 近期嫌疑重构：choice_contract 归一（16cc135 前后几次）、候选⑤ owner 深模块委托 + 去 double-decide、secondary_confirm 选择屏收进 Screen 深模块。
- 预期行为基线（本次 grilling 敲定）：
  - 掷骰前存在可选行动窗口；每用完一张道具应**回到同一窗口**，玩家可继续选下一张合法道具或主动掷骰。
  - 唯一显式数量限制是**同组道具单回合一次**（`used_effect_groups`，`src/rules/items/availability.lua:186`；feature：`features/game/items.feature` 场景「同组道具单回合内只能使用一次」）。不同组合法道具不限次数。
  - 计时语义（03 确认）：可选行动窗口**共用回合级倒计时**，使用道具/窗口重开不重置；**黑市屏是唯一特例**（独立计时、回合计时暂停/恢复）。现实现「重开归零」属偏差，随修复纠正。
  - 「任意数量」基线适用于掷骰前（pre_action）与行动后（post_action）两个窗口（03 确认延伸）。
  - 遥控骰子等自带掷骰效果的道具触发推进属正常设计，不算症状。
- 症状（实测）：用完一张道具后回合直接推进，无再用道具的机会；具体道具记不清，需复现钉住。无已知好版本参照，代码流分析优先于 git 二分。
- 常用 skills：/diagnosing-bugs（根因）、/grilling + /domain-modeling（决策票）、/tdd（失败用例）。
- 验证约定：迭代 `verify --smoke`；行为 spec 用 `busted --run behavior`。

## Decisions so far

<!-- one line per closed ticket: gist + link -->

- [02 代码流诊断：谁把可选行动窗口关死了](issues/02-root-cause-analysis.md) — 掷骰前(pre_action)窗口非掷骰道具连用**未复现/行为正常**（端到端全部重开）；唯一实锤缺陷是 post_action 窗口 + followup/target 道具用完不重开（`item_completions.lua:36-38` 的 `phase=="post_action"` 早退，历史遗留、非嫌疑重构引入）。
- [01 无头复现：钉住「用完道具后回合直接推进」的失败用例](issues/01-headless-repro.md) — 无头复现**成功**：红灯钉在 post_action 窗口 + followup 道具（`spec/behavior/turn/item_window_multi_use_spec.lua`，pending 形态），与 02 根因吻合；pre_action 三条链全绿留作回归 pin。实机复现矩阵不再需要。
- [03 修复方案 + 回归覆盖方式敲定](issues/03-fix-decision.md) — 目击确认即 post_action 缺陷、基线延伸；修复走**深模块收敛**（phase.lua 新增 resolve_completion 完成入口，三处完成路径委托，早退分支消失）；计时偏差（重开归零）**纳入修复**：窗口共用倒计时不重置，黑市屏唯一特例；回归 = Gherkin 四场景 + 翻红灯 + behavior 闭包；验收 verify 全量。

## Not yet specified

（无——路已清，地图到达终点。）

## Out of scope

- **修复的实际执行与验证**——地图终点是方案已定，执行另起 session/effort（方案见 [03 修复方案 + 回归覆盖方式敲定](issues/03-fix-decision.md)）。
- **其它选择流程（建房、拆迁、secondary_confirm 等共用 choice 链路环节）的同根因修复**——~~另起 effort~~ **已清场，无遗留工作**（grilling 2026-07-10 敲定）：「同根因」是诊断前的假设（若共用 choice 链路被重构破坏则波及所有选择流程）；02 诊断证实根因是道具专属的 `item_completions.lua` 早退分支，`stay` 传播共用链在 HEAD 完整，建房/拆迁/secondary_confirm 未见重开异常，受影响面收敛为主修复对象本身。完成路径 seam（`reopen_or_finish` 三使用者）仅道具链路经过，其它流程结构上不受本次收敛影响；唯一共用触点是计时管道 `on_need_choice`（`src/ui/ports/events.lua:40`），修复只做管道携带 elapsed 的改造，其它流程行为不变。**不并入执行 session，也不另起 effort。**
