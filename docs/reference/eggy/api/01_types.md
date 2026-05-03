---
kind: reference
status: stable
owner: eggy-vendor
last_verified: 2026-05-04
---
# 基础类型

---@class Vector3
---@field x Fixed
---@field y Fixed
---@field z Fixed
---@field pitch Fixed
---@field yaw Fixed
---@operator add(Vector3): Vector3
---@operator sub(Vector3): Vector3
---@operator mul(Vector3): Vector3
---@operator div(Vector3): Vector3
---@operator unm: Vector3
---@operator add(Fixed): Vector3
---@operator sub(Fixed): Vector3
---@operator mul(Fixed): Vector3
---@operator div(Fixed): Vector3
Vector3 = {}

---向量设置pitch/yaw
---@param pitch Fixed
---@param yaw Fixed

---@class Quaternion
---@field x Fixed
---@field y Fixed
---@field z Fixed
---@field w Fixed
---@field yaw Fixed 注意: 由于历史原因，在2025.10.30维护前的游戏版本中，Lua中math库默认欧拉角的旋转顺序为：pitch->yaw->roll（即XYZ顺序），而编辑器内显示的角度为roll->pitch->yaw（即ZXY顺序）。为了避免不同顺序引起的混乱，我们将于2025.10.30维护后，将Lua中math库的默认欧拉角旋转顺序调整至与编辑器内一致。此次更改只影响维护后新创建的地图，您无需修改已经创建或发布的地图。但是如果需要将旧地图的代码迁移到新地图，请留意此处的更改。
---@field pitch Fixed 注意: 由于历史原因，在2025.10.30维护前的游戏版本中，Lua中math库默认欧拉角的旋转顺序为：pitch->yaw->roll（即XYZ顺序），而编辑器内显示的角度为roll->pitch->yaw（即ZXY顺序）。为了避免不同顺序引起的混乱，我们将于2025.10.30维护后，将Lua中math库的默认欧拉角旋转顺序调整至与编辑器内一致。此次更改只影响维护后新创建的地图，您无需修改已经创建或发布的地图。但是如果需要将旧地图的代码迁移到新地图，请留意此处的更改。
---@field roll Fixed 注意: 由于历史原因，在2025.10.30维护前的游戏版本中，Lua中math库默认欧拉角的旋转顺序为：pitch->yaw->roll（即XYZ顺序），而编辑器内显示的角度为roll->pitch->yaw（即ZXY顺序）。为了避免不同顺序引起的混乱，我们将于2025.10.30维护后，将Lua中math库的默认欧拉角旋转顺序调整至与编辑器内一致。此次更改只影响维护后新创建的地图，您无需修改已经创建或发布的地图。但是如果需要将旧地图的代码迁移到新地图，请留意此处的更改。
---@field euler Vector3 注意: 由于历史原因，在2025.10.30维护前的游戏版本中，Lua中math库默认欧拉角的旋转顺序为：pitch->yaw->roll（即XYZ顺序），而编辑器内显示的角度为roll->pitch->yaw（即ZXY顺序）。为了避免不同顺序引起的混乱，我们将于2025.10.30维护后，将Lua中math库的默认欧拉角旋转顺序调整至与编辑器内一致。此次更改只影响维护后新创建的地图，您无需修改已经创建或发布的地图。但是如果需要将旧地图的代码迁移到新地图，请留意此处的更改。
---@operator mul(Vector3): Vector3
---@operator mul(Quaternion): Quaternion
Quaternion = {}

---四元数求逆

---@class dict
---@overload fun(): dict
dict = {}

---设置健值
---@param key any
---@param value any

---@class (partial) math
---@field pi Fixed
---@field e Fixed
---@field maxval Fixed
---@field minval Fixed
---@field zero Fixed
---@field one Fixed
---@field neg_one Fixed

---转换为整数
---@param x Fixed
---@return integer

## 方法清单

Vector3|set_pitch_yaw|pitch, yaw
Vector3|length
Vector3|getUnit
Vector3|getAbsoluteVector
Vector3|normalize
Vector3|dot|rhs
Vector3|cross|rhs
Quaternion|inverse
Quaternion|apply|v
dict|set|key, value
dict|get|key
dict|keyvalues
dict|keys
dict|values
math|tointeger|x
math|toreal|x
math|tofixed|x
math|isfinite|x
math|sin|x
math|cos|x
math|tan|x
math|asin|x
math|acos|x
math|atan|x
math|atan2|y, x
math|sqrt|x
math|log|x
math|log2|x
math|log10|x
math|log1p|x
math|exp|x
math|exp2|x
math|fmod|x, y
math|pow|x, y
math|round|x
math|ceil|x
math|floor|x
math|trunc|x
math|min|a, b
math|max|a, b
math|abs|a
math|fabs|x
math|clamp|x, min, max
math|equal001|a, b
math|rad_to_deg|rad
math|deg_to_rad|deg
math|Vector3|x, y, z
math|Quaternion|pitch, yaw, roll

## 其他类型

- Damage
- Decoration: Unit
- JointAssistant: JointAssistantComp, Unit
- Timer
- UnitGroup: Unit
- Vehicle: Unit, VehicleComp
- Enums
- GlobalAPI
- Ability: Actor, AttrComp, KVBase, TriggerSystem
- AbilityComp
- Actor: KVBase, TriggerSystem
- AttrComp
- BuffStateComp
- Camp: AttrComp, KVBase
- Character: LifeEntity
- CharacterComp
- Creature: LifeEntity, OwnerComp
- CustomTriggerSpace: ExprDeviceComp, OwnerComp, SceneUI, Unit, UnitInteractVolumeComp
- DebugAPI
- DisplayComp
- Equipment: KVBase, OwnerComp, TriggerSystem
- EquipmentComp
- ExprDeviceComp
- GameAPI
- GoodsInfo
- ItemBox: DisplayComp, ExprDeviceComp, SceneUI
- JointAssistantComp
- JumpComp
- KVBase
- LevelComp
- LifeComp
- LifeEntity: AbilityComp, AttrComp, BuffStateComp, CharacterComp, DisplayComp, EquipmentComp, JumpComp, LevelComp, LifeComp, LiftComp, LiftedComp, ModifierComp, MoveStatusComp, RollComp, RushComp, SceneUI, Unit, UnitInteractVolumeComp
- LiftComp
- LiftedComp
- LuaAPI
- Modifier: Actor
- ModifierComp
- MoveStatusComp
- Obstacle: DisplayComp, ExprDeviceComp, LiftedComp, OwnerComp, SceneUI, Unit, UnitInteractVolumeComp
- OwnerComp
- Role: AttrComp, KVBase
- RollComp
- RushComp
- SceneUI
- TriggerSpace: ExprDeviceComp, OwnerComp, SceneUI, Unit, UnitInteractVolumeComp
- TriggerSystem
- Unit: Actor
- UnitInteractVolumeComp
- VehicleComp
- VirtualEquipment
