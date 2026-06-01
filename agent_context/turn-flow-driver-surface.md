# turn_flow 收敛：验收驱动面接口诉求（turn-flow-driver-surface）

specifier → coder。源自 ADR 0017 D1.1（`turn_flow.lua` Tier C 假绿须经真 driver 收敛）。
这是**验收层需要观察到的回合循环能力清单**，不是函数签名处方——具体 API 形状归 coder/架构。

## 为什么先来这一步

`features/game/turn_flow.feature` 约 24 场景，`tools/acceptance/steps/turn_flow.lua`（758 行，仅 require `number_utils`）自建 `world.turn` 模型 + 重实现轮转/淘汰/AI 优先级，`src/turn/*`、`src/rules/items`、`src/config/content/items` 零调用。要按 D1 收敛，specifier 的场景重写依赖 `game_driver`（或回合专用 driver）先长出回合循环面——现 driver 只有 `new_game/move/roll_dice/tile_*/player_cash/roadblock/mine/deity/facing/events`，**无**回合生命周期/淘汰/扣留/阶段序/超时/等待/AI 道具阶段。

## 架构岔路（升级架构师裁定）

ADR 0017 D1.1 留口：「经 `game_driver`（或回合专用 driver）」。扩 `game_driver` 还是另起 `turn_driver`——这是边界裁决，按 ADR「架构师负责本边界裁决」。请 coder 在动工前与架构师确认这一点。

## 需要可观察的能力（按 feature 簇）

驱动须 over 真 `src/turn/{loop,phases,policies,waits,deadlines,timing,actions}` + `src/rules/items` + `src/config/content/items`，断言读 src 产出，不再落 `world.turn` fixture。

1. **轮转 / 淘汰 / 扣留 / 临时态**（场景 320-362）
   - 设玩家数、读当前参与玩家数；设当前回合玩家；结束回合 → 推进到下一**未淘汰**玩家（含环回 4→1）。
   - 标记玩家淘汰 → 结束回合时跳过。
   - 扣留（停留 N 回合）：回合开始递减、禁掷骰/移动、回合直接结束；到期后恢复正常掷骰。
   - 回合结束清临时态：遥控骰子效果清除、骰子加倍倍率重置为 1。

2. **标准阶段序**（场景 364-371）
   - 跑一个回合并观察阶段序列：开始 → 等待行动 → 掷骰 → 移动 → 落地 → 结束。

3. **落地结算卡牌边界**（场景 373-394；部分可复用现有 move/tiles/items，勿重复造）
   - 黑市售罄 → 不弹购买选择、直接进结束阶段。
   - 落对手地块 + 免租卡 → 自动消耗、不付租、无手动选择。
   - 同持强夺卡 + 免租卡 → 先弹强夺提示；拒绝则自动消耗免租；不付租。

4. **选择超时 / deadline / 等待 / 打断**（场景 396-462）
   - 选择类型（普通/黑市/道具目标）各自超时配置（15/60/15 秒），剩 5 秒警告。
   - 超时自动执行默认项；温和跳过不扣金币；道具目标超时退还预消耗道具至背包。
   - 分阶段倒计时：剩 5/3/0 秒 → 警告/紧急/到期，每级仅一次。
   - 超时自动结算后关弹窗、清待处理选择指示。
   - 黑市浏览期间行动计时器不暂停。
   - 回合间等待间隔；阻断性提示显示完毕前不切下一玩家回合。

5. **电脑玩家行为**（场景 464-509）
   - AI 自动购买可负担无主地、自动升级可负担自有地、对手地块自动用免租卡。
   - AI 道具使用阶段按优先级尝试；优先级表 + 触发条件覆盖：遥控骰子卡 / 路障卡 / 偷窃卡 / 怪兽卡 / 均富卡 / 流放卡 / 导弹卡 / 查税卡 / 请神卡（天使 / 财神无天使两分支）/ 送神卡 / 穷神卡 / 其他卡。
   - **D3 单一真源**：AI 优先级 / 触发条件必须来自 `src/config/content/items.lua` + `src/rules/items/handlers.lua` 单源，driver 不得复制 `turn_flow.lua` 现有的 `AI_ITEM_PRIORITY`/`AI_TRIGGER_KNOWN`。

## 交接后时序

