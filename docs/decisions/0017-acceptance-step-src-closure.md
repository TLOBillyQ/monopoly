---
kind: adr
status: stable
owner: quality
last_verified: 2026-05-31
---
# ADR 0017 — Acceptance step handler 收敛到 src 闭环

## 背景

ADR 0012 D1 要求验收场景经真实 `game_driver` / UI facade / 明确产品 mock 观察，不依赖模块私有状态；D4 要求 step handler 不平行实现业务规则，若重写了一套与 `src/` 平行的规则「只能作为临时过渡，后续必须收敛到真实 driver/facade」。

2026-05-31 对 `tools/acceptance/steps/*.lua` 做 feature→src 闭环审计（详见 `agent_context/architect/acceptance-src-closure-audit.md`）：19 个玩法/UI feature 中 16 个真闭环（Tier A 经 `game_driver`、Tier B 经 `src.ui.coord`/`host_integrations`），但发现两个 D4「临时过渡」从未收敛，外加一个孤儿 feature：

- `turn_flow.lua`（758 行，仅 require `number_utils`）：自建 `world.turn` 模型，handler 内重实现回合轮转/淘汰（`_next_active_player`）、`turn_count`，并硬编码 `AI_ITEM_PRIORITY` / `AI_TRIGGER_KNOWN` / `_ai_priority_rank`，断言打自身 fixture。`src/turn/*`、`src/rules/items/handlers.lua`、`src/config/content/items.lua` 从不被调用。
- `bankruptcy.lua`（仅 `number_utils` + `shared`）：handler 自判破产（`world.player.bankrupt = true`）再断言自身判定，`src.rules` 破产逻辑未 import。
- `features/game/setup.feature`：4 场景，不在 `acceptance_features.lua` registry、无 `setup.lua`、无 harness 引用。

这两个是核心玩法（回合流程 / 破产清算）却对 src 零保护：回归对应 src，`make acceptance` 仍全绿。本 ADR 把 0012 D4 的「后续必须收敛」落为具体收敛令，并补一条 0012 未显式写出的 fixture 边界。

## 决策

### D1 — 收敛对象与优先级

以下 Tier C 假绿 handler 必须重接到真实 driver，删除平行重实现：

1. **`turn_flow.lua`（最高优先）** — 经 `game_driver`（或回合专用 driver）驱动真 `src/turn/*` 的轮转/淘汰/回合推进；AI 决策走真 `src/rules/items` + `src/turn/policies`，不在 handler 复制。
2. `bankruptcy.lua` — 破产判定来自 `src.rules`，handler 只布置现金/费用初值并触发真实结算，断言读 src 产出的破产状态。

### D2 — fixture 仅作种子，不承载规则判定

`shared.ensure_player` / `ensure_target` 等 fixture 助手只可造**初始** state（现金、持有、空袋等种子值）。禁止在 step handler 内写规则**结论**（例如由 handler 判定并赋 `world.player.bankrupt = true`）。任何规则结论必须由 `src/` 计算后被断言读取。这是对 0012 D4 的收紧。

### D3 — 单一真源，禁止常量复制

handler 不得复制 `src/` 已有的业务常量/表。`turn_flow.lua` 的 `AI_ITEM_PRIORITY` / `AI_TRIGGER_KNOWN` 必须来自 `src/config/content/items.lua` / `src/rules/items/handlers.lua` 单源，消除人工同步漂移。

### D4 — `setup.feature` 处置

先确认 4 个场景（游戏初始化、报名人数→行动角色数、允许开始）的产品意图：

- 有产品价值 → 入 `acceptance_features.lua` 并写经 `game_driver` 真闭环的 handler；
- 无价值 → 删除 feature。

默认不保留「挂在仓库但不跑」的中间态。

### D5 — 重申新 handler 守则

沿用 0012 D1/D4：新增 acceptance step 一律经真实 `game_driver`/facade 观察，不得平行实现业务规则；仅工具自身测试与纯展示 mock 可维护 world-only 小模型。

## 验证

- `make acceptance` 收敛后仍绿（先从 feature 重生成 gitignored 生成物，ADR 0015）。
- 收敛真实性反证：对 `src/turn/*`（及破产规则）的关键分支跑差分变异；重接**前** turn_flow / bankruptcy 杀不掉这些 src 分支变异（survivor），重接**后**应转为 killed。以「变异由红转杀」证明断言确实穿透到 src，而非再次落到新 fixture。
- `turn_flow.lua` 去重后 grep 确认 `AI_ITEM_PRIORITY` 等不再在 `tools/acceptance/` 出现。

