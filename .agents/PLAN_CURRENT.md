# 基础屏按客户端玩家隔离显示（已完成）

## 摘要

- 玩家信息区保持全局一致渲染。
- 非玩家信息（倒计时/行动按钮/托管按钮/自动控制按钮/道具槽位）改为按 role 渲染。
- 道具槽位按客户端玩家显示；非可操作时机禁用。
- 行动/托管仅当前回合玩家可操作。
- 事件路由携带 `actor_role_id`，调度层做越权拦截。
- 观战或未映射 role 跟随当前回合玩家显示，但不可操作。

## 执行清单

- [x] 扩展 `src/ui/UIModel.lua`：`item_slots_by_player` / `current_player_id` / `item_choice_owner_id`
- [x] 改造 `src/ui/UIView.lua`：玩家信息全局渲染，非玩家信息逐 role 渲染
- [x] 改造 `src/ui/UIEventRouter.lua`：所有点击透传 `actor_role_id`
- [x] 改造 `src/game/turn/TurnDispatch.lua`：按钮与道具槽位做强校验
- [x] 调整 `src/game/turn/AutoRunner.lua` 与 `src/game/turn/GameplayLoop.lua`，补齐自动流程 `actor_role_id`
- [x] 补充 `.agents/tests/suites/ui.lua` 覆盖新增行为
- [x] 更新 `.agents/docs/ui/01_UI_基础屏.md` 与 `.agents/docs/ui/00_UI_架构与画布.md`
- [x] 运行 `lua .agents/tests/regression.lua`：通过（40）