driver 面建好（coder，含架构裁定）→ 回来 specifier：把 turn_flow 24 场景重写到该面，删平行重实现 + AI 常量复制。揭债红按 ADR 0012「区分新增失败与既有失败」处理。

## 节奏裁定：一次性重写（用户定，2026-05-31）

coder 已交 cluster1（轮转/淘汰/扣留/临时态）+ cluster2（阶段序）驱动面，并提议增量（先交 1&2 场景）。**用户裁定守一次性**：

- **coder 续建 cluster3/4/5 驱动面**（落地结算卡牌边界 / 超时-deadline-等待-打断 / AI 道具阶段），从本契约上方「需要可观察的能力」描述造 verb——如同已造的 1&2，**不必等 specifier 的 Gherkin 场景**做 verb 设计参考；行为粒度本契约已给足。
- 全 5 簇 driver 面经正常 cycle（coder→refactorer→architect）落 main 后，**specifier 一次性重框全 24 场景**到完整驱动面，coder 同提交重写 turn_flow.lua step（原子落地，main 不中途红）。
- 不走增量（1&2 先闭）——用户已定一次性，避免 turn_flow.feature 反复改。
- D3 单源、跨 feature 步骤句唯一（coder 自处理 reword）等约束不变。

## 收敛真实性反证（ADR 0017 验证段）

重接**前** turn_flow 杀不掉 `src/turn/*` 关键分支差分变异（survivor）；重接**后**转 killed。以变异由红转杀证明断言穿透到 src。

## coder 实证发现（cluster 5，供 specifier 重框前校准；2026-05-31）

driver 面建 cluster 5 时核对真 src，三处与本契约措辞/前提有出入，重框场景前请校准：

1. **D3 单源不在 `items.lua`/`handlers.lua` 数据字段**：AI 道具优先级是 `src/rules/items/strategy.lua` `_run_auto_pre_action_probes` 的**调用链顺序**（清障→遥控骰→地雷→骰子加倍→路障→怪兽→目标类(steal/missile/share_wealth/exile/tax/invite_deity/send_poor/poor，序由 `post_effects.target_item_ids()`)→神祇类(rich→angel)）；触发条件是该文件内**内联谓词**（`has_obstacles_ahead` / `pick_remote_dice_value` / `pick_roadblock_target` / `_has_target_player` / `_has_demolish_target`），无 `ai_priority`/`ai_trigger` 数据字段。driver 已按 D3 意图驱真 `strategy.auto_pre_action`（读不到任何列表，优先级/触发全自 src），未复制 turn_flow.lua 常量。场景断言「按优先级」应表述为「驱真 strategy 后某卡被/未被消耗」，单源指 strategy.lua。

2. **AI 道具阶段一次跑用掉所有触发卡，非「选一张优先级最高」**：每个 `_try_use_item` 触发即经 `executor.use_item({by_ai=true})` 消耗，仅当某卡需玩家选择（waiting/intent）才中断链。故同一 pre_action pass 会按序用掉所有满足触发的卡。

3. **「道具目标超时退还预消耗道具」实为「超时未消耗→留存」，且 ask 为 UI 耦合**：目标类道具在 `handlers.lua:51-52` **选定目标后 apply 时才消耗**（除非 `item_preconsumed`）；目标选择超时→不 apply→从未消耗→卡自然留背包。`deadlines._refund_preconsume` 是 **no-op**（`item_preconsume_policy` 无 `refund` 函数）。进入目标询问的 `_item_phase_ask_active=true` 由 `src/ui/coord/modal.lua:81` 设（UI 层）。故此项 driver 折入待议：真闭环测「留存」可，但「退还到背包」语义 src 未实现；人类目标选择路径 UI 耦合，真闭环需 host/UI seam 或裁为「留存」语义。

4. **AI 买地/升级/对手地用免租**不在道具阶段，而在落地结算经 `choice_auto`（AI actor）自动解析；驱整局 AI 回合经协程机会触宿主 API 缺口（LuaAPI），真闭环宜驱决策策略 seam 或补 host stub——cluster 5 余项，下一 cycle。

本 cycle 已交 cluster 5 核心（AI 道具阶段真触发门控，commit 见 swarmforge-coder）；2/3/4 项为待议/余项，请 specifier 据此校准 464-509 重框，architect 视 3 项「退还 vs 留存」语义是否需 ADR 裁。