## 影响

- 所有权：场景/步骤改写属 specifier + coder；架构师负责本边界裁决与收敛后验收。
- 风险：turn_flow 经 `game_driver` 驱动真回合机后，原本被 fixture 掩盖的 src 行为差异可能显化为红——这是预期的「揭债」，按 0012「区分新增失败与既有失败」处理。

## 附录 — D1.1 驱动面裁定（2026-05-31，回应 turn-flow-driver-surface 契约）

D1.1 留口「经 `game_driver`（或回合专用 driver）」。coder 在动工前升级裁定，裁断如下。

### 裁定：B — 独立 `turn_driver`，但**共享单一组合根 / 同一 `ctx`**

不扩 `game_driver`（A），另起 `tools/acceptance/turn_driver.lua` 与之并列；二者**不重新组合 game**，over 同一 `ctx`。

理由：
- **职责内聚**：`game_driver` 现职责是 board/空间/骰子/地块效果 over `ctx.game`，内聚且窄（225 行）。塞入 5 簇回合生命周期会膨胀近 3 倍并混两个技术边界（空间态 vs 时序/决策）——违反本仓库「拆混合职责、维护技术边界」的模块律。
- **零重复组合**：`src.app.compose_game` 已 wire 真 `turn_runtime`（`game.turn_runtime = turn_runtime:new(game, phases)`）+ 默认 phase 序。`ctx.game` 自带真实回合机，`turn_driver` 作为第二 facade 直接驱动真 `src/turn/*`，无需也**不得**自建/重组 game。
- **单一组合根**：`game_driver.new_game(opts)` 仍是唯一 game 构造点、产出 `ctx`；`turn_driver` 只接 `ctx`。杜绝双 game 实例漂移。
- **观察复用（应「勿重复造」）**：cluster 3 落地结算复用 `game_driver` 的 move/tile 观察 verb（经共享 `ctx`）；跑真实 phase 序时移动自然走 `src/turn/phases/move`→`src/rules/movement`，是真 src 而非平行实现。`turn_driver` 不复制空间观察。
- **解耦**：两 driver 互不 `require`；step handler 层持同一 `ctx` 分别调用（空间 op→game_driver，时序/生命周期 op→turn_driver），避免编译期耦合。

### 形状边界（能力归属，非签名处方——签名归 coder）

`turn_driver` over 真 `src/turn/{loop,phases,policies,waits,deadlines,timing,actions}` + `src/rules/items` + `src/config/content/items`：

1. **轮转/淘汰/扣留/临时态** → `src/turn/loop` + `phases/start` + `policies/role_control`；推进读 `turn_runtime`，**不自建** index 环。
2. **阶段序** → 观察 `src/turn/phases/registry` 的真实 phase 序列。
3. **落地结算** → 真 `src/turn/land`/`move_followup`/`rules`；复用 game_driver 空间观察。
4. **超时/deadline/等待/打断** → `src/turn/deadlines`/`timing`/`waits` + `policies/{timer,auto_runner,choice_auto}`。
5. **AI 道具阶段** → `policies/auto_runner`+`choice_auto` 驱动；**D3 单源**：优先级/触发条件读 `src/config/content/items.lua` + `src/rules/items/handlers.lua`，`turn_driver` 与 step 均**不得**复制 `AI_ITEM_PRIORITY`/`AI_TRIGGER_KNOWN`。

### `ctx` 契约
`ctx` 为普通表（含 `game`/`_events`/`_rng_queue`…）。`turn_driver` 读 `ctx.game.turn_runtime` 等真实字段；如需回合专属句柄挂 `ctx` 上新键，不得破坏 `game_driver` 既有字段。

## 附录 — D4 裁定（2026-05-31，setup.feature 处置）

coder 读真 src 后升级：契约前提「roster.lua 真支撑全部场景」对 4 场景中的 2 个为假。`src/app/roster.lua`（`max_player_count=4` 硬编码、`_build_startup_roster` 补 AI 到 4、`_warn_if_roles_truncated` 仅 warn）**恒填 4 槽、无 reject 路径、无「报名人数」输入**，与 setup.feature 场景 3（2-4 按原数不补）、场景 4（拒绝 0/5）矛盾。feature/ADR 0011 D1 设计与现 src 是两套不同产品；ADR 0011 仍 `proposed` 未批。

