# Lua 高级特性

## 并行计算（辅助线程）
- 适用：耗时的纯计算（AI、寻路、战场模拟等），避免占用主逻辑帧。
- 线程数：1~3 个；`LuaAPI.dispatch_init(n)` 只能调用一次，建议放在 `main.lua` 开始处。
- 从虚拟机与主虚拟机隔离：默认不共享数据/状态。
- 限制：从虚拟机不能调用游戏 API；可用内置库与数学库；不支持开发者模式；可存在多个从虚拟机；数据传递仅支持表/字符串/数字及其组合，不支持单位。

### 关键 API
- `LuaAPI.dispatch_queue(vmIndex, funcName, {params...})`：派发异步调用；参数必须打包成表。
- `LuaAPI.dispatch_flush()`：执行队列里的异步调用；未手动调用时，下一帧开始前会自动触发。
- `LuaAPI.dispatch_sync()`：等待全部异步完成并返回结果列表，顺序与派发顺序一致；每项为 `{ok, valueOrErr}`。
- 代码加载：`LuaAPI.dispatch_queue(vmIndex, "require", {"module"})`。

### 使用建议
- 避免频繁传递大而复杂的数据。
- 任务尽量均匀分散到多个线程。
- 任务不要切得过细，每帧建议控制在 20 个左右。
- 常见节奏：帧尾派发多次调用，下一帧开始时同步结果。

## 运行时创建可变形组件
- 目的：在运行时动态生成可变形组件（曲线/曲面、多边形环、圆台、方块等）。
- 两步：
  1) `GameAPI.register_geometry_*()` 注册几何体形状并返回几何体 ID（仅描述形状，不创建组件）。
  2) `GameAPI.create_obstacle_from_geometry(presetId, position, rotation, scale, owner, geometryId)` 创建组件。
- 预设 ID 用于继承皮肤/物理等配置；示例 ID 需替换为你的预设。

### register_geometry_spline 说明
- 形式：`GameAPI.register_geometry_spline(isCurve, positions, normals, radius, distPrecision, anglePrecision, thickness, extra)`
- `isCurve=true` 表示曲线，`false` 表示曲面；曲面需要 `thickness`。
- 返回字符串形式的几何体 ID。

### 其他几何类型
- `GameAPI.register_geometry_ring(...)`
- `GameAPI.register_geometry_frustum(...)`
- `GameAPI.register_geometry_box(...)`
- 具体参数以 API 文档为准。
