# 蛋仔 PC 编辑器（Lua）能力矩阵（阶段0交付物）

> 目标：在迁移 Love2D → 蛋仔前，先确认“是否有入口/定时/ UI / 存档 / 音效”等基础能力，并给出最小可复用示例。
>
> 本文基于仓库内 `eggitor/` 官方 Lua 模板与 `eggitor/EggyAPI.lua`（legacy API 声明）整理。

## 结论摘要

- Lua 入口：有（`EVENT.GAME_INIT`），模板已使用：`eggitor/main.lua`。
- Tick：有（`LuaAPI.set_tick_handler`），模板已使用：`eggitor/main.lua`。
- 定时器：有（`EVENT.TIMEOUT` / `EVENT.REPEAT_TIMEOUT`），模板已使用：`eggitor/MonsterManager.lua`。
- UI：有（节点查询、节点属性、UI 自定义事件）；节点属性与事件可以直接用于“面板/按钮/弹窗”驱动。
- 日志：有（`LuaAPI.log`、`GlobalAPI.debug|warning|error`）。
- 存档：有（`Role.get_archive_by_type` / `Role.set_archive_by_type`）。
- 音频/特效：有（`GameAPI.play_sfx_by_key` / `GameAPI.play_3d_sound` / `GameAPI.stop_sound` 等）。

## 能力矩阵

| 能力 | API/事件（Eggy） | 仓库内证据 | 迁移影响 | 限制/配额（待实测） |
|---|---|---|---|---|
| Lua 入口（等价 love.load） | `EVENT.GAME_INIT` + `LuaAPI.global_register_trigger_event` | `eggitor/main.lua` | 可在此创建游戏、初始化 UI、初始化 seed/存档 | 触发时机/单局多次触发等需要在编辑器内确认 |
| Tick（等价 love.update） | `LuaAPI.set_tick_handler(pre, post)` | `eggitor/main.lua` | 可做“每帧刷新 UI / 推进自动逻辑” | tick 频率、开销上限、是否可多处设置需要确认 |
| 定时器 | `EVENT.TIMEOUT` / `EVENT.REPEAT_TIMEOUT` | `eggitor/MonsterManager.lua` | 可替代 dt 累计，做 0.1s/1s 轮询等 | 精度、最大并发计时器数量、是否受暂停影响待确认 |
| UI 节点查询 | `LuaAPI.query_ui_node` / `LuaAPI.query_ui_nodes` | `eggitor/EggyAPI.lua`（声明）+ `eggitor/Stage0Demo.lua`（示例） | 可按命名拿节点句柄/ID，用于 UI 刷新 | “name” 是节点名/路径/别名？需要在你的 UI 工程里实测 |
| UI 节点属性 | `Role.set_button_text` / `Role.set_label_text` / `Role.set_label_color` / `Role.set_node_visible` / `Role.set_ui_opacity` / `Role.set_node_touch_enabled` / `Role.show_tips` | `eggitor/EggyAPI.lua`（声明）+ `eggitor/MonsterManager.lua`（set_node_visible） | 用节点驱动替换 Love 即时绘制 | 颜色/透明度单位、过渡时间、是否需要主线程等待确认 |
| UI 事件（按钮点击等） | `EVENT.UI_CUSTOM_EVENT` | `eggitor/EggyAPI.lua`（事件声明）+ `eggitor/Stage0Demo.lua`（示例） | UI → action 的事件入口（阶段4） | UI 侧如何配置触发该 event_name、payload 内容待确认 |
| 日志 | `LuaAPI.log` / `GlobalAPI.debug|warning|error` | `eggitor/EggyAPI.lua`（声明） | 迁移期间必需（排查输入/状态/存档） | 日志长度/频率限制待确认 |
| 存档 | `Role.get_archive_by_type` / `Role.set_archive_by_type` + `Enums.ArchiveType.*` | `eggitor/EggyAPI.lua`（声明）+ `eggitor/Stage0Demo.lua`（示例） | 可实现阶段5的“继续上次游戏” | 单 key 大小限制、总量、覆盖策略待确认 |
| 音效/声音 | `GameAPI.play_sfx_by_key` / `GameAPI.play_3d_sound` / `GameAPI.stop_sound` | `eggitor/EggyAPI.lua`（声明）+ `eggitor/Stage0Demo.lua`（示例，key 需资源） | UI 按钮/结算/事件都可挂音效 | 资源 key 命名/打包方式、同时播放数量上限待确认 |

## 示例代码链接（建议后续都复用这里的调用方式）

- 入口 + tick handler：`eggitor/main.lua`
- 定时器用法：`eggitor/MonsterManager.lua`
- UI 节点 ID 表（插件导出）：`eggitor/Data/UINodes.lua`
- 阶段0综合演示（日志/UI事件/存档/音效）：`eggitor/Stage0Demo.lua`

## 如何验证（在蛋仔 PC 编辑器里）

- 直接使用官方模板入口 `eggitor/main.lua`（已默认调用 `Stage0Demo.install()`）。
- 进图后观察：
	- 日志里应出现 `[Stage0Demo] GAME_INIT`。
	- UI 的“倒计时”Label 文本应每秒刷新为 `Stage0: Ns`（前提：你的 UI 工程包含 `eggitor/Data/UINodes.lua` 里导出的节点）。
	- 存档：同一玩家二次进入时，`stage0_runs` 计数应递增。
	- UI 自定义事件：在 UI 侧配置触发 event_name=`stage0_demo` 后，点击应在日志看到 `UI_CUSTOM_EVENT`。

## 编辑器侧需要你补一次“实测记录”的清单

- `EVENT.GAME_INIT` 触发次数与时机（关卡重载/重新开始是否重复触发）
- `LuaAPI.set_tick_handler` 频率与是否允许多次设置
- `TIMEOUT/REPEAT_TIMEOUT` 精度、最大计时器数量、取消方式
- `query_ui_node/query_ui_nodes` 的 name 匹配规则（节点名/路径/别名）
- `UI_CUSTOM_EVENT` 如何从 UI 按钮配置触发，以及 `data` 结构是否可自定义携带参数
- 存档 key 的大小限制/总容量/覆盖策略
- `play_sfx_by_key` 的资源 key 配置与打包方式
