# 创建（Create）API 用法文档

本文档汇总 `GameAPI` 中所有创建类接口，按对象类型归类，便于检索。

---

## 场景与单位

### GameAPI.create_life_entity(unit_key, pos, rotation, scale_ratio, role)

创建生命体。

**参数**：
- `_unit_key`
- `_pos`
- `_rotation`
- `_scale_ratio`
- `_role`

**返回值**：未注明

---

### GameAPI.create_creature_fixed_scale(unit_key, pos, rotation, scale_ratio, role)

创建固定缩放的生物。

**参数**：
- `_u_key`
- `_pos`
- `_rotation`
- `_scale_ratio`
- `_role`

**返回值**：未注明

---

### GameAPI.create_obstacle(unit_key, pos, rotation, scale, role)

创建障碍物。

**参数**：
- `_u_key`
- `_pos`
- `_rotation`
- `_scale`
- `_role`

**返回值**：未注明

---

### GameAPI.create_obstacle_from_geometry(unit_key, pos, rotation, scale, role, geometry_path)

通过几何资源创建障碍物。

**参数**：
- `_u_key`
- `_pos`
- `_rotation`
- `_scale`
- `_role`
- `_geometry_path`

**返回值**：未注明

---

### GameAPI.create_decoration(unit_key, pos, rotation, scale, parent)

创建装饰物。

**参数**：
- `_u_key`
- `_pos`
- `_rotation`
- `_scale`
- `_parent`

**返回值**：未注明

---

### GameAPI.create_unit_with_scale(unit_key, pos, rotation, scale)

创建单位并设置缩放。

**参数**：
- `_u_key`
- `_pos`
- `_rotation`
- `_scale`

**返回值**：未注明

---

### GameAPI.create_unit_group(unit_group_id, pos, root_quaternion, role)

创建单位组。

**参数**：
- `_unit_group_id`
- `_pos`
- `_root_quaternion`
- `_role`

**返回值**：未注明

---

## 触发与交互

### GameAPI.create_triggerspace(unit_key, pos, rotation, scale, role)

创建触发区域。

**参数**：
- `_u_key`
- `_pos`
- `_rotation`
- `_scale`
- `_role`

**返回值**：未注明

---

### GameAPI.create_customtriggerspace(unit_key, pos, rotation, scale, role)

创建自定义触发区域。

**参数**：
- `_u_key`
- `_pos`
- `_rotation`
- `_scale`
- `_role`

**返回值**：未注明

---

## UI 与特效

### GameAPI.create_scene_ui_at_point(layer_key, pos, duration)

在指定位置创建场景 UI。

**参数**：
- `_layer_key`
- `_pos`
- `_duration`

**返回值**：未注明

---

### GameAPI.create_sfx_with_socket(sfx_key, unit, socket_name, scale, duration, bind_type)

在单位挂点创建特效。

**参数**：
- `_sfx_key`
- `_unit`
- `_socket_name`
- `_scale`
- `_duration`
- `_bind_type`

**返回值**：未注明

---

### GameAPI.create_sfx_with_socket_offset(sfx_key, unit, socket_name, offset, rot, scale, duration, bind_type)

在单位挂点创建带偏移的特效。

**参数**：
- `_sfx_key`
- `_unit`
- `_socket_name`
- `_offset`
- `_rot`
- `_scale`
- `_duration`
- `_bind_type`

**返回值**：未注明

---

## 物品与组件

### GameAPI.create_equipment(equipment_eid, pos)

创建装备/道具实例。

**参数**：
- `_equipment_eid`
- `_pos`

**返回值**：未注明

---

### GameAPI.create_joint_assistant(unit_key, unit1, unit2)

创建关节辅助对象。

**参数**：
- `_unit_key`
- `_unit1`
- `_unit2`

**返回值**：未注明

---

## 环境与数据

### GameAPI.create_constant_wind_field(pos, wind_type, wind_range, duration)

创建恒定风场。

**参数**：
- `_pos`
- `_wind_type`
- `_wind_range`
- `_duration`

**返回值**：未注明

---

### GameAPI.create_sheet

创建数据表。

**参数**：无

**返回值**：未注明

---

## 相关文档

- `docs/eggy/api/05_game_api.md`
