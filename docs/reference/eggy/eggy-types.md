---
kind: contract
status: stable
owner: agents
last_verified: 2026-05-06
---
# Eggy Type Mapping

Eggy 引擎的 Lua API 使用特定类型映射，写值时必须注意子类型：

- `Fixed` —— 对应引擎 `Fix32`，Lua 端必须用 **浮点数字面量** (`30.0`)。
  Lua 的 `integer` 子类型（5.3+，如 `30`）会被引擎拒绝。

  错误示例：`set_camera_property(7, 30)` → 报错：expected Fix32, got int
  正确示例：`set_camera_property(7, 30.0)`

  影响 API：`math.Vector3/Quaternion` 所有分量、`set_camera_property` 第 2 参数等。

- `CameraPropertyType` —— 枚举值，整数正确（如 `CAMERA_PROP_DIST = 7`）。
  注意与上面 `Fixed` 区分：第 1 参数是 enum int，第 2 参数是 Fixed float。

- `math` 库 —— Eggy 沙盒里的 `math` 是 **Fixed-based 改造版**，
  **没有标准 Lua 5.3+ 的整数常量**（`math.maxinteger`/`math.mininteger`/`math.huge`）。
  写出来在宿主 Lua（busted）能跑，但 Eggy 运行时取到的是 `nil`，
  传到下游做比较就会抛 `attempt to compare nil with integer`。

  Eggy `math` 实际提供：`pi/e/maxval/minval/zero/one/neg_one`（都是 Fixed），
  以及 `tointeger/tofixed/sin/cos/.../min/max/abs/clamp` 等函数（参数皆 Fixed）。
  完整签名见 `meta/luals_host.lua` 的 `---@class math`。

  错误示例：`number_utils.clamp(value, 1, math.maxinteger)` → max=nil 抛错
  正确示例：上限本就无意义就别写，`return value < 1 and 1 or value`

  影响：任何使用 `math.maxinteger` / `math.mininteger` / `math.huge`
  作为"无意义上下限"哨兵值的代码，统统在 Eggy 运行时崩。

- `role.set_image_color` —— 引擎层 API 注解参数类型是 `EImage`，
  对非 EImage 节点（典型如 `EButton`）运行时**静默拒绝**，
  pcall 完全看不到错误。调用看似成功，但视觉无任何变化。

  UIManager wrapper 路径 `button_node.image_color = X` 也走不通——
  `EButton` 无 `__set_image_color` setter（对比 `vendor/third_party/UIManager/EButton.lua`
  与 `EImage.lua`），ClassUtils 的 `__newindex` 直接 rawset 成普通字段，根本不进引擎。

  错误示例：`pcall(role.set_image_color, role, button_node, 0x808080, 0)` 是 no-op
  正确示例：想给 EButton 整体着色没有现成路径，按需选其一——
    - 只改文字色：`role.set_button_text_color(button_node, color)`
    - 整体换图（需美术配合）：备两套资源，
      用 `set_button_normal_image` / `set_button_pressed_image` 切图
    - 借用 disabled 视觉：`set_button_enabled(false)` 会自动变灰，
      但同时阻断点击（见 `EButton.lua:28` `__update_disabled` 双 API 实现）

  影响：任何想给 EButton 做 active/inactive 高亮、hover 反馈、状态着色的代码，
  走 `set_image_color` 都是 no-op。见 commit `5a3864d`（Revert `75b74bf` 黑市 tab 高亮）。
