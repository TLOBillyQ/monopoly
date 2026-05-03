---
kind: contract
status: stable
owner: agents
last_verified: 2026-05-04
---
# Eggy Type Mapping

Eggy 引擎的 Lua API 使用特定类型映射，写值时必须注意子类型：

- `Fixed` —— 对应引擎 `Fix32`，Lua 端必须用 **浮点数字面量** (`30.0`)。
  Lua 5.5 的 `integer` 子类型（如 `30`）会被引擎拒绝。

  错误示例：`set_camera_property(7, 30)` → 报错：expected Fix32, got int
  正确示例：`set_camera_property(7, 30.0)`

  影响 API：`math.Vector3/Quaternion` 所有分量、`set_camera_property` 第 2 参数等。

- `CameraPropertyType` —— 枚举值，整数正确（如 `CAMERA_PROP_DIST = 7`）。
  注意与上面 `Fixed` 区分：第 1 参数是 enum int，第 2 参数是 Fixed float。
