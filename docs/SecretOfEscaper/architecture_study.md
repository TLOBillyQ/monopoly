# SecretOfEscaper / Monopoly 架构研究笔记（进行中）

本笔记用于后续重构准备，当前先补齐 Monopoly 的 Choice/Item 调用链，其他章节待补充。

## Monopoly：Choice/Item 调用链

### 触发入口

回合阶段触发道具选择：

- `Manager/TurnManager/Turn/TurnStart.lua` 调用 `ItemPhase.run(..., "pre_action", ...)`。
- `Manager/TurnManager/Turn/TurnRoll.lua` 调用 `ItemPhase.run(..., "pre_move", ...)`。
- `Manager/TurnManager/Turn/TurnPost.lua` 调用 `ItemPhase.run(..., "post_action", ...)`。

道具在其它流程触发选择：

- `Manager/ItemManager/Item/ItemSteal.lua` 的 `Steal.handle_pass_players(...)` 在经过玩家时返回 `{ waiting = true, intent = { kind = "need_choice", ... } }`。
- `Manager/ItemManager/Item/ItemDemolish.lua` 的 `Demolish.use(...)` 在非 AI 使用时返回 demolish 目标选择。

### Choice 生成与派发

`Manager/ItemManager/Item/ItemPhase.lua` 会根据背包与时机生成 `item_phase_choice`：

- `ItemPhase.build_choice_spec(...)` 过滤可用道具，生成 `choice_spec`（kind=`item_phase_choice`），并在可丢弃时追加 `discard_item` 选项。
- `ItemPhase.run(...)` 调用 `IntentDispatcher.dispatch(game, { kind = "need_choice", choice_spec = spec })`。
- `Library/Monopoly/IntentDispatcher.lua` 负责写入 `game.store`：递增 `turn.choice_seq`，设置 `turn.pending_choice`，并广播 `need_choice` 事件。

### UI 展示与输入回传

- `Manager/System/Runtime.lua` 监听 `IntentDispatcher.on("need_choice", ...)`，将 `pending_choice` 绑定到 runtime，并调用 `RuntimeUI.open_choice_modal`。
- `Manager/System/GUI/RuntimeUI.lua` 转交给 `Manager/TurnManager/GUI/MainView.open_choice_modal` 渲染。
- `Manager/TurnManager/GUI/UIEventRouter.lua` 监听 UI 按钮，点击后调用 `RuntimeLoop.dispatch_action`。
- `Manager/System/GUI/RuntimeLoop.lua` 特殊处理 `item_slot_N`：仅在 `choice.kind == "item_phase_choice"` 时，将道具槽映射为 `choice_select` 并回传到游戏。

### Choice 解析与道具执行

- `Manager/System/GUI/RuntimeLoop.lua` 将 `choice_select/choice_cancel` 交给 `game:dispatch_action`。
- `Manager/TurnManager/Turn/TurnManager.lua` 在 `wait_choice` 状态通过 `ChoiceService.resolve(...)` 处理。
- `Manager/ChoiceManager/Choice/ChoiceService.lua` 将 `choice.kind` 映射到 `ChoiceRegistry`，并调用 `ItemChoiceHandler`。

`item_phase_choice` 的处理逻辑在 `Manager/ChoiceManager/Choice/ChoiceHandlers/ItemChoiceHandler.lua`：

- 选择 `discard_item`：打开 `discard_item` 子选择，并在丢弃完成后重新打开 `item_phase_choice`。
- 选择具体道具：调用 `ChoiceService.use_item` → `ItemExecutor.use_item(...)`。

`ItemExecutor` 与 `ItemRegistry` 决定是否需要后续选择：

- `Manager/ItemManager/Item/ItemExecutor.lua`：优先查 `ItemRegistry`，否则直接消耗并走 `ItemPostEffects.apply_post`。
- `Manager/ItemManager/Item/ItemRegistry.lua` 的 `run_item_choice_flow(...)` 生成目标选择：
  - `item_target_player`（目标玩家）
  - `remote_dice_value`（遥控骰子点数）
  - `roadblock_target`（路障位置）
  - `demolish_target`（怪兽/导弹目标）

### Choice 子流程（道具目标）

以下 choice 由 `ItemChoiceHandler` 继续处理并回到道具逻辑：

- `item_target_player` → `use_item` 传入 `target_id`，触发 `ItemPostEffects` 的定向效果。
- `remote_dice_value` → `RemoteDice.apply(...)`。
- `roadblock_target` → `Roadblock.apply(...)`。
- `demolish_target` → `Demolish.apply(...)`。
- `steal_prompt` → 打开 `steal_item` 选择；`steal_item` → `Steal.steal_item_at_index(...)`。
- `discard_item` → `Inventory.remove_by_index(...)`，结束后重开道具阶段。

当子流程结束时会调用 `finish_choice` 与 `finish_item_phase` 清理：

- `ChoiceService.finish_choice` 清除 `turn.pending_choice`。
- `ItemPhase.finish` 设置 `turn.item_phase.<phase>.done = true` 并清理 `turn.item_phase_active`。

### 自动与兜底决策

- `Manager/GameManager/Agent.lua` 的 `auto_action_for_choice` 为 AI 或超时兜底生成 `choice_select/choice_cancel`。
- `Manager/System/GUI/RuntimeLoop.lua` 的 `step_choice_timeout` 会在超时后触发自动选择。