### 裁定：B — 重框 feature 匹配现 src（不改 src）

升级用户裁定（产品价值判断 + 未批 ADR + 宿主容忍 = 用户 lane）：**产品行为以现 src 为准——恒 4 人局（真人不足补 AI）、永不拒绝**。不改 `roster.lua`、不动游戏初始化语义、不触宿主四槽模型。

- **specifier lane**：register `features/game/setup.feature`，重框场景使其与「恒 4 槽」现实自洽——报名 N→行动 4 / AI=4−N、报名 5→截断 4、报名 0→4 AI；**删掉**「2-4 按原数不补」与「拒绝开局」语义。
- **真闭环不变**：所有场景经 `game_driver.new_game`（真 `compose_game`）+ `roster.lua` 真装配 + `runtime_ports` 注入真角色 mock 驱动；断言读 player 真状态 / `constants.lua` 单源（金币 100000、卡槽 5，**勿硬编码**）；不落 fixture、不重实现 roster 规则（ADR 0017 D1/D5）。
- **不取 A**：A（抽纯 roster 规则 + reject + 支持 2-3 人）是兑现未批 ADR 0011 D1 且依赖 Eggy 容忍非 4 人局——用户未选，搁置；若日后产品确立可变人数，再起 A 并先确认宿主支持。
- **不取 C**：用户直接定 B，无需拆分增量。

ADR 0011 D1 的「开局玩家数」项与本裁定的张力（设计 vs 实现）记此；ADR 0011 仍 proposed，待用户整体 review 时一并裁。

## 附录 — D3 单源勘误 + 道具超时语义裁定（2026-05-31，回应 turn-flow-driver-surface cluster 5 实证）

coder 建 cluster 5（AI 道具阶段真触发门控）时核对真 src，发现 D3 引证位置有误、并升级一处 feature 措辞与 src 的语义出入，裁断如下。

### D3 勘误：AI 优先级/触发单源是 `src/rules/items/strategy.lua`，不在 `items.lua`/`handlers.lua` 数据字段

D3 正文写「`AI_ITEM_PRIORITY`/`AI_TRIGGER_KNOWN` 必须来自 `src/config/content/items.lua`/`src/rules/items/handlers.lua` 单源」——经验证 src **无** `ai_priority`/`ai_trigger` 数据字段。真实单源是 `src/rules/items/strategy.lua` `_run_auto_pre_action_probes` 的**调用链顺序**（清障→遥控骰→地雷→骰子加倍→路障→怪兽→目标类[序由 `post_effects.target_item_ids()`]→神祇类）+ 该文件内**内联谓词**（`has_obstacles_ahead`/`pick_remote_dice_value`/`pick_roadblock_target`/`_has_target_player`/`_has_demolish_target`）。

D3 的**意图不变且已兑现**：「禁止 handler/driver 复制 src 业务常量、单一真源」。driver 经 `turn_driver.run_ai_item_phase`→真 `item_strategy.auto_pre_action` 驱动，读不到任何列表（优先级/触发全自 src）。**specifier 重框断言**：场景须表述为「驱真 strategy 后某卡被/未被消耗」（被 `run_ai_item_phase` 真触发门控决定），**不得**写「按优先级列表」或假定数据字段；单源指 `strategy.lua`。次要事实：AI 一个 pre_action pass 会**按序用掉所有满足触发的卡**（每个 `_try_use_item` 触发即 `executor.use_item({by_ai=true})` 消耗），非「选一张最高优先级」。

### 道具目标超时语义：裁定为「留存」，删除「退还预消耗」措辞

`turn_flow.feature:428-432`「道具目标选择超时后退还预消耗道具 / 道具被退还至玩家背包」与真 src 出入：目标类道具在 `handlers.lua:51-52` **选定目标 apply 时才消耗**（除非 `item_preconsumed`），目标选择超时→不 apply→从未消耗→卡自然留背包；`deadlines._refund_preconsume` 是 **no-op**（`item_preconsume_policy` 无 `refund` 函数）。即 src **无退还机制**——「退还」断言会断言一个不存在的实现。

