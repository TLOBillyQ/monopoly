# Eggy Lua · Agent Memory（Codex 精简规则版）

用途：作为 **Codex / Coding Agent 的长期记忆（agent memory）**。  
目标：在 Eggy（蛋仔编辑器）环境下，生成**不会踩运行时坑**的 Lua 代码。

---

## 核心前提（不可违背）

- **入口文件固定：`main.lua`**
- **所有 API 调用只能用 `.`，禁止使用 `:`**
- **角度单位 = 弧度（rad）**
- **需要浮点数时必须显式写成 `x.y`（如 `2.0`）**
- **UI 只能在初始化完成后创建（用延迟 / 事件 / 触发器）**
- **Lua 只能操作“关闭组件性能优化”的单位**
- **逻辑帧率固定 30 FPS**

---

## API 使用模型（非常重要）

### 全局 API（可直接调用）

- `LuaAPI`
- `GameAPI`
- `GlobalAPI`

### 单位 API（必须先拿对象）

规则只有一句话：

> **先获取单位对象，再调用 API**

```lua
local role = GameAPI.get_role(1)
role.get_name()   -- 正确
```

❌ 禁止：

```lua
Role.get_name()
```

---

## 单位获取方式优先级

1. **实体 ID（最稳定）**

```lua
local unit = GameAPI.get_unit(123456)
```

1. 名称查询（仅在命名唯一时）

```lua
local unit = LuaAPI.query_unit("地砖0")
```

1. 链式获取（从已有单位）

```lua
local ctrl = GameAPI.get_role(1).get_ctrl_unit()
```

---

## 延迟 / 定时

- **30 帧 = 1 秒**
- 可按帧或按秒（秒允许小数）

```lua
LuaAPI.call_delay_frame(30, cb)
LuaAPI.call_delay_time(1.0, cb)
```

---

## 事件系统（通信首选）

### 全局自定义事件

```lua
local id = LuaAPI.global_register_custom_event("evt", function(_, _, data)
  -- data 是 table，业务参数在这里
end)

LuaAPI.global_send_custom_event("evt", {"payload"})
LuaAPI.global_unregister_custom_event(id)
```

⚠️ 蛋码触发时，`data` 可能需要用字符串索引：`data["1"]`

---

## 触发器（监听游戏行为）

- **单位触发器**：绑定到某个单位
- **全局触发器**：监听全局事件

```lua
LuaAPI.unit_register_trigger_event(unit, { EVENT.XXX }, cb)
LuaAPI.global_register_trigger_event({ EVENT.XXX }, cb)
```

事件枚举统一来自 `EggyAPI.lua`。

---

## `_id` 与 `_key`

- `_id`：已有实体的唯一 ID（用于操作）
- `_key`：预设 / 模板 ID（用于生成）

⚠️ **不要凭空硬编码 `_key`**  
→ 当作外部配置输入。

---

## 调试原则

- `print()`：只给开发者看
- `GlobalAPI.show_tips(text, 2.0)`：强烈推荐用于逻辑验证
- 发布后 **不能** 动态执行新 Lua

---

## Codex 自检清单（生成前默读）

- [ ] 所有 API 是否都用 `.`
- [ ] 所有浮点参数是否写成 `x.y`
- [ ] 是否避免直接调用不存在的全局表
- [ ] 是否确认单位关闭了组件性能优化
- [ ] 是否 UI 逻辑延后执行
- [ ] 是否避免依赖非唯一名称

---

## 需求不完整时的默认行为

当以下信息缺失时，只生成**框架代码**，不写死逻辑：

- 实体 ID / 预设 key
- 事件枚举
- UI 初始化时机

---

（End · Agent Memory）
