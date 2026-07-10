# 02 代码流诊断报告：可选行动窗口「用完一张道具后是否回到窗口」

Status: resolved
关联票：`../issues/02-root-cause-analysis.md`
地图：`../map.md`

## 结论（一句话）

**掷骰前（pre_action）可选行动窗口的「非掷骰道具连用」在 HEAD 上未复现——每用完一张（自效果 / 板面目标 / 玩家目标 / 甚至遥控骰子）窗口都正确重开，回合不推进。** 唯一真实存在的「用完不重开」缺陷在 **post_action（行动后）窗口、且只影响需要二段选择（followup/target）的道具**，且该不对称是**历史遗留**、与本票列出的嫌疑重构（choice_contract 归一 / 候选⑤去 double-decide / secondary_confirm）**无关**。

## 复现方法（端到端，走真实协程回合引擎）

用 `compose_game.new_game`（人类玩家，`ai={}`）建局，`game:advance_turn()` 把回合推进到 pre_action 打开 passive 窗口并 `wait_choice`，然后用 `game:dispatch_action{ type="choice_select", ... }` 模拟人类点选道具——这条路径完整经过 `timing` 协程调度 → `await.choice` → `turn_decision.resolve_choice` → `choice_resolver` → 道具 choice handler，不是只调 rule 层。观测 `game.turn.pending_choice` 与 `game.turn.phase`。

### pre_action（掷骰前）——全部重开，回合不推进

| 道具 | 类型 | 用后 `pending_choice` | 结果 |
|---|---|---|---|
| `mine` 地雷 | 立即自效果 | `item_phase_passive`（重开，含剩余 `clear_obstacles`）| 重开 ✅ |
| `roadblock` 路障 | 板面目标 followup | 选目标后 → `item_phase_passive`（含剩余 `mine`）| 重开 ✅ |
| `exile` 流放 | 玩家目标 followup | 选目标后 → `item_phase_passive`（含剩余 `mine`）| 重开 ✅ |
| `remote_dice` 遥控骰子 | dice + followup | 选点数后 → `item_phase_passive`（含剩余 `mine`）| 重开 ✅ |

即掷骰前窗口对**所有**道具都回到同一窗口。`remote_dice` 在 pre_action 只是预设骰面，真正掷骰在后续 roll 阶段，所以它这一步也重开（不是即刻推进）。

### post_action（行动后）——立即道具重开，followup 道具不重开

| 道具 | 类型 | 用后 `pending_choice` | 结果 |
|---|---|---|---|
| `mine` | 立即自效果 | `item_phase_passive`（含剩余 `roadblock`）| 重开 ✅ |
| `roadblock` | 板面目标 followup | `nil`（`mine` 仍在手）| **不重开 → 收尾推进 ❌** |

## 控制流证据链

窗口重开的判定链，从道具用完一路到协程是否再次停在同一窗口：

1. **道具用完（passive 窗口选项被选）** → `src/rules/choice_handlers/item_phase_handlers.lua:82` `_handle_item_phase_passive`。
   - 立即道具：`item_phase.reopen_or_finish(...)` 直接重开（`src/rules/items/phase.lua:137`），返回 `{ stay = true }`（`item_phase_handlers.lua:96-97`）。
   - followup 道具：先 `_handle_passive_waiting_result` 开二段选择（`item_phase_handlers.lua:38-46`，`passive_origin=true`、`meta.phase` 透传）。
2. **followup 二段选择确认** → `src/rules/choice_handlers/item.lua:5` `_handle_flow_choice` → `complete.followup_completion` = `src/rules/choice_handlers/item_completions.lua:46` `_resolve_followup_completion` → `_resolve_phase_completion`（`item_completions.lua:31`）：
   ```lua
   if not is_repeatable_phase_meta(meta) then finish end     -- 非重复相 → 收尾
   if meta.phase == "post_action" then finish end            -- ★ post_action → 收尾（不重开）
   local resumed = _resume_pre_action_phase(...)             -- pre_action/pre_move → reopen_or_finish
   ```
   **`item_completions.lua:36-38` 的 `meta.phase == "post_action"` 早退分支**，是 post_action followup 道具不重开的唯一原因。pre_action / pre_move 落到 `_resume_pre_action_phase`（`item_completions.lua:16`）→ `reopen_or_finish` → 重开。
