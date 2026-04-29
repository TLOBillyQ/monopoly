# Eggy Lua · Agent Memory

**用途**：Coding Agent 长期记忆，避免在 Eggy 编辑器环境踩运行时坑。

---

## 核心约束

- 入口文件固定：`main.lua`
- 所有 API 调用只能用 `.`，禁止 `:`
- 角度单位 = 弧度（rad）
- 浮点数必须显式写 `x.y`（如 `2.0`）
- UI 只能在初始化完成后创建（延迟 / 事件 / 触发器）
- Lua 只能操作关闭了「组件性能优化」的单位
- 逻辑帧率固定 30 FPS（30 帧 = 1 秒）

---

## API 模型

**全局 API**（直接调用）：`LuaAPI` / `GameAPI` / `GlobalAPI`

**单位 API**：先获取对象，再调用

```lua
local role = GameAPI.get_role(1)
role.get_name()   -- ✅
Role.get_name()   -- ❌
```

**单位获取优先级**：
1. 实体 ID：`GameAPI.get_unit(123456)`
2. 名称（仅唯一时）：`LuaAPI.query_unit("地砖0")`
3. 链式：`GameAPI.get_role(1).get_ctrl_unit()`

---

## 延迟 / 定时

```lua
LuaAPI.call_delay_frame(30, cb)   -- 按帧
LuaAPI.call_delay_time(1.0, cb)   -- 按秒
```

---

## 事件系统

```lua
local id = LuaAPI.global_register_custom_event("evt", function(_, _, data) end)
LuaAPI.global_send_custom_event("evt", {"payload"})
LuaAPI.global_unregister_custom_event(id)
```

⚠️ 蛋码触发时 `data` 可能需字符串索引：`data["1"]`

---

## 触发器

```lua
LuaAPI.unit_register_trigger_event(unit, { EVENT.XXX }, cb)   -- 单位触发器
LuaAPI.global_register_trigger_event({ EVENT.XXX }, cb)        -- 全局触发器
```

事件枚举来自 `EggyAPI.lua`。

---

## 杂项

- `_id`：已有实体 ID（操作用）；`_key`：预设/模板 ID（生成用），不要硬编码
- 调试：`print()` 给开发者；`GlobalAPI.show_tips(text, 2.0)` 推荐用于逻辑验证
- 发布后不能动态执行新 Lua

---

## 历史命名变迁

- 行动日志屏（玩家可见事件流）的代码侧 API 已从 `debug_*` 改名为 `event_log_*`：`src/ui/ports/event_log.lua`、`src/ui/ctl/event_log_view.lua`，方法 `set_event_log / set_event_log_visible / sync_event_log / resolve_event_log_enabled`。Eggy 画布节点名 `base_contract.action_log.label` 与角色面板 `调试屏` 因资源约束保留旧名，**但代码不再用 debug 命名**。
- `logger.event / logger.event_no_tips / logger.push/pop/flush_event_buffer / logger.get_text_by_level` 已退役。玩家可见事件改走 `src/rules/ports/event_feed.lua` 的 `event_feed.publish(game, event)`，事件落 `state.event_log`，并按 `event.tip` 自动飘字。`logger.info / logger.warn` 仅保留 dev 诊断职责，release 构建（`startup_policy.is_release`）下整体静默。

---

## 生成前自检

- [ ] 所有 API 用 `.` 而非 `:`
- [ ] 浮点参数写成 `x.y`
- [ ] 单位已关闭组件性能优化
- [ ] UI 逻辑已延后执行
- [ ] 未依赖非唯一名称
- [ ] 缺实体 ID / 预设 key / 事件枚举时，只生成框架代码
