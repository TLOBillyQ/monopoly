# 载具（Vehicle）API 用法文档

本文档介绍 Eggy 平台的载具相关接口，涵盖载具移动、退出载具、以及载具状态下的技能控制。

---

## 核心类型

### Vector3
- **类型**：`{x: Fixed, y: Fixed, z: Fixed, pitch: Fixed, yaw: Fixed}`
- **说明**：三维坐标与方向向量，常用于载具移动方向

---

## API 说明

### VehicleComp.start_move_by_direction(direction, duration)

车辆组件按方向移动。

**参数**：
- `direction`：`Vector3` - 移动方向
- `duration`：`Fixed` - 持续时间

---

### VehicleComp.stop_move()

停止车辆移动。

---

### VehicleComp.reset()

重置车辆组件状态。

---

### LifeEntity.try_exit_vehicle()

生命体尝试退出载具。

---

### Character.try_exit_vehicle()

角色尝试退出载具。

---

### AbilityComp.set_ability_enabled_on_vehicle(enable)

设置载具状态下技能可用性。

**参数**：
- `enable`：`boolean`

---

## 注意事项

1. **移动方向**：`start_move_by_direction` 使用 `Vector3` 方向向量
2. **退出载具**：`try_exit_vehicle` 由生命体/角色触发
3. **技能限制**：载具状态建议显式设置技能可用性

---

## 组合示例

目标：启动载具移动，限制技能使用；到达时停止并尝试下车。

```lua
-- 前置：vehicle_comp, life_entity 可用
local direction = math.Vector3(1, 0, 0)
vehicle_comp.start_move_by_direction(direction, 1.2)
life_entity.set_ability_enabled_on_vehicle(false)

LuaAPI.call_delay_time(1.2, function()
    vehicle_comp.stop_move()
    life_entity.try_exit_vehicle()
end)
```

---

## 相关文档

- `docs/eggy/movement_api.md`
- `docs/eggy/api/07_unit_entities.md`
- `docs/eggy/api/08_components.md`
