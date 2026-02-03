# 回合倒计时与动画/UI 冲突梳理

## 摘要

目标是输出问题清单与证据，不改代码。覆盖倒计时计算、超时触发、UI 刷新、移动/动作动画、UI 事件分发与按钮可用性。

## 倒计时链路图

SetFrameOut tick → gameplay_loop.tick → _update_countdown → store:set(turn.countdown_seconds) → dirty.turn_countdown → UIModel 生成 turn_label → UIView.refresh_turn_label。
证据：`src/app/init.lua:102` `src/app/init.lua:106` `src/game/turn/GameplayLoop.lua:423` `src/game/turn/GameplayLoop.lua:57` `src/game/turn/GameplayLoop.lua:78` `src/core/Store.lua:77` `src/ui/UIModel.lua:148` `src/game/turn/GameplayLoop.lua:563` `src/ui/UIView.lua:147`。

## 倒计时关键条件列表

- 仅在有待选择或弹窗激活时计算倒计时，否则为 0。证据：`src/game/turn/GameplayLoop.lua:57` `src/game/turn/GameplayLoop.lua:61` `src/game/turn/GameplayLoop.lua:68`。
- 选择超时会派发自动选择动作。证据：`src/game/turn/GameplayLoop.lua:199` `src/game/turn/GameplayLoop.lua:239` `src/game/turn/GameplayLoop.lua:247`。
- 弹窗超时会自动关闭。证据：`src/game/turn/GameplayLoop.lua:251` `src/game/turn/GameplayLoop.lua:272` `src/game/turn/GameplayLoop.lua:274`。
- UI 展示为“回合 | 倒计时”。证据：`src/ui/UIPanel.lua:5` `src/ui/UIView.lua:128`。

## 动画生命周期摘要与并行点

移动动画：TurnMove 写入 turn.move_anim 并进入 wait_move_anim；GameplayLoop 在 tick 中驱动 MoveAnim，按总时长延迟派发 move_anim_done；TurnManager 仅接受 move_anim_done 推进。证据：`src/game/turn/TurnMove.lua:70` `src/game/turn/TurnMove.lua:73` `src/game/turn/TurnMove.lua:84` `src/game/turn/GameplayLoop.lua:279` `src/game/turn/GameplayLoop.lua:470` `src/game/turn/GameplayLoop.lua:298` `src/game/turn/TurnManager.lua:169` `src/game/turn/TurnManager.lua:177`。

动作动画：GameplayLoop 在 tick 中调用 ActionAnim.play，按时长延迟派发 action_anim_done；TurnManager 仅接受 action_anim_done 推进。证据：`src/game/turn/GameplayLoop.lua:308` `src/game/turn/GameplayLoop.lua:528` `src/game/turn/GameplayLoop.lua:531` `src/ui/ActionAnim.lua:40` `src/ui/ActionAnim.lua:48` `src/game/turn/TurnManager.lua:186` `src/game/turn/TurnManager.lua:194`。

并行点：step_auto_runner、step_choice_timeout、step_modal_timeout 在动画前每 tick 执行。证据：`src/game/turn/GameplayLoop.lua:428` `src/game/turn/GameplayLoop.lua:434` `src/game/turn/GameplayLoop.lua:454`。

## UI 交互入口清单

- UI → intent：UIEventRouter 统一派发 ui_button、choice_select、choice_cancel、popup_confirm、market_confirm。证据：`src/ui/UIEventRouter.lua:61` `src/ui/UIEventRouter.lua:102` `src/ui/UIEventRouter.lua:137` `src/ui/UIEventRouter.lua:158`。
- intent → 行为：GameplayLoop.dispatch_action 处理 ui_button 与 choice_*。证据：`src/game/turn/GameplayLoop.lua:343` `src/game/turn/GameplayLoop.lua:410`。
- “下一回合”有点击冷却锁，不检查当前 phase。证据：`src/game/turn/GameplayLoop.lua:378` `src/game/turn/GameplayLoop.lua:393`。

## 冲突点清单

1. 倒计时语义与文案不一致。触发条件：非选择/弹窗阶段（包括动画等待）时倒计时为 0。影响：UI 显示“回合 | 倒计时 0”，不符合“回合倒计时”的直觉语义。证据：`src/game/turn/GameplayLoop.lua:57` `src/game/turn/GameplayLoop.lua:61` `src/game/turn/GameplayLoop.lua:68` `src/ui/UIPanel.lua:5`。
2. 动画等待期 UI 仍可点击，但逻辑层忽略非动画事件。触发条件：wait_move_anim 或 wait_action_anim 期间点击“下一回合”等 UI。影响：用户点击无反馈，事件被 TurnManager 忽略。证据：`src/ui/UIEventRouter.lua:102` `src/game/turn/GameplayLoop.lua:343` `src/game/turn/TurnManager.lua:169` `src/game/turn/TurnManager.lua:177`。
3. 动画期间点击“下一回合”触发冷却锁，导致后续点击短暂失效。触发条件：wait_move_anim 或 wait_action_anim 期间点击“下一回合”。影响：动画结束后短时间内按钮仍可能无效，放大“无反馈”感知。证据：`src/game/turn/GameplayLoop.lua:378` `src/game/turn/GameplayLoop.lua:393`。
4. 自动托管在动画阶段持续发起“下一回合”，产生重复无效推进。触发条件：auto_play 开启且处于动画等待。影响：重复派发 ui_button: next，被 TurnManager 忽略，同时触发冷却锁逻辑，可能影响手动点击时机。证据：`src/game/turn/GameplayLoop.lua:187` `src/game/turn/GameplayLoop.lua:192` `src/game/turn/GameplayLoop.lua:378`。
5. 弹窗超时与动画/回合推进并行，可能导致信息被快速关闭。触发条件：弹窗激活期间进入动画等待或其他阶段，step_modal_timeout 仍计时。影响：弹窗在动画或其他操作中被自动关闭，信息易被错过。证据：`src/game/turn/GameplayLoop.lua:251` `src/game/turn/GameplayLoop.lua:272` `src/game/turn/GameplayLoop.lua:274` `src/ui/UIView.lua:287` `src/ui/UIView.lua:308`。
