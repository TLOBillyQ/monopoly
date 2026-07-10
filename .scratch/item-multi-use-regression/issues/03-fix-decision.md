# 03 修复方案 + 回归覆盖方式敲定

Type: grilling
Status: resolved
Blocked by: 01, 02

## Question

基于根因诊断（02）与失败用例（01），和人一起敲定：
0. 确认实测目击即 01/02 钉住的缺陷（post_action 窗口用目标类道具后不重开），并把「回合内任意数量」基线明确延伸到 post_action 窗口——此前 grilling 只钉了掷骰前窗口；若目击另有其事，先补复现再回本票；
1. 修复方案——在哪一层修（turn loop / choice owner / items use_flow）、改动形态、与近期重构方向（choice_contract 归一、owner 深模块）如何兼容不倒退；
2. 回归 spec 覆盖方式——`features/game/items.feature` 补哪些 Gherkin 场景（多道具连用、同组限制不受影响、共用回合级 deadline 不重置）、behavior spec 补在哪；
3. 确认计时语义基线（共用回合级 deadline、用道具不重置）与现实现是否冲突，冲突时是否纳入本方案（见地图 Not yet specified）。

产出：修复方案决议写入 Answer——这是地图的最后一站，关票即到达 destination。

## Answer

与人 grilling 敲定（2026-07-10）：

0. **目击确认**：实测症状即 01/02 钉住的缺陷（post_action 窗口用目标类/followup 道具后不重开）；「回合内任意数量合法道具」基线**延伸到 post_action 窗口**。
1. **修复方案 = 深模块收敛**（超越最小修，与仓库近期 owner/choice_ports/Screen 深模块化方向一致）：
   - `src/rules/items/phase.lua` 新增完成入口（形如 `phase_module.resolve_completion(game, player, meta, opts)`），内部包揽 repeatable 判定、`reopen_or_finish`、action_anim 续接（`after_action_anim` → wait_choice + `build_wait_choice_args`）与无剩余道具时的收尾。
   - `src/rules/choice_handlers/item_completions.lua`（`_resolve_phase_completion`、`_resolve_followup_cancel` 的重开支）与 `item_phase_handlers.lua`（`_handle_item_phase_passive` 重开尾）三处完成路径全部委托该入口，不再感知 phase 差异；`item_completions.lua:36-38` 的 `phase=="post_action"` 早退分支随收敛消失。
   - API 具体签名/返回形状由执行 session 在该方向内细化（`{stay=true}` / `{after_action_anim=...}` / 收尾三态语义保持）。
2. **计时语义 = 共用倒计时，纳入本次修复**：可选行动窗口共用回合级倒计时，使用道具/窗口重开**不重置**；**黑市屏是唯一特例**（独立计时、回合计时暂停/恢复），保持不变。现实现「重开归零」（`on_need_choice` → `set_pending_choice` `elapsed_seconds=0`，`src/ui/ports/events.lua:40`）是偏差，随本次修复一并纠正：重开链路把已耗时 elapsed 随 open_choice 传递下去——该链路正在深模块收敛的 seam 内。
3. **回归覆盖**：`features/game/items.feature` 新增四场景（行动后窗口目标道具用后重开可继续用；回合内连用不同组道具不限次数，掷骰前/行动后皆然；同组单回合一次限制不受影响；连用道具倒计时不重置），`make acceptance` 重生成；修复时把 `spec/behavior/turn/item_window_multi_use_spec.lua` 的 pending 红灯翻回 `it`，3 条绿 pin 一并提交；`item_completions` 补 behavior 闭包 spec。
4. **验收**：`verify` 全量（含 crap + coverage）。

修复执行交后续 session（Out of scope）。

补充（grilling 2026-07-10）：out of scope 第二项「其它选择流程同根因修复」经确认**已清场、不再是遗留工作**——「同根因」系诊断前假设，02 证实根因为道具专属早退分支、共用 `stay` 链完整，建房/拆迁/secondary_confirm 无异常；完成路径 seam 仅道具链路使用。执行 session 无需顾及其它选择流程，唯一共用触点是计时管道 `on_need_choice`（管道携带 elapsed 改造，其它流程语义不变）。