3. **重开的 `{ stay = true }` 如何让协程停回窗口**：`choice_resolver.resolve`（`src/rules/choice/resolver.lua:150`）透传 `descriptor.execute` 的 `stay`（`_build_resolve_result` `resolver.lua:142`）→ `turn_decision.resolve_choice`（`src/turn/waits/decision.lua:27` 原样返回）→ `await._finish_choice_wait`（`src/turn/waits/await.lua:87`）：`if res and res.stay then return _WAIT`——`stay` 为真则协程再次 yield 在 `wait_choice`，停回（重开后的）窗口；`stay` 为假才推进到 `next_state`（roll）。**这条 `stay` 传播链在 HEAD 上完整无断点**，故 pre_action 每步都停回窗口。

`reopen_or_finish` 只有在 `build_passive_choice_spec` 返回 `nil`（即无任何可 offer 道具）时才 `finish`（`phase.lua:145-148`）——这正是「同组道具单回合一次」耗尽后正常收尾（`availability.can_offer_in_phase` + `used_effect_groups`，`src/rules/items/availability.lua:186-189`），不是 bug。

## 根因形态判定（对照票面三选）

- **窗口重开逻辑被删？** 否。`reopen_or_finish` 与两条 re-offer 分支（immediate、followup→`_resume_pre_action_phase`）在 HEAD 均在，pre_action 正常重开。
- **条件判断被改错？** pre_action 无。存在一个「收尾而非重开」的条件 `meta.phase == "post_action"`（`item_completions.lua:36`），但它作用域是 post_action 且仅 followup 路径，是设计不对称，非近期误改。
- **choice 归一后丢了 re-offer 分支？** 否。re-offer 分支在 HEAD 存活且 `stay` 传播链完整。

## 引入 commit / 历史

- post_action followup 早退分支：`git log -S'meta.phase == "post_action"'` 命中 `995c2fe4`（refactor: split achievement progress hotspots，把逻辑从旧 `item.lua` 拆到 `item_completions.lua`）与更早的 `30869772`（history reset 基线）。**本票嫌疑的 `16cc1358` / `100ceb3b` / `dd034f5a` / `34d91c3a` 均未触碰该逻辑。** 即：post_action 不对称是历史遗留，不是嫌疑重构引入。
- pre_action 重开链在 HEAD 正确，无「引入回归的 commit」可指——因为没有回归。

## 受影响面（只登记，按 map Out of scope 不展开）

- **post_action（行动后）窗口 + followup/target 道具（路障 / 怪兽 / 导弹 / 偷窃 / 流放 / 均富 / 查税 / 请神 / 送穷 等目标类，以及板面目标 roadblock/monster）用完即收尾，单回合只能用一张**——与「立即道具在 post_action 可连用」「同类道具在 pre_action/pre_move 可连用」不一致。这是本次诊断唯一实锤的重开缺陷。
- 若报告人实际所在窗口是 post_action（「行动后」，玩家常在移动落地后打出攻击类目标卡），且用的是目标类道具——**这最可能就是被误记为「掷骰前」的真实现象**。建议复现票据此定向验证：post_action 用一张目标卡后是否还能再用第二张。
- 建房 / 拆迁 / secondary_confirm 等未在本诊断路径观察到重开异常（pre_action 各类目标道具均正常重开）。

## 附：诊断中已跑并通过的现有覆盖

- `spec/behavior/scenarios/item_phase/passive_spec.lua`（6 ok）——rule 层重开 + 同组拦截 + 重入相已被 pin，且断言 `stay==true`，与本诊断一致。