## cluster 6 — AI 落地结算 driver seam（architect → coder，2026-05-31，最后一簇）

cluster 5 核心已交（AI 道具阶段真触发门控）。architect 已裁（ADR 0017 附录，2026-05-31）：
- **D3 勘误**：AI 优先级/触发单源是 `src/rules/items/strategy.lua`（调用链+内联谓词），非数据字段；no-copy 意图已兑现，driver 经 `run_ai_item_phase`→真 `strategy.auto_pre_action` 驱动。**无需回改**。
- **道具超时语义**：裁「留存」（删「退还」）。specifier 重框时落，coder 无须动 driver（deadline 超时观察「留存」用 cluster 4 既有 deadline verb 即可，不跨 UI modal）。

**本簇任务**：覆盖 `turn_flow.feature:464-509` 中 driver 尚不可达的 AI 落地结算场景——**电脑自动买地（247）/ 升级（260）/ 对手地免租（273）**。这些走 `choice_auto`（AI actor）在落地结算解析，驱整局 AI 回合经协程触宿主 LuaAPI 缺口。

**形状边界（能力，非签名）**：验收层须能观察「AI 玩家落在<地块情形> → 真 `choice_auto`/落地结算决策 → 买/升/用免租 的真 src 产出（地块归属、现金、卡背包）」，断言读真 src 状态，不落 fixture、不复制决策表。

**seam 选择（coder 裁，二选一或更优）**：
- (a) **决策策略 seam**：直接驱 `src/turn/policies/choice_auto`（AI actor 决策入口）而非跑整局协程，绕开 host LuaAPI——若 `choice_auto` 可在不触 LuaAPI 下产出决策+落到 game 状态，优先此路（最薄、最贴 D1.1「不重组 game、over 同一 ctx」）。
- (b) **薄 host LuaAPI stub**：若必须跑协程，给 AI 落地路径所**触及的具体 LuaAPI 调用**补**薄** stub（仅记录/默认返回，置于 driver 的 ctx 装配处，勿污染 game_driver 既有字段）。

**⚠️ 升级逃生阀（pre-write 信号，按 [[feedback_architect_handoff_escape_valves]]）**：
- 若 (a) 路径发现 `choice_auto` 决策**无法在不触 host LuaAPI 下落到 game 状态**（即决策与 host 渲染/事件强耦合）；**或**
- 若 (b) 需 stub 的 LuaAPI 调用**超过 ~5 个、或任一调用需真实语义（非默认返回即可）**，即 stub 会膨胀成 host-integration 假实现——
→ **STOP，回 architect 升级**。不要建厚 host 假实现冒充真闭环（违反 ADR 0017 D2/D5「fixture 不承载规则、不平行实现」）。带上：触及的 LuaAPI 清单 + 每个所需语义深度 + (a) 受阻的具体耦合点。

**节奏**：本簇是 driver 面**最后一簇**。就位后 architect 一次性路由 specifier 重写 `turn_flow.feature` 全场景 + 删 `turn_flow.lua` 假绿（用户 one-shot 节奏裁定 3b80ed39，避免反复 thrash feature）。specifier **保持待命至本簇验收通过**。

### cluster 6 交付结果（coder，2026-05-31）— seam (a)，逃生阀未触发

