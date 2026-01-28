# 镜头（Camera）API 用法文档

本文档介绍 Eggy 平台的镜头控制相关接口，涵盖镜头方向、绑定模式、投影、属性调节、陀螺仪与震动等常用能力。

---

## 核心类型

### Role
- **类型**：`Role`
- **说明**：玩家对象，常见来源为事件回调或 `GameAPI.get_role(RoleID)`

### Vector3
- **类型**：`{x: Fixed, y: Fixed, z: Fixed, pitch: Fixed, yaw: Fixed}`
- **说明**：三维坐标与朝向向量，用于镜头方向、锁定位置等

### Quaternion
- **类型**：`{x: Fixed, y: Fixed, z: Fixed, w: Fixed, pitch: Fixed, yaw: Fixed, roll: Fixed}`
- **说明**：四元数旋转（详细说明见类型文档）

### Enums.CameraBindMode
- **类型**：`Enums.CameraBindMode`
- **说明**：镜头绑定模式枚举（取值见 `docs/eggy/api/03_enums.md`）

### Enums.CameraProjectionType
- **类型**：`Enums.CameraProjectionType`
- **说明**：镜头投影类型枚举（取值见 `docs/eggy/api/03_enums.md`）

### Enums.CameraPropertyType
- **类型**：`Enums.CameraPropertyType`
- **说明**：镜头属性预设枚举（取值见 `docs/eggy/api/03_enums.md`）

### Enums.CameraShakeType
- **类型**：`Enums.CameraShakeType`
- **说明**：镜头震动类型枚举（取值见 `docs/eggy/api/03_enums.md`）

---

## API 说明

### 方向与旋转

#### Role.get_camera_direction()
获取镜头朝向（需要先开启镜头旋转同步）。

**返回值**：`Vector3`

---

#### Role.get_camera_rotation()
获取镜头旋转（需要先开启镜头旋转同步）。

**返回值**：`Quaternion`

---

#### Role.set_camera_rotation_sync_enabled(enabled)
设置是否开启镜头旋转同步。

**参数**：
- `enabled`：`boolean`

---

#### Role.set_camera_rotation_by_direction(target_dir, duration)
将镜头旋转到指定方向。

**参数**：
- `target_dir`：`Vector3`
- `duration`：`Fixed`

---

### 绑定与拖拽

#### Role.set_camera_bind_mode(mode)
设置镜头绑定模式。

**参数**：
- `mode`：`Enums.CameraBindMode`

---

#### Role.set_camera_draggable(draggable)
设置镜头是否可拖拽。

**参数**：
- `draggable`：`boolean`

---

#### Role.set_camera_lock_position(pos)
锁定镜头位置。

**参数**：
- `pos`：`Vector3`

---

### 投影与属性

#### Role.set_camera_projection_type(projection_type)
设置镜头投影类型。

**参数**：
- `projection_type`：`Enums.CameraProjectionType`

---

#### Role.set_camera_property(property, value)
设置镜头属性。

**参数**：
- `property`：`Enums.CameraPropertyType`
- `value`：`Fixed`

---

### 镜头马达

#### Role.pause_camera_motor() / Role.resume_camera_motor() / Role.stop_camera_motor()
暂停/恢复/停止镜头马达。

---

### 震动

#### Role.shake_camera(shake_type, shake_max_amplitude, shake_time, shake_source, shake_frequency, shake_time_decay, shake_effect_scope, shake_undamped_scope, shake_distance_decay)
镜头震动。

**参数**：
- `shake_type`：`Enums.CameraShakeType`
- `shake_max_amplitude`：`Fixed`
- `shake_time`：`Fixed`
- `shake_source`：`Vector3`
- `shake_frequency`：`Fixed`
- `shake_time_decay`：`Fixed`
- `shake_effect_scope`：`Fixed`
- `shake_undamped_scope`：`Fixed`
- `shake_distance_decay`：`Fixed`

---

### 重置与陀螺仪

#### Role.reset_camera(reset_angle, reset_bind, reset_point, reset_prop_pitch)
重置镜头状态。

**参数**：
- `reset_angle`：`boolean` - 是否重置镜头角度
- `reset_bind`：`boolean` - 是否重置绑定模式
- `reset_point`：`boolean` - 是否重置镜头相对焦点的位置
- `reset_prop_pitch`：`boolean` - 是否重置俯仰角范围

---

#### Role.set_camera_gyroscope_control_enabled(is_control)
设置是否开启陀螺仪控制镜头。

**参数**：
- `is_control`：`boolean`

---

## 注意事项

1. **本地玩家调用**：镜头相关接口通常要求在本地玩家 `Role` 上调用
2. **旋转同步**：获取镜头方向/旋转前需先调用 `set_camera_rotation_sync_enabled(true)`
3. **强干预效果**：锁定镜头位置、震动等效果建议限时撤销，避免影响玩家体验

---

## 组合示例

目标：开启旋转同步，短暂锁定镜头并旋转到指定方向后恢复。

```lua
Role.set_camera_rotation_sync_enabled(true)
Role.set_camera_lock_position(math.Vector3(0, 0, 0))
Role.set_camera_rotation_by_direction(math.Vector3(0, 1, 0), 0.5)

LuaAPI.call_delay_time(0.6, function()
    Role.reset_camera(false, false, true, false)
end)
```

---

## 相关文档

- `docs/eggy/role_api.md`
- `docs/eggy/api/03_enums.md`
- `docs/eggy/api/07_unit_entities.md`
- `docs/eggy/api/01_types.md`
