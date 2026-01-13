# 蛋仔大富翁：设计案需求 vs 代码实现核查（v1）

日期：2026-01-13  
范围：当前仓库 `main` 分支（Love2D 适配版玩法闭环）  
设计来源：`docs/design/蛋仔大富翁--设计案.md`（重点包含“行动逻辑/道具卡/机会卡/地块/医院/深山/税务局/破产/AI”章节）

## 1. 结论摘要

- **核心回合制闭环已存在**：可完成“投骰→移动→落地触发（机会/道具/地块/医院/深山/税务局/黑市/地雷）→结束回合”。
- **大量交互/AI细则未对齐**：尤其是设计案中“10秒无输入默认确认”“黑市弹窗购买”“强征/免费/免税询问是否使用”“AI道具优先级/遥控骰子选点”等，当前实现多为“自动执行/简化逻辑”。
- **强制移动后的二次落地链路已实现**：机会卡产生 `need_landing` 会通过 `ChanceService.resolve` 立即触发落地结算。

## 2. 代码实现总览（定位入口）

- 回合状态机：`src/gameplay/app/services/turn_manager.lua`
- 回合阶段：`src/gameplay/app/turn/start.lua` / `roll.lua` / `move.lua` / `land.lua` / `end_turn.lua`
- 移动服务：`src/gameplay/app/services/movement_service.lua`
- 落地解析：`src/gameplay/app/landing_resolver.lua` + `src/gameplay/domain/landing.lua`
- 地块（购买/加盖/租金/税务）：`src/gameplay/domain/land.lua`
- 机会卡：配置 `src/config/chance_cards.lua`；执行 `src/gameplay/domain/chance.lua`；服务 `src/gameplay/app/services/chance_service.lua`
- 道具：配置 `src/config/items.lua`；执行 `src/gameplay/domain/item.lua`（含部分自动策略）
- 黑市：`src/gameplay/app/services/market_service.lua`（当前为自动买）
- 医院/深山/神明状态：`src/gameplay/app/services/status_service.lua`
- Love2D 自动点击（auto_play）：`src/adapters/love2d/auto_runner.lua`、`src/adapters/love2d/love_layer.lua`

## 3. 已对齐/基本对齐项（按设计案）

### 3.1 回合与移动
- 回合结构：`start → roll → move → landing → end_turn`（与“行动前/行动中/行动后”相近，但目前缺少“行动后阶段”的道具使用窗口）。
- 两骰/一骰：以 `player.seat_id` 判断，2骰/1骰（`src/gameplay/app/turn/roll.lua`，常量 `src/config/constants.lua`）。
- 岔路奇偶：移动时将 `raw_total` 作为分支奇偶（`turn/move.lua` 传入 `branch_parity`；`domain/core/board.lua` 根据奇偶走分支）。
- 经过起点奖励：每次越过起点按次数发放 `pass_start_bonus=2000`（`movement_service.lua`）；落在起点另有一次“停在起点奖励”（`domain/landing.lua`）。

### 3.2 医院/深山/税务局/破产
- 医院：费用 `1000`、停留 `2` 回合（`status_service.lua` + `constants.lua`）。
- 深山：停留 `2` 回合；深山中不收租（`status_service.is_in_mountain` + `land.lua` 中租金逻辑）。
- 税务局：按 `50%` 现金缴税，支持免税卡（`land.lua` 的 `tax` effect）。
- 破产：现金不足时淘汰（租金/税务/机会卡等场景中调用 BankruptcyService）。

### 3.3 机会卡
- 抽取权重：按 `weight` 随机（`ChanceService.draw_card` + `util/random.lua`）。
- 天使免疫负面：`card.negative == true` 且天使附身则负面机会卡无效（`domain/chance.lua`）。
- 强制移动后的二次落地：`need_landing` 会立即调用 `LandingResolver.resolve` 继续结算（`app/services/chance_service.lua`）。

### 3.4 地雷
- 落点检查地雷；天使免疫并清除地雷；否则送医并摧毁座驾（`tile_service.lua`）。

## 4. 未实现/不一致项清单（按“设计案原意”核查）

### 4.1 交互与阶段
1) **“每步操作最大等待时间10秒，超时默认确认”未实现**
- 现状：仅有常量 `action_timeout_seconds=10`，未见在 UI/TurnManager/Choice 体系中使用。
- 影响：玩家不操作不会自动确认；与设计案节奏不一致。

