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

**示例**：
```lua
life_entity.add_state(Enums.BuffState.BUFF_FORBID_MOVE)
```

---

### BuffStateComp.add_state(state_id)

添加状态（包含禁止移动/操作等）。

**参数**：
- `state_id`：`Enums.BuffState`

**示例**：
```lua
life_entity.add_state(Enums.BuffState.BUFF_FORBID_CONTROL)
```

---

### BuffStateComp.remove_state(state_id)

移除指定状态。

**参数**：
- `state_id`：`Enums.BuffState`

**示例**：
```lua
life_entity.remove_state(Enums.BuffState.BUFF_FORBID_MOVE)
```

---

### BuffStateComp.clear_state(state_id)

清除指定状态（同类接口，不依赖是否已添加）。

**参数**：
- `state_id`：`Enums.BuffState`

**示例**：
```lua
life_entity.clear_state(Enums.BuffState.BUFF_FORBID_CONTROL)
```

---

### BuffStateComp.get_state_count(state_id)

获取状态计数（用于叠加判断）。

**参数**：
- `state_id`：`Enums.BuffState`

**返回值**：`integer`

**示例**：
```lua
if life_entity.get_state_count(Enums.BuffState.BUFF_FORBID_MOVE) > 0 then
    print("当前禁止移动")
end
```

---

### BuffStateComp.get_state_list()

获取当前状态列表。

**返回值**：`Enums.BuffState[]`

**示例**：
```lua
local list = life_entity.get_state_list()
for _, state_id in ipairs(list) do
    print(state_id)
end
```

---

### Character.start_move_to_pos(target_pos, duration)

角色向目标点移动。

**参数**：
- `target_pos`：`Vector3` - 目标坐标
- `duration`：`Fixed` - 移动时间

**示例**：
```lua
local target = math.Vector3(100, 0, 50)
character.start_move_to_pos(target, 2.0)
```

---

### Character.cmd_move_to_pos(target_pos, duration)

命令角色移动到目标点（带指令语义）。

**参数**：
- `target_pos`：`Vector3` - 目标坐标
- `duration`：`Fixed` - 移动时间

**示例**：
```lua
character.cmd_move_to_pos(math.Vector3(0, 0, 0), 1.5)
```

---

### Character.start_forced_move(vel, duration, enable_phy)

角色强制移动（速度向量）。

**参数**：
- `vel`：`Vector3` - 速度向量
- `duration`：`Fixed` - 持续时间
- `enable_phy`：`boolean` - 是否启用物理影响

**示例**：
```lua
character.start_forced_move(math.Vector3(5, 0, 0), 0.8, true)
```

---

### Character.stop_forced_move()

停止强制移动。

**示例**：
```lua
character.stop_forced_move()
```

---

### Character.set_aim_move_enabled(enable)

启用或关闭瞄准移动模式。

**参数**：
- `enable`：`boolean`

**示例**：
```lua
character.set_aim_move_enabled(true)
```

---

### LifeEntity.ai_command_*（AI 移动指令）

面向具备 AI 的生命体移动指令集合。

**常用指令**：
- `ai_command_start_move(direction, t)`
- `ai_command_start_move_high_priority(target_position, duration, threshold)`
- `ai_command_stop_move(duration)`
- `ai_command_follow(target_unit, follow_dis, tolerate_dis, reject_time, move_mode)`
- `ai_command_nav(waypoint, reject_time, round_mode, move_mode)`
- `ai_command_patrol(waypoint, reject_time, round_mode, move_mode)`
- `ai_command_alert(target_pos, target_dir, delay_time, reject_time, move_mode)`

**示例**：
```lua
local dir = math.Vector3(1, 0, 0)
life_entity.ai_command_start_move(dir, 1.0)

life_entity.ai_command_follow(target_unit, 300, 50, 3.0, Enums.MoveMode)
```

---

### LifeEntity.start_move_by_direction(direction, duration)

按方向移动（非 AI 指令）。

**参数**：
- `direction`：`Vector3` - 移动方向
- `duration`：`Fixed` - 持续时间

**示例**：
```lua
life_entity.start_move_by_direction(math.Vector3(0, 0, 1), 0.5)
```

---

### LifeEntity.start_move_to_pos_with_threshold(target_pos, duration, threshold)

移动到目标点，带距离阈值。

**参数**：
- `target_pos`：`Vector3`
- `duration`：`Fixed`
- `threshold`：`Fixed` - 判定到达阈值

**示例**：
```lua
life_entity.start_move_to_pos_with_threshold(math.Vector3(10, 0, 10), 3.0, 0.5)
```

---

### Unit.get_position() / Unit.set_position(pos)

读取/设置单位坐标。

**参数**：
- `pos`：`Vector3`

**示例**：
```lua
local pos = unit.get_position()
unit.set_position(pos + math.Vector3(0, 0, 2))
```

