# T3 — 神仙状态卡清除站静态审计

> 范围：仅审计「清除点」（clear-sites）。不覆盖 apply-sites（T1）/ tick 机制本体（T2）/ 读取站（rent/chance）。

## 调用站清单

逐项 `clear_player_deity` 调用：

| # | 站点 | file:line | 触发条件 | 调用者 / 调用对象 | 分类 |
|---|------|-----------|----------|------------------|------|
| 1 | 定义站 | `src/player/actions/state_ops/deity_ops.lua:18-24` | （定义本身）将 `status.deity = { type="", remaining=0 }` 并 `mark_players` | — | WORKING |
| 2 | tick 自动到期 | `src/player/actions/state_ops/deity_ops.lua:50` | `tick_player_deity` 中 `deity.remaining` 减到 `<=0` 时 | `self:clear_player_deity(player)`，对象 = 当前 tick 的 player | WORKING |
| 3 | 请神卡（invite_deity）| `src/rules/items/post_effects.lua:144` | 道具 `invite_deity` apply 时（已通过 `filter_target` 检查 target 持有 deity） | `game:clear_player_deity(target)`，**先清 target，再 `set_player_deity(user, deity.type, deity.remaining)`**（line 145） | WORKING |
| 4 | 送穷神卡（send_poor）| `src/rules/items/post_effects.lua:163` | 道具 `send_poor` apply 时（已通过 `require_user` 检查 user 身上有 `poor`） | `game:clear_player_deity(user)`，**先 `set_player_deity(target, "poor", remaining)`（line 162），后 clear user** | WORKING |

直接对 `status.deity` 赋值（非通过 `clear_player_deity`）：

| # | file:line | 行为 | 分类 |
|---|-----------|------|------|
| a | `deity_ops.lua:20` | `status.deity = status.deity or { type="", remaining=0 }`（clear 内部 fallback 初始化） | WORKING |
| b | `deity_ops.lua:29` | set_player_deity 中 fallback 初始化 | WORKING（不属于 clear-site） |
| c | `deity_ops.lua:43` | tick_player_deity 中 fallback 初始化 | WORKING（不属于 clear-site） |
| d | `src/player/actions/player.lua:30-33` | 玩家初始化：`self.status = { ..., deity = { type="", remaining=0 }, ... }` | WORKING（构造期，非运行期清除） |

`status.deity = nil` 的直接重置：**0 处**（grep `\.deity\s*=\s*(nil|\{)` 无匹配，仅上面赋空表的情形）。

## 破产/出局路径调查

针对 bankruptcy / eliminated / reset_player / player_lose / game_over 流程逐一检查是否清理 `status.deity`：

### 1. 主清算入口 `src/rules/endgame/bankruptcy.lua:107-154 bankruptcy.eliminate`

逐行核对清理动作：

- L116-127：清空地块 `reset_tile` + `set_player_property(player, tile.id, false)`
- L129：`inventory.clear(player)` 清空背包
- L131：`game:set_player_eliminated(player, true)`
- L132：弹出破产 popup
- L133-137：emit `feedback.bankruptcy` 事件
- L139-141：调用 role.die / mark_role_lose
- L143-145：通知 tiles_cleared
- L147-153：从 `game.occupants` 移除占位

**未发现任何 `clear_player_deity(player)` 或 `status.deity` 清理调用。**

### 2. `set_player_eliminated` (`status_ops.lua:16-19`)

只设置 `player.eliminated = true`，无 deity 清理。

### 3. 破产入口的全部上游

通过 `bankruptcy_port.eliminate` 进入 `bankruptcy.eliminate` 的所有点：

- `src/player/actions/state_ops/location_ops.lua:51`（医药费不足破产）
- `src/player/actions/state_ops/location_ops.lua:61`（支付医药费后破产）
- `src/rules/items/post_effects.lua:133`（查税卡支付后破产）
- `src/rules/land/events.lua:49`（rent_bankrupt）
- `src/rules/chance/handlers/common.lua:54 / 59`（机会卡相关）

