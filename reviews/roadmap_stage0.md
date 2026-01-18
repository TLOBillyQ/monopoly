# 阶段 0 交付物：分解清单与回归检查

## 分解清单（按 gap）

1) 胜利条件：仅剩<=1玩家
- 触发路径：`Game:advance_turn()` / `Game:dispatch_action()` -> `Game:check_victory()`.
- 关键文件/函数：`src/game.lua` `Game:check_victory`, `Game:alive_players`.
- 设计差异：缺“时间到按资产结算且并列胜利”.

2) 行动超时：10s 自动确认未接入
- 触发路径：`IntentDispatcher.dispatch()` 写入 `turn.pending_choice` -> `TurnManager:run_until_wait()` 停在 `wait_choice`.
- UI 相关：`src/adapters/love2d/love_layer.lua` 仅弹窗，无超时逻辑.
- 关键文件/函数：`src/config/constants.lua` `action_timeout_seconds`, `src/gameplay/turn_manager.lua`, `src/util/intent_dispatcher.lua`.

3) 机会卡数量：设计 34，配置 37
- 触发路径：`Landing.executors.chance_draw_and_resolve` -> `random.weighted_choice(chance_cfg)`.
- 关键文件/函数：`src/config/chance_cards.lua`, `src/gameplay/landing.lua`.

4) 路障停回合
- 触发路径：`MovementService.move()` 检测 `board:has_roadblock()` -> 清除路障 -> 返回 `stopped_on_roadblock`.
- 现状：`stopped_on_roadblock` 未被后续流程使用.
- 关键文件/函数：`src/gameplay/movement_service.lua`, `src/gameplay/turn_start.lua`(扣留回合逻辑).

5) 地雷时序：事件后触发
- 触发路径：`turn_land.lua` -> `EffectPipeline.run(landing_defs)`.
- 现状：`landing_defs` 中 `mine` 在 `buy_land/upgrade_land/rent/tax` 之前.
- 关键文件/函数：`src/config/landing_effects.lua`, `src/gameplay/turn_land.lua`, `src/gameplay/effect_pipeline.lua`.

6) 清障卡分叉路径
- 触发路径：`ItemEffects.apply_post()` -> `handlers.clear_obstacles_ahead`.
- 现状：按单一路径 `step_forward_by_facing` 清除；未分叉.
- 关键文件/函数：`src/gameplay/item_post_effects.lua`.

7) 机会卡强制移动到黑市
- 触发路径：`ChanceEffects.resolve()` -> `handlers.forced_move` -> `MarketService.auto_buy()`.
- 现状：人类玩家被自动购买或跳过，无 UI 选择.
- 关键文件/函数：`src/gameplay/chance.lua`, `src/gameplay/market_service.lua`.

8) 地产购买/升级：余额不足仍提示
- 触发路径：`Effect.scan()` 依赖 `Land.can_apply` 过滤.
- 现状：`can_buy/can_upgrade` 直接用余额判断，导致选项不出现.
- 关键文件/函数：`src/gameplay/effect.lua`, `src/gameplay/land.lua`.

9) 道具丢弃流程
- 触发路径：`ItemPhase.run()` -> `ItemChoiceHandler.item_phase_choice`.
- 现状：无“丢弃”选项与处理分支.
- 关键文件/函数：`src/gameplay/item_phase.lua`, `src/gameplay/choice_handlers/item_choice_handler.lua`.

10) AI 道具使用覆盖
- 触发路径：`ItemPhase.run()`(AI) -> `Strategy.auto_pre_action()`.
- 现状：仅固定子集，未覆盖 2005(地雷)等.
- 关键文件/函数：`src/gameplay/item_strategy.lua`.

11) 富神/穷神倍率范围
- 触发路径：租金在 `LandActions.execute_pay_rent` 中倍增.
- 现状：机会卡增减/转账仅在部分效果里处理倍增.
- 关键文件/函数：`src/gameplay/land_actions.lua`, `src/gameplay/chance.lua`.

12) 破产触发：现金为 0
- 触发路径：机会卡 `apply_cash_and_maybe_bankrupt` 仅现金 < 0.
- 其他触发：租金不足时 `LandActions.execute_pay_rent` 设 0 后淘汰; 查税卡在 `item_post_effects` 仅现金 < 0.
- 关键文件/函数：`src/gameplay/chance.lua`, `src/gameplay/land_actions.lua`, `src/gameplay/item_post_effects.lua`, `src/gameplay/bankruptcy_service.lua`.

13) 偷窃卡：中途触发并续步
- 触发路径：`MovementService.move()` 记录 `encountered_players` -> `Landing.pass_players` -> `Steal.handle_pass_players`.
- 现状：移动完成后统一触发，无“中断-续步”.
- 关键文件/函数：`src/gameplay/movement_service.lua`, `src/gameplay/landing.lua`, `src/gameplay/item_steal.lua`.

14) 同格人数上限（<=4）
- 触发路径：`Game:update_player_position()` 直接追加 `occupants`.
- 现状：无上限检测/冲突处理.
- 关键文件/函数：`src/game.lua`.

15) 背包满提示
- 触发路径：`Inventory.give()` 返回 false 且仅日志.
- 关键文件/函数：`src/gameplay/item_inventory.lua`, 相关抽卡/黑市入口.

## 回归检查清单

### 自动检查
- Lua 语法：`find src tests -name '*.lua' -print0 | xargs -0 luac -p`.
- 依赖检查：`lua tests/deps_check.lua`.
- 回归脚本：`lua tests/regression.lua`.

### 手动用例（逐条对应 gap）
- 胜利条件：设定时间上限并验证并列胜利与资产排序逻辑.
- 超时确认：待选项弹出后 10s 自动确认（含取消与默认选项）.
- 机会卡数量：抽卡池总数与权重统计一致.
- 路障停回合：触发路障后下一回合跳过且路障清除.
- 地雷时序：落地事件处理完成后再触雷.
- 清障卡分叉：分叉点前清障应覆盖各分支.
- 黑市强制移动：人类玩家进入黑市弹 UI 选择; AI 走策略.
- 购买/升级提示：余额不足仍出现选项，确认后失败提示.
- 道具丢弃：背包满时可主动丢弃并继续获得新道具.
- AI 道具使用：AI 可使用地雷卡与其他可用道具.
- 富/穷神倍率：机会卡加/扣/转账均按倍率处理.
- 破产触发：现金为 0 时淘汰（含机会卡/税/道具分支）.
- 偷窃中断：移动中遇玩家触发偷窃后继续剩余步数.
- 同格人数上限：第五人进入处理策略与 UI 提示.
- 背包满提示：抽卡/偷窃/黑市购买失败提示为 UI.