---

### Unit.ai_command_*（单位层 AI 指令）

与 `LifeEntity.ai_command_*` 类似，常用于泛型 Unit。

**示例**：
```lua
unit.ai_command_nav(waypoint, 2.0, round_mode, Enums.MoveMode)
```

---

## Vehicle

### Unit.vehicle_start_move(direction, duration) / Unit.vehicle_stop_move()

单位作为载具时的移动控制接口。

**示例**：
```lua
unit.vehicle_start_move(math.Vector3(1, 0, 0), 1.2)
unit.vehicle_stop_move()
```

---

### VehicleComp.start_move_by_direction(direction, duration)

车辆组件按方向移动。

**参数**：
- `direction`：`Vector3` - 移动方向
- `duration`：`Fixed` - 持续时间

**示例**：
```lua
vehicle_comp.start_move_by_direction(math.Vector3(1, 0, 0), 1.2)
```

---

### VehicleComp.stop_move()

停止车辆移动。

**示例**：
```lua
vehicle_comp.stop_move()
```

---

### VehicleComp.reset()

重置车辆组件状态。

**示例**：
```lua
vehicle_comp.reset()
```

---

### LifeEntity.try_exit_vehicle()

生命体尝试退出载具。

**示例**：
```lua
life_entity.try_exit_vehicle()
```

---

### Character.try_exit_vehicle() / Character.try_exit_ugcvehicle()

角色尝试退出载具（UGC 载具接口保留）。

**示例**：
```lua
character.try_exit_vehicle()
character.try_exit_ugcvehicle()
```

---

### AbilityComp.set_ability_enabled_on_vehicle(enable)

设置载具状态下技能可用性。

**参数**：
- `enable`：`boolean`

**示例**：
```lua
life_entity.set_ability_enabled_on_vehicle(false)
```

---

### MoveStatusComp.is_fling_status() / is_lost_control_status()

移动状态查询（被击飞/失控）。

**示例**：
```lua
if life_entity.is_lost_control_status() then
    print("当前处于失控状态")
end
```

---

### MoveStatusComp.start_face_lock_target(target_unit, time)

锁定面向目标单位一段时间。

**参数**：
- `target_unit`：`Unit`
- `time`：`Fixed`

**示例**：
```lua
life_entity.start_face_lock_target(target_unit, 1.0)
```

---

### MoveStatusComp.stop_face_lock_target()

取消面向锁定。

**示例**：
```lua
life_entity.stop_face_lock_target()
```

---

## 事件

### EVENT.SPEC_LIFEENTITY_MOVE_BEGIN

指定生命体移动开始事件。

**注册**：
```lua
LuaAPI.unit_register_trigger_event(
    life_entity,
    {EVENT.SPEC_LIFEENTITY_MOVE_BEGIN},
    function(event_name, actor, data)
        -- actor: 事件主体（LifeEntity）
    end
)
```

---

### EVENT.SPEC_LIFEENTITY_MOVE_END

指定生命体移动结束事件。

**注册**：
```lua
LuaAPI.unit_register_trigger_event(
    life_entity,
    {EVENT.SPEC_LIFEENTITY_MOVE_END},
    function(event_name, actor, data)
        -- actor: 事件主体（LifeEntity）
    end
)
```

---

## 常用流程

### 完整使用流程

1. **确定目标位置**：使用 `Vector3` 组装目标点或方向
2. **选择移动方式**：直接移动、强制移动或 AI 指令
3. **监听移动事件**：在需要时监听开始/结束回调
4. **查询移动状态**：处理失控或击飞等特殊状态

### 完整示例

```lua
-- 1. 指定目标点
local target = math.Vector3(15, 0, 8)

-- 2. 移动
character.start_move_to_pos(target, 2.0)

-- 3. 监听移动开始/结束
LuaAPI.unit_register_trigger_event(character, {EVENT.SPEC_LIFEENTITY_MOVE_BEGIN}, function()
    print("开始移动")
end)
LuaAPI.unit_register_trigger_event(character, {EVENT.SPEC_LIFEENTITY_MOVE_END}, function()
    print("结束移动")
end)

-- 4. 兜底处理失控
if character.is_lost_control_status() then
    character.stop_forced_move()
end
```

---

## 注意事项

1. **坐标类型一致**：位移相关接口统一使用 `Vector3`
2. **AI 移动模式**：`ai_command_*` 需要配合 `Enums.MoveMode`，不要传入空值
3. **强制移动**：`start_forced_move` 会覆盖部分角色控制逻辑，结束后记得 `stop_forced_move`
4. **事件主体**：移动事件以指定生命体作为事件主体，不是全局事件

---

## 相关文档

- `docs/eggy/api/07_unit_entities.md`
- `docs/eggy/api/08_components.md`
- `docs/eggy/api/09_events.md`
