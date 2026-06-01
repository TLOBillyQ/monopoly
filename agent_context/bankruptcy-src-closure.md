# bankruptcy 收敛：重框到具体规则上下文 + 真 src 闭环（bankruptcy-src-closure）

specifier → coder。源自 ADR 0017 D1.2（`bankruptcy.lua` Tier C 假绿须经真 driver 收敛）。
用户裁定（2026-05-31）：重框到具体规则上下文。

specifier 交付重框后的场景（外部可见行为，下方），coder 实现真闭环 step harness + 跑变异反证。
**原子落地**：feature 改写 + step 实现必须同提交，避免 main 的 `make acceptance` 中途因未定义步骤变红。

## 现状：重实现跨 3 个文件（比 ADR D1.2 命名的更宽）

- `tools/acceptance/steps/bankruptcy.lua`：医院步骤 handler 内自算 `cash<fee → bankrupt`（D2 违反）。
- `tools/acceptance/steps/economy.lua:588` `玩家需要支付<金额>` + `:599 玩家<结果>`：fixture 算 `cash<amount → bankrupt`，零 src。
- `tools/acceptance/steps/chance.lua:117` `机会卡效果结算`：fixture 手搓 pay_each/collect_each 循环 + `world.player.bankrupt=true`。

`bankruptcy.feature` 4 场景的步骤散在这三处。**注意**：economy/chance 这两个共享步骤可能被别的 feature 用——重框后 bankruptcy.feature 不再用它们，**是否删除属另一 PR**，coder/架构先 grep 确认无其他 feature 依赖再处置，勿在本次 bundle。

## 真 src 入口（已核）与可观察状态

可观察真破产状态 = `player.eliminated`（由各规则经 `bankruptcy_port` / `common.handle_bankruptcy_if_non_positive` 置位）。`game:deduct_player_cash` 只 `assert(>=0)`，不自判破产。

| 场景 | 真入口 | 备注 |
|---|---|---|
| 0 租金破产 | `src/rules/land/landing_rules.execute_pay_rent(game, player_id, tile_id)` | 付不起返回 `result.event="rent_bankrupt"` + `bankrupt_reason`，**淘汰在下游处理 result（land/events → bankruptcy_port）**；step 须跑完整落地结算链至 `player.eliminated`，不能只调 execute_pay_rent 读返回值 |
| 1 机会卡向每人支付中途破产 | `src/rules/chance/handlers.pay_others(game, player, card)` | 已含 `if player.eliminated then break`（中途破产停止）+ `handle_bankruptcy_if_non_positive` |
| 2 机会卡向每人收取无力者破产 | chance handlers 收取分支（`pay_cash`/`percent_pay_cash` 经 `_dispatch_payment`，target=all）| 对手付不起→eliminated；玩家收到其清算额 |
| 3 医院住院费不足破产 | 医院落地规则（landing 经 hospital 费用扣除→`handle_bankruptcy_if_non_positive`）| 真落地，非 handler 自算 |

chance handlers 表经 deps 工厂构建（`src/rules/chance/handlers.lua:442 return handlers`，含 monopoly_event/number_utils/angel_feedback/common 注入）；`game_driver.new_game` 的真游戏应已接好 chance 派发，coder 用真游戏的派发入口，勿在 step 里手搓工厂。tile 归属用 `game:set_tile_owner`。

## 场景2 修正（coder 实测真 src 退回 d3fc84c5，specifier 改）

初版「持有800 / 第一位后破产」与真 `pay_others` 矛盾：它逐个对手扣费、`cash<=0` 才破产并 `break`。800 付 500/each → opp1 后 300（存活）→ opp2 后破产，opp1 与 opp2 都已收到。修正为 **持有1000**：opp1 1000→500（存活、收 500）、opp2 500→0（恰好归零触发 `handle_bankruptcy_if_non_positive`、收 500）、opp3 因 `if player.eliminated then break` 不收。避开「付不起时透支到负」的歧义（opp2 恰好付满 500 到 0，非透支），且真正体现「中途」（前两位已付、第三位被截断）。断言读真 `player.eliminated` + 各对手真现金增量。

## 重框后的场景（specifier 交付的外部可见行为）

替换 `features/game/bankruptcy.feature` 现有 4 场景。参数保留对 Gherkin 变异有效者（余额/租金/结果/金额/对手数）。

```gherkin
功能: 破产判定

  背景:
    假如 游戏已初始化标准棋盘

  场景大纲: 落在对手地块结算租金后的破产判定
    假如 玩家持有<余额>金币
    并且 对手拥有玩家所在地块且应付租金为<租金>金币
    当 玩家落地结算租金
    那么 玩家<结果>

  例子:
    | 余额 | 租金 | 结果 |
    | 100  | 200  | 破产 |
    | 500  | 200  | 存活 |
    | 0    | 100  | 破产 |

  场景: 机会卡向每位对手支付效果中途破产停止后续支付
    假如 玩家持有1000金币
    并且 游戏中有3名未淘汰对手
    当 玩家结算向每位对手支付500金币的机会卡
    那么 玩家支付前两位对手各500金币后破产淘汰
    并且 第三位对手不再收到支付

  场景: 机会卡向每位对手收取效果中无力支付的对手破产淘汰
    假如 对手A持有500金币
    当 玩家结算向每位对手收取1000金币的机会卡
    那么 对手A支付全部500金币后破产淘汰
    并且 玩家至少收到对手A的500金币

  场景: 落在医院支付住院费不足时破产淘汰
    假如 玩家持有0金币
    当 玩家落在医院结算住院费
    那么 玩家破产淘汰
```

`玩家<结果>`（破产/存活）断言读真 `player.eliminated`：破产→eliminated 为真且现金清零；存活→未 eliminated 且现金 = 余额 − 租金。

## 收敛真实性反证（coder 跑，specifier 不跑变异）

重接**前** bankruptcy 杀不掉 `src/rules/land/landing_rules`（租金破产分支）/ `src/rules/chance/handlers`（pay_others 的 `if eliminated then break`、收取破产）/ 医院落地的关键差分变异（survivor）；重接**后**转 killed。以变异由红转杀证明断言穿透到 src。

## manifest

`bankruptcy.feature` 顶部 acceptance-mutation-manifest 不手改，coder 改完由 gherkin-mutator 刷新（stamp 暂失配是预期）。