实证三场景全经 seam (a) 落真状态，**零 LuaAPI、无 host stub、不重组 game**（probe 验后删）：
- 落地结算核心是 `src/turn/phases/land.lua` 的 `_phase_land`（导出为 `land.run(turn_mgr, args)`，只读 `turn_mgr.game`）：跑 `effect_pipeline.run` → 强制效果（pay_rent 等）就地结算，可买/可升的 optional 经 `intent_output_port.open_choice` 把真 `landing_optional_effect` 选择落入 `game.turn.pending_choice`；干净买地/升级不产 action_anim 队列 → `_resolve_wait_state` 纯返回 `wait_choice`，**host 耦合（action_anim/landing_visual 路由）不触发**。
- AI 决策经 `src/turn/policies/choice_auto.decide(game, nil, choice, {mode="wait_choice"})`：`is_auto_actor` **不硬传**，由真 `auto_play_port.is_auto_player(owner)` 解析 → AI owner 出 `{choice_select, option_id}`、human owner 出 nil（选择留 pending）。决策表在 `src/computer/agent/decision.lua`（`_handle_landing_optional_effect` 取 buy_land/upgrade_land），纯逻辑无 host。
- 应用经 `src/rules/choice/resolver.resolve(game, choice, action)` → bootstrap 的 `_handle_optional_landing_effect` → `effect_runner.execute` → `effect_base` `_apply_buy`（纯 game-state）/`_apply_upgrade`（另触 tile_feedback_port/action_anim_port，均**端口非 LuaAPI**，acceptance compose 下默认/no-op）。
- **对手地免租（273）非选择**：`_apply_pay_rent` 在强制效果阶段，持 free_rent 无 strong → `execute_free_card` 直接消耗、不付租、不弹选择（`settle_landing` 返回 nil）。观测真源 = 现金不变 + 卡背包消耗 + 地块仍属对手。

driver verb（`tools/acceptance/turn_driver.lua`）：`settle_landing(ctx, player)`（驱真落地结算，返回 pending choice 或 nil）+ `auto_resolve_landing_choice(ctx)`（驱真 choice_auto 决策 + resolver 应用，返回 AI 选的 option_id 或 nil=非 auto owner）。支撑 `game_driver.first_land_tile(ctx)`（按真地图取首个 land tile 的 index+id）。spec 四例（买/升/免租/human-gate）见 `turn_driver/spec`（tooling 148-151）。D3 单源不破——driver 读不到任何优先级表，买/升/免租结果全自 src。

## cluster 6 已交付 + driver 面完成（architect 接受，2026-05-31）

cluster 6（AI 落地结算 seam）由 **refactorer 交付**（commit 345649f7，先于 coder 拾取）。architect 已接受并合并到 swarmforge-architect。

**采 seam (a)（决策策略 seam），src 零改动、无 host stub、无决策表复制**：
- `turn_driver.settle_landing`：驱真 `src/turn/phases/land` 落地结算（强制效果如 pay_rent 自动用免租卡），ownable 地块开真 `landing_optional_effect` 选择入 `pending_choice`。
- `turn_driver.auto_resolve_landing_choice`：经真 `src/turn/policies/choice_auto`.decide（AI 决策入口）+ `src/computer/agent` 决策并 apply（buy_land/upgrade_land），落真 game 态（地块归属/现金/卡背包）；human owner 不产 auto action。
- 逃生阀已尊重：未跑整局协程（绕开 host LuaAPI 缺口），驱「落地结算+决策」函数即够。

**验证**：tooling 318 ok / make verify 9/9 PASS / make acceptance 540 ok / DRY 仅旧 benign 微 verb 对（无新增）/ src 零改动。

**⚠️ cluster-6 coder handoff（3f3541b8）已被本交付取代**——coder 无需再实现 cluster 6，project state（本节 + turn_driver.lua）即为完成证。

### driver 面（clusters 1–6）至此完成 → specifier 一次性重写解锁

turn_flow.feature soft-gherkin 现状：23 场景**全 skip**（total=0 有效突变）——旧 `turn_flow.lua` 自 fixture 场景无可突变 world-state 断言，mutator 测不到。这正是 specifier 重写要关闭的债。

driver 面现覆盖 turn_flow 全场景所需能力（轮转/淘汰/扣留/阶段序/落地卡牌/超时/等待/AI 道具阶段/AI 落地结算）。依用户 one-shot 节奏裁定，**现路由 specifier 一次性重写 `features/game/turn_flow.feature` 全场景经真 driver 闭环 + 删除 `tools/acceptance/steps/turn_flow.lua` 假绿**。重写注意 ADR 0017 附录两裁：AI 优先级断言表述为「驱真 strategy 后某卡被/未被消耗」（单源 strategy.lua）、道具目标超时断言「留存」（删「退还」）。

## specifier 一次性重框交付（2026-05-31）

driver 面（clusters 1–6）已落 main `820e7d16`，specifier 据此一次性重框。**Gherkin 改动收敛为 ADR 0017 附录强制的 3 个场景**（其余 20 场景行为正确——driver 面正是按其能力清单造，不作无谓 churn）；真收敛的主体是 `turn_flow.lua` step 重写为驱 `turn_driver`/`game_driver`，删 `world.turn` fixture + `AI_ITEM_PRIORITY`/`AI_TRIGGER_KNOWN` 复制。

