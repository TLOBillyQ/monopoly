# 蛋仔 PC 编辑器 Lua 能力矩阵

> 迁移前确认基础能力：入口/定时/UI/存档/音效

## 结论

- ✅ Lua 入口：EVENT.GAME_INIT
- ✅ Tick：LuaAPI.set_tick_handler
- ✅ 定时器：EVENT.TIMEOUT / EVENT.REPEAT_TIMEOUT
- ✅ UI：节点查询/属性/自定义事件
- ✅ 日志：LuaAPI.log / GlobalAPI.debug|warning|error
- ✅ 存档：Role.get_archive_by_type / Role.set_archive_by_type
- ✅ 音频：GameAPI.play_sfx_by_key / GameAPI.play_3d_sound

---

## 能力矩阵

| 能力 | API/事件 | 仓库证据 | 迁移影响 |
|---|---|---|---|
| **入口** | EVENT.GAME_INIT | ggitor/main.lua | 初始化游戏/UI/seed/存档 |
| **Tick** | LuaAPI.set_tick_handler(pre, post) | ggitor/main.lua | 每帧刷新 UI / 推进逻辑 |
| **定时器** | EVENT.TIMEOUT / REPEAT_TIMEOUT | ggitor/MonsterManager.lua | 替代 dt 累计，做轮询 |
| **UI 查询** | LuaAPI.query_ui_node(s) | ggitor/EggyAPI.lua + Stage0Demo.lua | 按名称获取节点句柄 |
| **UI 属性** | Role.set_button_text / set_label_text / set_label_color / set_node_visible / set_ui_opacity / set_node_touch_enabled / show_tips | ggitor/EggyAPI.lua + MonsterManager.lua | 节点驱动替换即时绘制 |
| **UI 事件** | EVENT.UI_CUSTOM_EVENT | ggitor/EggyAPI.lua + Stage0Demo.lua | UI → action 事件入口 |
| **日志** | LuaAPI.log / GlobalAPI.debug\|warning\|error | ggitor/EggyAPI.lua | 排查输入/状态/存档 |
| **存档** | Role.get/set_archive_by_type + Enums.ArchiveType.* | ggitor/EggyAPI.lua + Stage0Demo.lua | 实现"继续上次游戏" |
| **音效** | GameAPI.play_sfx_by_key / play_3d_sound / stop_sound | ggitor/EggyAPI.lua + Stage0Demo.lua | UI/结算/事件音效 |

---

## 参考示例

- 入口 + tick：ggitor/main.lua
- 定时器：ggitor/MonsterManager.lua
- UI 节点 ID：ggitor/Data/UINodes.lua
- 综合演示（日志/UI/存档/音效）：ggitor/Stage0Demo.lua

---

## 验证步骤（在蛋仔编辑器内）

1. 使用官方模板入口 ggitor/main.lua（默认调用 Stage0Demo.install()）
2. 进图后观察：
   - 日志出现 [Stage0Demo] GAME_INIT
   - UI "倒计时" Label 每秒刷新为 Stage0: Ns
   - 存档：二次进入时 stage0_runs 计数递增
   - UI 事件：配置 event_name=stage0_demo 后点击触发日志

---

## 实测待确认清单

- [ ] EVENT.GAME_INIT 触发次数与时机（重载/重新开始是否重复触发）
- [ ] set_tick_handler 频率与是否允许多次设置
- [ ] TIMEOUT/REPEAT_TIMEOUT 精度/最大数量/取消方式
- [ ] query_ui_node(s) 的 name 匹配规则（节点名/路径/别名）
- [ ] UI_CUSTOM_EVENT 从 UI 按钮配置触发方式 + data 结构
- [ ] 存档 key 大小限制/总容量/覆盖策略
- [ ] play_sfx_by_key 资源 key 配置与打包方式