2) **“行动后阶段可使用道具”未实现（或缺少对应窗口/流程）**
- 现状：回合开始阶段有 `auto_pre_action`（`turn/start.lua` 调用 `ItemEffects.auto_pre_action`），但没有对称的“行动后可用道具”阶段。

3) **道具“使用/丢弃”UI与时机提示未完整实现**
- 现状：存在道具 timing 字段（`config/items.lua`），但核心交互主要通过 `LandingResolver` 的“可选行动”或自动逻辑推进，缺少设计案中详细的“只能在行动前/回合内/触发时使用”的提示与限制。

### 4.2 黑市
4) **黑市购买方式不一致（设计：弹窗选购；现状：自动买）**
- 现状：到达黑市直接 `MarketService.auto_buy` 把能用金币买的、买得起的、背包未满的全部买入（`tile_service.lua`、`market_service.lua`）。
- 设计案：经过黑市弹窗购买，且“卡槽满提示不能买”。

### 4.3 租金/相邻地块/深山收付款
5) **“相邻地块租金=相邻地块之和”的判定口径可能不一致**
- 现状：`contiguous_rent` 以 `board.path` 的相邻索引连续 land 为“相邻”（`land.lua`）。
- 风险：若地图“相邻”不等价于 path 连续（例如分叉/同区域但非连续 index），会与设计偏差。

6) **深山“任何向该玩家支付金币时支付为0”仅在部分场景覆盖**
- 现状：租金场景覆盖；机会卡的 `pay_others` 对收款方在深山时跳过；但并非所有“支付给玩家”的效果都统一通过同一转账网关处理。

### 4.4 道具效果与交互（与设计案不一致）
7) **强征卡/免费卡/免税卡：缺少“是否使用”弹窗**
- 现状：在租金/税务逻辑中会自动消耗（`land.lua`）。
- 设计案：应弹窗“使用/放弃”。

8) **遥控骰子卡：实现为直接设为6，而非“点选1~6并按落点优先级选择”**
- 现状：`remote_dice_max` 将骰子全部设为 6（`item_post_effects.lua`）。
- 设计案：允许玩家点击调整点数；AI按目标格优先级选点数。

9) **路障卡：仅“前方3格找第一个可放”**
- 现状：`place_roadblock_ahead` 不区分格子类型，不考虑后方（`item_post_effects.lua`）。
- 设计案：前/后不同格子有明确优先级。

10) **导弹卡/怪兽卡：目标筛选口径与设计案可能偏差**
- 怪兽卡：实现为前后3内找“他人且有建筑(level>0)”且总投入最高（与设计案一致）。
- 导弹卡：`find_target` 允许选择 value=0 的格子（不要求“他人建筑存在”），因此自动策略可能会在无建筑时仍发射（`item_missile.lua` + `item_board_utils.lua` + `item.lua`）。

11) **请神卡/送神卡/穷神卡/均富卡/流放卡/查税卡：目标选择策略与设计案不一致**
- 现状：候选列表通常按玩家顺序，UI开时由玩家选，否则默认第一个；未实现“现金最多/优先天使再财神”等策略（`item.lua`、`item_target_effects.lua`）。

### 4.5 AI与自动
12) **AI策略未实现（设计案给了细到每张卡的优先级）**
- 现状：`main.lua` 默认 `auto_all=true` + `love_layer` 的 `auto_play`/`AutoRunner` 会倾向“选第一个/点确认”；`ItemEffects.auto_pre_action` 只按少量规则自动用几张卡。

## 5. 实现路线图（建议优先级）

> 目标：在不大改架构的前提下，把“设计案的可见行为”对齐到可验收的程度。

### P0（先修：会导致玩法明显不一致/容易被认为“没做”）
1) **补齐 10s 超时默认确认**
- 方案：在 `LoveLayer:update` 或 Choice 系统引入计时器：当存在 `pending_choice`/modal 且无输入超过 `constants.action_timeout_seconds`，自动选择默认项或确认。
- 影响文件：`src/adapters/love2d/love_layer.lua`、`src/adapters/love2d/auto_runner.lua`、可能需要读取 `src/config/constants.lua`。