**裁定（architect lane，非用户升级）**：语义取**「留存」**。理由与 setup D4（B）不同——此处玩家**可观察产出完全一致**（超时后背包道具数不变，无论称「退还」或「未消耗留存」），不涉产品能力/价值差异，纯属场景措辞对 src 的保真，落在 ADR 0017 闭环授权内，architect 直裁。

- **specifier lane**：重框 428-432 断言**可观察留存**——「目标选择超时后该道具仍在玩家背包」，删「预消耗/退还至背包」措辞（勿断言 src 未实现的退还机制）。
- **人类目标选择路径 UI 耦合**：进入目标询问的 `_item_phase_ask_active=true` 由 `src/ui/coord/modal.lua:81`（UI 层）设；真闭环**人类**目标超时需 host/UI seam（cluster 5 余项，见下）。可先以 driver 可达的 deadline 超时观察「留存」，不跨 UI modal。
- **设计 vs 实现张力**：若 ADR 0011 / 策划曾设想「预消耗+退还」作为玩家可见 UX 反馈，那属 UI 反馈层、出验收（规则产出）范围；记此，待 ADR 0011 整体 review 一并裁。

### cluster 5 余项 → cluster 6（AI 落地结算 seam），specifier 一次性重框前置

`turn_flow.feature:464-509` 的 AI 场景分两类：**主动道具优先级**（286/299）已经 cluster-5 核心 `run_ai_item_phase` 可驱真；但**电脑自动买地/升级/对手地免租**（247/260/273）走**落地结算** `choice_auto`（AI actor），驱整局 AI 回合经协程触**宿主 LuaAPI 缺口**——cluster-5 余项，尚不可真闭环。

依用户 one-shot 节奏裁定（feature 文件待全部 driver 簇就位后一次性重写，避免反复 thrash）：**保持 specifier 待命**，先路由 coder 落 **cluster 6 — AI 落地结算 driver seam**（决策策略 seam 或薄 host LuaAPI stub）。cluster 6 就位后 driver 面方才覆盖 turn_flow 全场景，再一次性路由 specifier 重写 `turn_flow.feature` + 删除 `turn_flow.lua` 假绿。

## 闭环 stamp — D1 turn_flow 收敛完成（2026-05-31）

turn-flow-driver-surface 全程交付完成，ADR 0017 三处审计缺口全部关闭：

- **D1.1 turn_flow**（最高优先，本次）：driver 面 clusters 1–6 就位（轮转/淘汰/扣留/阶段序/落地卡牌/超时/等待/AI 道具阶段/AI 落地结算），`turn_flow.feature` 一次性重写经真 `turn_driver`/`game_driver` 闭环，`turn_flow.lua` 删尽 `_next_active_player`/`AI_ITEM_PRIORITY`/`AI_TRIGGER_KNOWN` 平行重实现（仅留注释说明已移除）。
- **D1.2 bankruptcy**（早先）：经 `game_driver` 驱真 `src.rules.land.actions`/`chance.resolver`，断言读真 `player.eliminated`。
- **D4 setup**（早先，用户裁 B）：`setup.feature` 重框匹配恒 4 槽现 src，经真 `roster.build_game_factory` + `runtime_ports` 真角色注入。

**穿透反证（ADR 验证段「变异由红转杀」）**：重写前 `turn_flow.feature` soft-gherkin = 23 场景全 skip / total=0（假绿无可突变 world-state 断言）；重写后 = **total=26 killed=26 survived=0**。断言确实穿透到 src。

**两裁落实**（specifier 27af3b73）：AI 断言改「消耗满足触发条件的主动道具」（触发驱动，单源 strategy.lua，无优先级列表）；道具超时改「未被消耗仍留存背包」（删退还，对齐 src 无退还机制）。

验证全绿：tooling 318 / make verify 9/9 / make acceptance 540 / soft-gherkin 26/26 killed / DRY 仅 step-binding 内在样板（benign）/ src 零改动。

cluster-5 余项中「驱整局 AI 回合经协程触宿主 LuaAPI 缺口」未再现——seam (a) 经 `choice_auto`/`settle_landing` 直驱决策+结算函数绕开，turn_flow 全场景已覆盖。如未来需真整局 AI 协程闭环（超出 turn_flow 验收范围），另起任务。