**按 setup/bankruptcy 先例原子落地**：specifier 不单提交 feature（否则 main `make acceptance` 中途红——Gherkin 与旧 step 失配）。下方 reframed Gherkin 由 specifier 拥有/作者，coder **feature 改写 + step 重写 + manifest 重生同一提交**原子落地。manifest stamp 失配是预期，coder 跑 `make acceptance` 由 gherkin-mutator 刷新，不手改。

### 三处 reframed 场景（替换现有同位场景）

场景 13「道具目标选择超时后退还预消耗道具」→ 留存语义（src 无退还，目标 apply 时才消耗，超时从未消耗）：

```gherkin
场景: 道具目标选择超时后道具未被消耗仍留存背包
  假如 玩家持有需指定目标的道具
  并且 玩家已发起使用但尚未选定目标
  当 目标选择超时系统自动取消
  那么 该道具未被消耗仍在玩家背包
```

场景 21「电脑玩家按优先级主动使用背包中的主动道具」→ 删「按优先级」，表述为驱真 strategy 后被消耗：

```gherkin
场景: 电脑玩家在道具使用阶段消耗满足触发条件的主动道具
  假如 当前行动玩家是电脑
  并且 电脑玩家背包中持有满足触发条件的主动道具
  当 电脑玩家的道具使用阶段执行
  那么 该道具被自动消耗
```

场景 22「电脑玩家主动道具优先级」→ 删「优先级」命名/措辞，逐卡触发谓词驱真 strategy（保留 13 行 Examples，每行一卡=真 per-card 谓词，强突变面）：

```gherkin
场景大纲: 电脑玩家在触发条件满足时消耗对应主动道具
  假如 当前行动玩家是电脑
  并且 电脑玩家背包中持有<道具>
  并且 棋盘状态满足<触发条件>
  当 电脑玩家的道具使用阶段执行
  那么 该<道具>被消耗

例子:
  | 道具       | 触发条件                         |
  | 遥控骰子卡 | 移动范围内存在道具格             |
  | 路障卡     | 前方存在道具格                   |
  | 偷窃卡     | 存在持有道具的其他玩家           |
  | 怪兽卡     | 前后3格内存在他人等级最高的建筑  |
  | 均富卡     | 电脑玩家不是现金最多的角色       |
  | 流放卡     | 存在其他现金最多的角色           |
  | 导弹卡     | 前后3格内存在他人等级最高的建筑  |
  | 查税卡     | 存在其他现金最多的角色           |
  | 请神卡     | 其他角色附有天使                 |
  | 请神卡     | 其他角色附有财神且无人附有天使   |
  | 送神卡     | 电脑玩家附有穷神且存在现金最多对手 |
  | 穷神卡     | 存在其他现金最多的角色           |
  | 其他卡     | 道具当前可用                     |
```

其余 20 场景（idx 0–12、14–20）Gherkin 文本不变；仅 step 实现改为驱真 driver。idx 9/14（验证列 doubling）保留——刻意的 Examples-cell 突变抗性，勿删。

### step → driver verb 映射（coder 重写 turn_flow.lua 用，断言读真 src 状态）

