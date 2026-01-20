# src/adapters/eggy/ 实现路线图（基于公开检索与仓库研究）

> 目标：在不改规则层的前提下，用蛋仔 PC 编辑器的事件与 UI 节点替换 Love2D 适配层，最终形成 `src/adapters/eggy/`。

## 公开检索结论（截至 2026-01-20）

- 工坊手册 PC 端概述页明确：Eggitor 是蛋仔派对地图编辑器的 PC 版本，手册用于 PC 端地图创作上手，并说明后续会持续补充内容。
- 工坊手册 PC 端安装推荐配置页已公开：Windows 10 x64 起、Intel Core i3-6100 或更好、8GB 内存或更好、GeForce GTX 750 Ti 或更好。
- 手册导航列出 “Lua” 章节，但公开页面未见 Lua API 细节；适配实现仍需依赖编辑器内模板工程与仓库内 `eggitor` 模板资料（已在 `docs/eggy/eggy-capability-matrix.zh-CN.md` 归档）。

公开来源（可用入口，URL 放在代码块中）：

```text
https://h5.nie.netease.com/eggy/editor-docs-hope/pc/overview.html
https://h5.nie.netease.com/eggy/editor-docs-hope/pc/installation.html
```

## 依赖资料（仓库内）

- `docs/eggy/eggy-migration-roadmap.zh-CN.md`
- `docs/eggy/eggy-capability-matrix.zh-CN.md`
- `src/adapters/love2d/*`（现有适配层实现）

## 适配层边界（硬约束）

- 规则层不动：`src/gameplay/*`、`src/core/*`、`src/config/*`。
- 适配层只负责：事件桥接、UI 节点刷新、输入映射、存档读写、必要的自动化（auto/timeout）。
- 现有规则层契约沿用：`game.ui_port` + `dispatch_action`。

## 目录与职责（最小改造版）

> 复用现有实现，避免新增抽象；缺 2 个真实调用点不新增 helper。

- `src/adapters/eggy/eggy_layer.lua`
  - 负责：game 生命周期、action 分发、pending_choice 处理、auto_runner 接入。
  - 直接复用 `LoveLayer` 的逻辑结构，只替换 UI/事件入口。
- `src/adapters/eggy/eggy_runtime.lua`
  - 负责：Eggy 事件绑定（GAME_INIT/TICK/UI_CUSTOM_EVENT 等）。
  - 等价 `love_runtime.lua` 的“入口挂载”。
- `src/adapters/eggy/ui_state.lua`
  - 负责：UI 节点名/ID 映射、必要的缓存句柄。
  - 不承载复杂布局计算（布局由编辑器 UI 决定）。
- `src/adapters/eggy/presenter.lua`
  - 可直接复用 `src/adapters/love2d/presenter.lua`（纯数据整理）。
- 其余 Love2D 渲染文件（`board_renderer/panel_renderer/modal/layout`）在 Eggy 侧由 UI 节点刷新替代。

## Action 协议（沿用既有）

沿用 `LoveLayer:dispatch_action` 的语义：

- `ui_button`：`next/auto/restart`。
- `modal_button` / `modal_confirm`：弹窗按钮/确认。
- `choice_select` / `choice_cancel`：选择流程。
- `key`：可选（仅在 Eggy 支持键盘事件时保留）。

> 该协议在 Eggy 层不新增字段；只做事件映射。

## 路线图（阶段交付）

### 阶段 0（P0）能力核对与最小脚手架

目标：能在 Eggy 中运行 `new_game()` 并定时推进，不依赖 UI 绘制。

- 绑定入口与 tick：`GAME_INIT` / `set_tick_handler` 或 `REPEAT_TIMEOUT`。
- 初始化 `game_factory`、`ui_state`、`auto_runner`。
- 仅日志输出：当前玩家名、现金、回合数（确认规则层可用）。

交付物：
- `eggy_runtime.lua`（事件绑定）
- `eggy_layer.lua`（最小可运行）
- 日志验证脚本

### 阶段 1（P0）规则层契约固化 + choice 流程

目标：完整跑通 action/choice 机制，不做任何美术表现。

- `IntentDispatcher.on("need_choice")` -> 触发 Eggy UI 弹窗。
- `pending_choice` 超时（复用 `constants.action_timeout_seconds` 逻辑）。
- `dispatch_action` 对 `choice_select/choice_cancel` 的透传。

交付物：
- action 列表 + payload 示例（同步到文档）
- 最小“弹窗 UI 节点”驱动（标题/正文/按钮）

### 阶段 2（P0）UI 面板与按钮（替换 panel_renderer）

目标：可用 UI 面板替代 Love2D 面板，且交互一致。

- 绑定按钮节点：`btn_next/btn_auto/btn_restart`。
- 刷新文本节点：当前玩家、现金、阶段、回合、骰子、事件日志。
- 自动/暂停状态反映到按钮样式（可用节点显隐或颜色）。

交付物：
- UI 节点命名表
- `refresh_panel(view)` 单入口刷新函数

### 阶段 3（P1）棋盘与格子信息（替换 board_renderer）

目标：棋盘信息可视化，支持选中格子查看细节。

- 棋盘用 UI 节点网格或图片节点表达（避免 3D 单位）。
- 选中格子：UI_CUSTOM_EVENT → `ui_tile_select` action。
- 同步显示格子详情（价格/等级/归属/路障/地雷）。

交付物：
- UI 节点命名表（tile_x_y / tile_idx）
- `refresh_board(view)`

### 阶段 4（P1）输入映射与回放一致性

目标：所有输入都收口为 action，确保可回放。

- UI 事件统一转 action（按钮/格子/弹窗）。
- 不在 UI 事件里直接改 game；只调 `dispatch_action`。

交付物：
- 事件 → action 映射表

### 阶段 5（P1）存档与继续游戏

目标：编辑器内可一键继续上次游戏。

- `Role.get_archive_by_type` / `Role.set_archive_by_type` 保存 store 快照或 actions。
- UI 显示“继续/重开”。

交付物：
- 存档结构定义（版本号 + data）
- 恢复流程

### 阶段 6（P2）3D 表现与特效

目标：规则稳定后再接入 3D 表现。

- 角色/棋盘 3D 单位、相机、音效。
- 不改变规则层逻辑，仅增加表现。

交付物：
- 3D 单位创建销毁 + 动画映射表

## 验收标准（每阶段）

- 同 seed + 同 action 序列 -> 结果一致（现金/地块/胜者）。
- 进入 `pending_choice` 时不推进回合；选择后推进。
- UI 节点与 store 状态一致，可从存档恢复。

## 风险与缺口

- 公开文档缺失：Lua API 具体字段与事件参数需在编辑器内实测确认。
- UI_CUSTOM_EVENT 的 payload 结构需要在 Eggy UI 工程里验证并固化。

