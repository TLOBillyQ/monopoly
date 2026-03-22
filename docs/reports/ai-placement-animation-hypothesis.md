# AI placement 动画假设

## 现象

- 同格 placement 后，AI 位置正确。
- 玩家移动动画能停。
- AI 跑步动画可能持续。
- AI 发生碰撞后能恢复 idle。

## 最佳猜测

- 根因是宿主时序不一致：
  - synthetic AI 的移动状态未完全结束；
  - placement 同帧执行 stop + `set_position()`；
  - 宿主稍后才处理 move/contact 状态更新。
- 结果：
  - 玩家链路：`start_move_by_direction()`
  - AI 链路：`force_start_move()`
  - placement 先停再立刻 snap
  - 宿主可能还没完成 `MOVE_END`
  - 后续碰撞/contact 把状态机纠回 idle

## 为什么符合现象

- 位置正确，说明游戏逻辑没问题。
- 只有动画残留，问题更像宿主移动/动画状态。
- 碰撞后恢复 idle，说明宿主后续事件能修正状态。
- `stop_anim()` 更像停显示层动画，不一定停 locomotion 状态。

## 相关代码

- synthetic AI 启动：`src/host/eggy/synthetic_actor_registry.lua:140`
- AI 移动：`src/ui/render/move_anim.lua:458`
- 玩家移动：`src/ui/render/move_anim.lua:463`
- placement 里 stop 后立即放置：`src/ui/render/board/placement.lua:176`
- stop 路径：`src/ui/render/move_anim.lua:295`, `src/ui/render/move_anim.lua:325`

## 相关文档

- `Creature.force_start_move` / `Creature.force_stop_move`：`docs/eggy/api/07_unit_entities.md:98`
- `LifeEntity.ai_command_stop_move`：`docs/eggy/api/07_unit_entities.md:187`
- `LifeEntity.start_ai` / `LifeEntity.stop_ai`：`docs/eggy/api/07_unit_entities.md:226`
- `LifeEntity` move begin/end：`docs/eggy/api/09_events.md:1153`
- `LifeEntity` contact begin/end：`docs/eggy/api/09_events.md:885`
- `DisplayComp.stop_anim`：`docs/eggy/api/08_components.md:66`

## 解释

- 宿主至少有三层：
  - 移动命令层
  - AI 状态层
  - 显示动画层
- placement 试图同时停这三层。
- 对 synthetic AI，`set_position()` 执行时，宿主可能仍处在 `MOVE_BEGIN` 到 `MOVE_END` 之间。
- 因此位置已更新，但视觉仍在跑步；直到 contact 或后续宿主事件刷新状态。

## 快速验证

1. 在 snap 前注册 `SPEC_LIFEENTITY_MOVE_BEGIN/MOVE_END`，确认 placement 是否发生在 `MOVE_END` 前。
2. stop 后延迟一帧再 `set_position()`，比较 idle 是否稳定恢复。
3. 对比：
   - `force_stop_move()`
   - `force_stop_move() + stop_ai()`
   - `force_stop_move() + delayed set_position()`

## 结论

- 最可能是宿主时序 / 状态机问题，不是游戏逻辑问题。
