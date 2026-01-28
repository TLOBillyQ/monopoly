# Lua环境

## 概述
蛋仔的游戏逻辑运行在安全沙盒（SandBox）中，为保证安全与多人状态一致性，Lua 环境做了裁剪与改造。

## 主要变更

### 库的变更

- 移除：`io`、`os`、`package`、`debug`
- 重新实现：`math`（与标准 Lua 差异较大，见下文）
- 支持的全局变量/函数：
  - `_VERSION`、`error`、`assert`、`ipairs`、`pairs`、`next`、`pcall`、`tostring`、`type`、`xpcall`、`select`
  - `require`（仅允许加载 `script` 目录下的其他 Lua 模块）
  - `setmetatable`（不可使用 `__mode` 与 `__gc`）
  - `getmetatable`（仅可获取 table 的 metatable）
  - `traceback`（等价于 `debug.traceback`）
  - `print`

### 语法变更

- 不支持字符串与数字之间的隐式转换
- 普通 table 的键只能是数字或字符串
- 需要其他类型键时，使用 `dict()`

示例：

```lua
local map = dict()
local key = {}
map:set(key, 1234)
assert(map:get(key) == 1234)

for _, kv in ipairs(map:keyvalues()) do
  print("K: " .. tostring(kv[1]) .. " V: " .. tostring(kv[2]))
end

-- keys() / values() 获取键和值列表
```

## 开发者模式
在 PC 编辑器内试玩时可开启开发者模式：

```lua
local success = LuaAPI.enable_developer_mode()
```

### 开发者模式特性

- 内置 LuaSocket 库
- 解除表键类型限制
- 允许使用 `io` 与 `debug` 库

注意：开发者模式仅在 PC 编辑器内试玩时有效；手机版编辑器和发布后的地图中均无效，游戏逻辑不能依赖该模式。

## math 库
蛋仔的 `math` 库与标准 Lua 有明显差异，主要支持整数（integer）与定点数（Fixed）。

### 数值范围

- 定点数范围：`-2147483647.0 ~ 2147483647.0`
- 注意：整数转定点数可能溢出

### 常量

| 名称 | 含义 |
| --- | --- |
| `math.pi` | 圆周率 |
| `math.e` | 自然对数常数 |

### 主要函数

| 函数 | 功能 | 备注 |
| --- | --- | --- |
| `math.tointeger(var)` | 转整数 | 向下取整 |
| `math.tofixed(var)` | 转定点数 |  |
| `math.sin/cos/tan(x)` | 三角函数 | 输入为弧度 |
| `math.asin/acos/atan(v)` | 反三角函数 | 返回弧度 |
| `math.log/log2/log10(x)` | 对数函数 |  |
| `math.exp/exp2(x)` | 指数函数 |  |
| `math.round/ceil/floor/trunc(x)` | 取整函数 |  |
| `math.clamp(x, min, max)` | 范围裁剪 |  |

### 类型 `math.Vector3`
用于三维定点数向量。

| 函数/属性签名 | 参数 | 返回值 | 功能 |
| --- | --- | --- | --- |
| `math.Vector3(x : Fixed, y : Fixed, z : Fixed)` | x/y/z 坐标 | 向量实例 | 构造向量 |
| `vec.x / vec.y / vec.z` | 无 | 分量 | 获取分量 |
| `vec.yaw / vec.pitch` | 无 | 角度 | 只读朝向角 |
| `vec:length()` | 无 | Fixed | 向量长度 |
| `vec:dot(other)` | 另一向量 | Fixed | 点积 |
| `vec:cross(other)` | 另一向量 | Vector3 | 叉积 |
| `vec:normalize()` | 无 | Fixed | 单位化，返回原长度 |
| `+ - * /` |  |  | 常规加减乘除 |

### 类型 `math.Quaternion`
用于旋转的四元数。

| 函数/属性签名 | 参数 | 返回值 | 功能 |
| --- | --- | --- | --- |
| `math.Quaternion(pitch, yaw, roll)` | 欧拉角 | 四元数实例 | 由欧拉角构造 |
| `math.Quaternion(x, y, z, w)` | 分量 | 四元数实例 | 由分量构造 |
| `rot:inverse()` | 无 | 无 | 求逆 |
| `rot:slerp(other, t)` | 另一四元数、插值参数 | 四元数 | 球面插值 |
| `rot.x / rot.y / rot.z / rot.w` | 无 | 分量 | 获取分量 |
| `rot.yaw / rot.pitch / rot.roll` | 无 | 角度 | 只读欧拉角 |
| `+ - *` |  |  | 常规加减乘 |
