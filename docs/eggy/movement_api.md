# 移动（Movement）API 用法文档

本文档介绍 Eggy 平台的角色/单位移动相关接口，涵盖主动移动、强制移动、AI 移动指令、移动状态查询与移动事件监听。

---

## 核心类型

### Vector3
- **类型**：`{x: Fixed, y: Fixed, z: Fixed, pitch: Fixed, yaw: Fixed}`
- **说明**：三维坐标与朝向，常用于移动目标点与方向

### Enums.MoveMode
- **类型**：`Enums.MoveMode`
- **说明**：AI 移动模式枚举（具体取值见 `docs/eggy/api/03_enums.md`）

---

## API 说明

### Enums.BuffState（移动相关状态）

用于限制移动或操作的状态枚举，常与 `BuffStateComp` 配合使用。

**常用项**：
- `BUFF_FORBID_MOVE`：禁止移动
- `BUFF_FORBID_CONTROL`：禁止所有操作
- `BUFF_FORBID_RUSH`：禁止前扑
- `BUFF_FORBID_ROLL`：禁止滚动
- `BUFF_FORBID_JUMP`：禁止跳跃
- `BUFF_FORBID_UNCONTROL`：无视失控

---

### BuffStateComp.add_state(state_id)

添加状态（包含禁止移动/操作等）。

**参数**：
- `state_id`：`Enums.BuffState`

---

### BuffStateComp.remove_state(state_id)

移除指定状态。

**参数**：
- `state_id`：`Enums.BuffState`

---

### BuffStateComp.clear_state(state_id)

清除指定状态（同类接口，不依赖是否已添加）。

**参数**：
- `state_id`：`Enums.BuffState`

---

### BuffStateComp.get_state_count(state_id)

获取状态计数（用于叠加判断）。

**参数**：
- `state_id`：`Enums.BuffState`

**返回值**：`integer`

---

### BuffStateComp.get_state_list()

获取当前状态列表。

**返回值**：`Enums.BuffState[]`

---

### Character.start_move_to_pos(target_pos, duration)

角色向目标点移动。

**参数**：
- `target_pos`：`Vector3` - 目标坐标
- `duration`：`Fixed` - 移动时间

---

### CharacterComp.start_forced_move(vel, duration, enable_phy)

角色组件强制移动（速度向量）。

**参数**：
- `vel`：`Vector3` - 速度向量
- `duration`：`Fixed` - 持续时间
- `enable_phy`：`boolean` - 是否启用物理影响

---

### CharacterComp.stop_forced_move()

停止强制移动。

---

### Character.set_aim_move_enabled(enable)

启用或关闭瞄准移动模式。

**参数**：
- `enable`：`boolean`

---

### LifeEntity.ai_command_*（AI 移动指令）

面向具备 AI 的生命体移动指令集合。

**常用指令**：
- `ai_command_start_move(direction, t)`
- `ai_command_start_move_high_priority(target_position, duration, threshold)`
- `ai_command_stop_move(duration)`
- `ai_command_follow(target_unit, follow_dis, tolerate_dis, reject_time, move_mode)`
- `ai_command_patrol(waypoint, reject_time, round_mode, move_mode)`
- `ai_command_alert(target_pos, target_dir, delay_time, reject_time, move_mode)`

---

### LifeEntity.start_move_by_direction(direction, duration)

按方向移动（非 AI 指令）。

**参数**：
- `direction`：`Vector3` - 移动方向
- `duration`：`Fixed` - 持续时间

---

### LifeEntity.start_move_to_pos_with_threshold(target_pos, duration, threshold)

移动到目标点，带距离阈值。

**参数**：
- `target_pos`：`Vector3`
- `duration`：`Fixed`
- `threshold`：`Fixed` - 判定到达阈值

---

### Unit.get_position() / Unit.set_position(pos)

读取/设置单位坐标。

**参数**：
- `pos`：`Vector3`

---

## Vehicle

载具相关接口已独立到 `docs/eggy/vehicle_api.md`。

---

### MoveStatusComp.is_fling_status() / is_lost_control_status()

移动状态查询（被击飞/失控）。

---

### MoveStatusComp.start_face_lock_target(target_unit, time)

锁定面向目标单位一段时间。

**参数**：
- `target_unit`：`Unit`
- `time`：`Fixed`

---

### MoveStatusComp.stop_face_lock_target()

取消面向锁定。

---

## 事件

### EVENT.SPEC_LIFEENTITY_MOVE_BEGIN

指定生命体移动开始事件。

---

### EVENT.SPEC_LIFEENTITY_MOVE_END

指定生命体移动结束事件。

---

## 注意事项

1. **坐标类型一致**：位移相关接口统一使用 `Vector3`
2. **AI 移动模式**：`ai_command_*` 需要配合 `Enums.MoveMode`，不要传入空值
3. **强制移动**：`start_forced_move` 会覆盖部分角色控制逻辑，结束后记得 `stop_forced_move`
4. **事件主体**：移动事件以指定生命体作为事件主体，不是全局事件

---

## 组合示例

目标：AI 追随目标一段时间，期间监控失控状态；必要时强制停止并锁定面向。

```lua
-- 前置：life_entity, target_unit, character_comp 可用
local follow_dis = 300
local tolerate_dis = 50
local reject_time = 3.0
local move_mode = Enums.MoveMode

life_entity.ai_command_follow(target_unit, follow_dis, tolerate_dis, reject_time, move_mode)

LuaAPI.unit_register_trigger_event(
    life_entity,
    {EVENT.SPEC_LIFEENTITY_MOVE_BEGIN},
    function()
        if life_entity.is_lost_control_status() then
            character_comp.stop_forced_move()
            life_entity.stop_face_lock_target()
        else
            life_entity.start_face_lock_target(target_unit, 1.0)
        end
    end
)
```

---

## 相关文档

- `docs/eggy/api/07_unit_entities.md`
- `docs/eggy/api/08_components.md`
- `docs/eggy/api/09_events.md`