| 场景簇 | idx | driver verb（`turn_driver` 除注明外） |
|---|---|---|
| 轮转/淘汰/扣留/临时态 | 0–4 | `set_current_player`/`participant_count`/`active_participant_count`/`current_player`/`play_turn`/`eliminate`/`detain`/`stay_turns`/`pending_remote_dice`/`dice_multiplier` |
| 标准阶段序 | 5 | `turn_phase_order_holds`(milestones=开始→等待行动→掷骰→移动→落地→结束) / `observe_turn_phases` |
| 黑市售罄/免租/强夺优先 | 6–8 | `settle_landing` 或 `advance_to_choice`+`pending_choice`+`resolve_choice("skip")`；地块归属/持卡用 `game_driver` 落座+set_tile_owner+背包 setup |
| 选择超时自动决定 | 9 | `choice_timeout_seconds`/`arm_choice_deadline`/`elapse_choice_deadline`/`choice_deadline_level`（普通15/黑市60/目标15，剩5警告） |
| 回合间等待/路障/阻断提示 | 10,11,17 | `advance_to_inter_turn_wait`/`inter_turn_wait_seconds`/`inter_turn_wait_active`/`elapse_inter_turn_wait`/`hold_inter_turn_with_blocking_tip`/`reset_tips` |
| 温和跳过不扣金币 | 12 | `elapse_choice_deadline` + `game_driver.player_cash`（前后不变） |
| 道具目标超时留存 | 13 | deadline 超时 verb（cluster4）+ 背包道具数前后不变（**不**断言退还，src 无此机制） |
| 分阶段警告 | 14 | `arm_choice_deadline`+`elapse_choice_deadline`+`choice_deadline_level`（normal→warn_5s→warn_3s→expired，各 latch 一次） |
| 关弹窗/清指示 | 15 | 超时后 `pending_choice`==nil |
| 黑市计时器不暂停 | 16 | `choice_timeout_seconds`(market_buy=60)+`elapse`+`choice_deadline_remaining`（持续递减） |
| AI 买地/升级/对手地免租 | 18–20 | `is_ai`/`settle_landing`/`auto_resolve_landing_choice`（地块归属/现金/卡背包读真态） |
| AI 道具阶段（触发即消耗） | 21,22 | `is_ai`/`run_ai_item_phase`（驱真 `strategy.auto_pre_action`；消耗经背包道具数观测，**勿**复制优先级/触发表） |

`game_driver` 既有空间/setup verb（`new_game`/落座/`set_tile_owner`/`player_cash`/`first_land_tile` 等）用于场景前置；turn 生命周期一律走 `turn_driver`。删 `turn_flow.lua` 全部 `world.turn` 自建模型与 AI 常量复制后，soft-gherkin total 应由 0 转正（断言落真 world state）。

### 反证（coder 跑，specifier 不跑）

重接前 turn_flow soft-gherkin 全 skip（total=0）；重接后断言穿透真 `src/turn/*`/`src/rules/items/strategy`/落地结算，关键差分变异由 survivor 转 killed、soft-gherkin total 转正。

## coder 一次性重写交付（2026-05-31）

specifier 一次性重框已落地，原子单提交，main 不中途红。`make acceptance` 540 ok·0 FAIL·0 error（确定性，多跑稳定）；`make verify` 9/9 lane 49s；`busted --run tooling` 318/318。

- **3 场景 reframe 应用**（feature）：S13 目标超时→「该道具未被消耗仍在玩家背包」（删退还）；S21/S22→「该(道具)被(自动)消耗」，S22 大纲补 `棋盘状态满足<触发条件>` 列 + 13 行（覆盖全 AI 主动卡，含 send_poor 经 post_action 触发）。
- **turn_flow.lua 全重写**：删 `world.turn` 自建模型 + `AI_ITEM_PRIORITY`/`AI_TRIGGER_KNOWN` 常量复制；全 23 场景 step 改驱真 `turn_driver`/`game_driver`/`src/rules/items/strategy`/落地结算。soft-gherkin total 由 0 转正（断言落真 world state）。
- **turn_driver/game_driver 扩展**：cluster6 `settle_landing`/`auto_resolve_landing_choice`、target-select 系列 verb；`game_driver.new_game` 注入 no-op paid gateway（黑市偶发路由→安全 no-op，play_turn 抗任意 roll；paid_currency/skin_shop reset+configure 自有 gateway 不受影响）。
- **跨 feature 解耦**：`玩家2已被淘汰` 为 turn_flow 与 deities 共享 phrase（deities 借用、自身不定义）。重写后该 phrase 改为 game-preserving（在既有 game 上淘汰，保住 deities 先置的神灵），新增 turn_flow 专用 `四人human局中玩家2已被淘汰` 强制全人类局供轮转跳过场景。修复重写初期 deities #126「淘汰玩家神灵不递减」回归（旧实现 `_human_game` 重建 game 擦掉神灵）。
- **manifest**：turn_flow.feature 内嵌 mutation manifest（行 1–313）已陈旧，但为注释，`make acceptance` 忽略；按约 coder 不手改，交 refactorer/architect 经 mutation run 刷新。