所有上游均把清算责任委托给 `bankruptcy.eliminate`，不自行清 deity；`bankruptcy.eliminate` 又不清 deity → **链路全程缺失**。

### 4. 结论

- `player.eliminated = true` 后，`status.deity` 仍保留破产前的 `{ type, remaining }`。
- 由于多处读取（如 `rules/items/steal.lua:92`、`rules/items/handlers.lua:101`、`rules/choice_handlers/item/steal.lua:54`）会先 `if not player.eliminated` 短路，**部分逻辑不会被影响**。
- 但仍存在 SUSPICIOUS 风险：
  - `invite_deity` 的 `filter_target` 仅检查 `target.status.deity` 真值，未检查 `target.eliminated` → 已破产玩家身上残留 deity 仍可能被「请走」（注：道具 apply 顶层是否在更外层过滤掉 eliminated target，需 T4 / 道具调度层确认；从 post_effects 本文件看不到守卫）。
  - tick 流程对 eliminated 玩家是否仍执行 `tick_player_deity`，未在本任务范围内（T2 覆盖）；如果跳过，则残留计数永不归零，与「破产即销号」语义不一致。
  - `feedback.deity_applied` / `deity_evicted` / `deity_transferred` 等事件历史可能与 eliminated 玩家最后状态不一致，UI 层可能看到「死人持神」。

**分类：SUSPICIOUS（破产/出局路径未清 deity，需 NEEDS-SPEC 决定语义）。**

## Over-clear / Under-clear 风险评估

| 风险 | 站点 | 详情 | 分类 |
|------|------|------|------|
| over-clear | `post_effects.lua:144 invite_deity` | 顺序为「先 clear target → 再 set user」。若 `set_player_deity` 抛错（assert 失败等），target 已被清而 user 未被赋值，状态不一致 | SUSPICIOUS（防御性顺序问题；目前 `assert(name ~= nil)` 只防 nil，line 143 已 assert deity 存在，实际不会触发） |
| over-clear | `post_effects.lua:163 send_poor` | 顺序为「先 set target → 再 clear user」。如果 user == target（自送），先 set_player_deity(target=self,"poor", remaining) 写入新数据，再 `clear_player_deity(self)` 把刚写入的清掉，导致「送神后自己丢神且穷神丢失」 | SUSPICIOUS（需 T4 道具调度层确认是否禁止 user==target；handlers.lua:101 道具普遍要求 `target.id ~= player.id`，若该规则覆盖 send_poor 则无问题） |
| under-clear | bankruptcy 主流程 | 见上一节 | SUSPICIOUS |
| under-clear | turn 切换 / 回合开始 / 角色重置 | grep 未发现 `reset_player` 等函数；`tick_player_deity` 是唯一基于回合推进的衰减入口 | WORKING（设计如此；非清除点） |
| over-clear | `tick_player_deity:50` | 仅在 `remaining` 减到 ≤ 0 时清除，前置 L45 已守卫；逻辑闭合 | WORKING |

## 未审查清单

以下属于其他 Task 的范围，本 Task 未深究：

- `tick_player_deity` 的调用时机与 turn-phase 绑定（`src/turn/phases/registry.lua` 的具体 hook 顺序）→ T2
- `set_player_deity` 的 apply 站（poor / angel 配置入口、机会卡赋予 deity 等）→ T1
- `player_has_deity` 的所有读取站点（rent 折扣 / 偷窃免疫 / 道具守卫等）→ T4 或后续
- 道具 `apply` 的外层调度（是否在 `handlers.lua` / dispatcher 层过滤 eliminated target）→ T4
- UI 层对 deity 显示与 eliminated 标记的同步逻辑

## QA 摘要

- 「调用站清单」共 4 项 `clear_player_deity` 直接调用，均已枚举。
- 「破产/出局路径」grep 24 处相关文件，确认 `bankruptcy.eliminate` 链路 0 处清理 deity。
- 主要风险：破产残留 deity（SUSPICIOUS, NEEDS-SPEC）；`send_poor` 自送场景顺序问题（SUSPICIOUS, 需上层确认）。
