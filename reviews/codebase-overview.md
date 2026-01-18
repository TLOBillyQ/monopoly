# 代码库综览

**日期**: 2026-01-18
**范围**: `src/` 与 `tests/`

---

## 一、总纲

此库分三层：

- **core**: 领域对象与状态容器。
- **gameplay**: 规则流程、服务、效果与选择。
- **adapters**: Love2D 展示与输入。

装配唯有一处：`src/gameplay/composition_root.lua`。诸服务与阶段皆由此组装注入，`src/game.lua` 为运行时门面。

---

## 二、主流程

一局之驱动在 `src/gameplay/turn_manager.lua`。

1. `Game:advance_turn()` 调用 `TurnManager:run_turn()`。
2. `TurnManager` 以 `Flow` 轮转诸阶段：`start` -> `roll` -> `move` -> `landing` -> `post_action` -> `end_turn`。
3. 若需玩家选择，则入 `wait_choice`，待 `dispatch_action` 继续。

阶段实现散见 `src/gameplay/turn_*.lua`。

---

## 三、效果系统

效果定义与执行已拆。

- **定义**: `src/config/landing_effects.lua`、`src/config/land_effects.lua`。
- **执行器**: `src/gameplay/landing.lua`、`src/gameplay/land.lua`，以 `executors` 映射实现 `can_apply/apply`。
- **管线**: `src/gameplay/effect.lua` 负责 `scan/execute`，`src/gameplay/effect_pipeline.lua` 负责序列与可选效果选择。

`turn_land` 以 `EffectPipeline.run` 处理落点逻辑。

---

## 四、Choice 与意图

Choice 以 `IntentDispatcher` 推送。

- `src/util/intent_dispatcher.lua`：派发 `need_choice` 与 `push_popup`。
- `src/gameplay/choice_service.lua`：注册式 handler 表，解 `choice.kind`。
- `src/gameplay/choice_handlers/*`：分场景处理。

Love2D UI 订阅 `need_choice` 事件，在 `src/adapters/love2d/love_layer.lua` 即时弹窗。

---

## 五、服务层

服务皆为纯模块，注入于 `game.services`。

- `movement_service.lua`：移动与遇到事件。
- `market_service.lua`：黑市购买。
- `bankruptcy_service.lua`：破产淘汰。
- `choice_service.lua`：选择解析。

依赖方向受 `tests/deps_check.lua` 约束。

---

## 六、玩家与道具

玩家本体在 `src/core/player.lua`，并由装配时注入：

- 载具相关：`src/gameplay/player_vehicle.lua`
- 场景效果：`src/gameplay/player_effects.lua`

道具执行主在 `src/gameplay/item_executor.lua`，其后效/策略/目标拆分于 `item_post_effects.lua`、`item_strategy.lua` 等。

---

## 七、UI 适配

Love2D 层自 `main.lua` 入口。

- `love_layer.lua`: UI 状态与事件。
- `love_runtime.lua`: 与 Love 生命周期接合。
- `presenter.lua`: 由 store 生成视图。

UI 不直依 gameplay，皆经 `Game` 与 `IntentDispatcher`。

---

## 八、测试

- `tests/regression.lua`: 回归集。
- `tests/deps_check.lua`: 依赖规则校验。

建议常行：

```
luac -p
lua tests/deps_check.lua
lua tests/regression.lua
```

---

## 九、关键文件速览

- `src/gameplay/composition_root.lua`: 唯一装配点。
- `src/gameplay/turn_manager.lua`: 回合流程。
- `src/gameplay/effect.lua`: 效果执行入口。
- `src/gameplay/choice_service.lua`: choice 中枢。
- `src/game.lua`: 运行时门面。

---

## 十、运行路径一例

1. `main.lua` 建 `LoveLayer`。
2. `LoveLayer` 调 `Game.new`。
3. `CompositionRoot.assemble` 组装。
4. `TurnManager` 推进回合。
5. 若需选择，`IntentDispatcher` 推送 UI。
6. UI 产生 `dispatch_action`，回到 `TurnManager`。

---

## 结语

此库结构清分、依赖收束，主干清晰：**装配一处、流程一线、选择一门、效果一管**。欲改动，应先观 `composition_root.lua` 与 `turn_manager.lua`，再循 effect 与 choice 之链。