2) **黑市改为交互式（而非 auto_buy）**
- 方案：进入黑市时 `Choice.open` 展示可购买道具列表（按价格/权重等），允许多次购买/或一次购买后关闭（按设计案最小实现：一次购买）。
- 影响文件：`src/gameplay/app/services/tile_service.lua`、`src/gameplay/app/services/market_service.lua`、`src/gameplay/app/choice_resolver.lua`（新增 choice kind）。

3) **强征/免费/免税改为“提示是否使用”**
- 方案：在 `land.lua` 的租金/税务 effect 中，当检测到对应卡时返回 `waiting` intent，交由 `Choice` 决定用/不用。
- 影响文件：`src/gameplay/domain/land.lua`、`src/gameplay/app/choice_resolver.lua`。

### P1（对齐：按设计案补齐关键道具/后置阶段）
4) **加入“行动后阶段”与回合内道具窗口**
- 方案：在 `TurnManager` phases 中新增 `post_action`（或在 `landing` 后、`end_turn` 前插入），让玩家可在回合结束前使用“回合内可用”的主动道具。
- 影响文件：`src/gameplay/app/services/turn_manager.lua`、新增 `src/gameplay/app/turn/post.lua`、`LandingResolver` 可选行动逻辑（可复用）。

5) **遥控骰子卡按设计支持点数选择**
- 方案（玩家）：提供 choice “设置骰子点数(1~6)”；将选择写入 `pending_remote_dice`。
- 方案（AI）：另行实现策略模块（见 P2）。
- 影响文件：`src/gameplay/domain/item_post_effects.lua`、`choice_resolver.lua`。

6) **路障卡支持前/后放置并按类型优先级选格**
- 方案：提供可选格列表（前后3）并允许选择；或在无 UI 时按优先级自动选。
- 影响文件：`item_post_effects.lua`、可能需要 tile 类型扫描工具。

7) **导弹卡目标筛选收紧为“他人建筑存在”**
- 方案：`Missile.find_target` 的 `score_fn` 在无 owner/level==0 时返回 nil，避免“0分也可选”。
- 影响文件：`src/gameplay/domain/item_missile.lua`。

### P2（AI 对齐：按设计案实现“可解释的策略”）
8) **新增 AI 决策层（不与 UI auto_click 混用）**
- 目标：让 `player.is_ai==true` 时，选择/使用道具遵循设计案优先级，而不是“点第一项”。
- 方案：新增 `src/gameplay/ai/`（或放在 domain 下）实现：
  - 遥控骰子：在可达范围内按格子优先级选目标并反推出点数。
  - 路障：前/后按规则选格；不满足则不使用。
  - 均富/流放/查税/穷神：按“现金最多”等规则选目标。
  - 请神：优先偷天使再财神。
  - 送神：仅穷神附身时可用，目标现金最多。
- 影响文件：`src/gameplay/domain/item.lua`（auto_pre_action 改为对 AI 调用策略）、`choice_resolver.lua`（当需要选择时由 AI 自动提交 action）。

### P3（细节完善/一致性）
9) **统一“深山收付款为0”的语义到转账网关**
- 方案：引入 `MoneyService.transfer(from,to,amount,reason)`，在其中统一判断深山、天使、神明加成等；逐步替换 `chance.lua`/`land.lua` 中的分散逻辑。

10) **明确“相邻地块”口径（按地图邻接而非 path 连续）**
- 方案：若设计案的“相邻”指地图物理邻接，需要在 board/map 中提供邻接关系并基于 owner 连通块计算租金加成。

## 6. 验收建议（可操作的检查点）

- 超时：停在可选弹窗不操作，10秒后自动选择/确认。
- 黑市：进入黑市必弹窗，卡槽满提示“无法购买”，可手动选购。
- 租金/税：踩到他人地块/税务局时，若有对应卡会询问“使用/放弃”。
- 机会卡强制移动：触发“前进/后退/送医院/送深山/送税务局/送黑市”后，会继续触发落点事件。
- AI：打开 AI 专用策略后，遥控骰子/路障/请神等行为符合设计案优先级（可通过日志验证）。

---

如需我直接进入实现阶段，建议先从 **P0：超时 + 黑市交互 + 卡牌提示** 开始，这三项改动最直观也最接近设计案体验。