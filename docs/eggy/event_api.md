# 事件（Event）API 用法文档

本文档提供事件系统的最小用法说明，具体事件清单见 `docs/eggy/api/09_events.md`。

---

## 核心概念

- **事件常量**：统一在 `EVENT.*` 中定义。
- **事件主体**：事件触发的主体对象（如 Ability、LifeEntity、Global）。
- **注册方式**：按“全局事件 / 指定单位事件”两类注册。

---

## 注册接口

### LuaAPI.global_register_trigger_event(event_desc, callback)

注册全局事件。

**参数**：
- `event_desc`：`table` - 事件描述，形如 `{EVENT.Xxx, ...}`，可附带注册参数
- `callback`：`function(event_name, actor, data)` - 事件回调

---

### LuaAPI.unit_register_trigger_event(unit, event_desc, callback)

注册指定单位事件。

**参数**：
- `unit`：`Unit` - 目标单位
- `event_desc`：`table` - 事件描述，形如 `{EVENT.Xxx, ...}`，可附带注册参数
- `callback`：`function(event_name, actor, data)` - 事件回调

---

## 回调参数约定

- `event_name`：`string` - 事件名称
- `actor`：事件主体（随事件不同而变化）
- `data`：事件数据表（字段见事件清单）

---

## 常见事件类型

- **技能/战斗类**：Ability、伤害、击中、施法流程等
- **移动/状态类**：移动开始/结束、失控等
- **角色/阵营类**：玩家状态、阵营变化、胜负等
- **交互/物件类**：触发区域、物品、互动等
- **UI/系统类**：UI 自定义事件、计时器超时等

---

## 组合示例

目标：监听指定角色购买商品事件，并在 UI 提示。

```lua
LuaAPI.global_register_trigger_event(
    {EVENT.SPEC_ROLE_PURCHASE_GOODS, role},
    function(event_name, actor, data)
        GlobalAPI.show_tips("购买成功: " .. data.goods_id, 3.0)
    end
)
```

---

## 相关文档

- `docs/eggy/api/09_events.md`
- `docs/eggy/api/06_lua_api.md`
