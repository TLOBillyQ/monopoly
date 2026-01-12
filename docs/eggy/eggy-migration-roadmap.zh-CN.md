# Love2D → 蛋仔派对 PC 编辑器（保留 Lua）迁移路线图

## 目标

- 保留现有 **Lua 规则层**（`src/app.lua`、`src/gameplay/*`、`src/core/*`、`src/config/*`）。
- 将 Love2D 相关代码替换为 **蛋仔 PC 编辑器的事件 + UI 节点驱动**。
- 迁移过程中优先保证 **规则一致性/可回放**，其次再做 3D 表现与特效。

## 现状盘点（基于仓库）

- Love2D 调用主要集中在 `src/visual/*`：
  - 主循环与输入：`src/visual/love_layer.lua`
  - 即时绘制 UI：`src/visual/modal.lua`、`src/visual/board_renderer.lua`、`src/visual/panel_renderer.lua`
  - 尺寸布局：`src/visual/layout.lua`
  - 字体加载：`src/visual/ui_state.lua`
- 规则层已具备较好的分离度（参见 `docs/architecture-review.zh-CN.md`）。

## 总体策略（关键决策）

- **不建议“移植 love.graphics 画图 API”** 到蛋仔：蛋仔侧更适合用 UI 预制与节点属性更新。
- 迁移拆成两层：
  - `game/`（规则）：继续沿用现有 `src/gameplay/*`，尽量不改。
  - `visual/`（表现）：在蛋仔侧基本等同“重写一个新前端”，但复用现有 action/choice 流程。

## 阶段 0：蛋仔侧能力确认（P0）

要确认并记录到同一份对接文档里（避免走到一半卡死）：

- Lua 入口：是否有等价 `GAME_INIT` 的初始化事件；脚本加载方式（是否必须 `LuaAPI.require`）。
- Tick/定时器：是否支持周期事件（手册里有 `TIMEOUT/REPEAT_TIMEOUT`）。
- UI：
  - 节点查询：`LuaAPI.query_ui_node` / `LuaAPI.query_ui_nodes`
  - 节点属性：`Role.set_button_text`、`Role.set_label_color`、`Role.set_node_visible`、`Role.set_ui_opacity`、`Role.set_node_touch_enabled`、`Role.show_tips`
  - UI 事件：`UI_CUSTOM_EVENT`（按钮点击等如何上报到 Lua）
- 日志：`LuaAPI.log` / `GlobalAPI.debug|warning|error`
- 存档：`Role.get_archive_by_type` / `Role.set_archive_by_type`
- 音频/特效：`GameAPI.play_sfx_by_key`、`GameAPI.play_3d_sound`、`GameAPI.stop_sound` 等

交付物：

- 一页“能力矩阵 + 是否可用 + 限制/配额 + 示例代码链接”：`docs/eggy-capability-matrix.zh-CN.md`。

## 阶段 1：冻结“规则层契约”（P0）

目标：让“规则推进”只依赖 **action**，不依赖渲染与输入设备。

利用你现有的结构：

- 继续以 `LoveLayer:dispatch_action(...)` 的 action 形式作为“输入统一入口”（例如 `ui_button`、`modal_button`、`choice_select`、`choice_cancel`）。
- 继续使用 `game.ui_hooks` 作为“规则层 → UI 的请求端口”（你在 `src/visual/love_layer.lua` 里已绑定 `push_popup/request_choice`）。

交付物：

- 一份“action 列表 + payload 结构”的小协议文档（以现有代码为准）。

## 阶段 2：蛋仔版入口与 Tick（替换 love.load/update）（P0）

目标：让游戏在蛋仔里能“启动 → 每帧/定时推进 → 退出”，先不做棋盘绘制。

对接建议（对应你当前 LoveLayer 的生命周期）：

- `love.load()` → `GAME_INIT`：创建 game、初始化 UI、初始化存档/seed、布局计算。
- `love.update(dt)` → `REPEAT_TIMEOUT`（或等价 tick）：调用 `sync_pending_choice_modal`、处理自动行动、刷新 UI 节点。
- `love.event.quit()` → `GAME_END` 或编辑器提供的结束逻辑。

交付物：

- 蛋仔工程里一个最小脚本：能跑 `new_game()`，能 tick，能在 UI 上显示当前玩家名字/现金。

## 阶段 3：UI 前端重写（替换 love.draw + renderers）（P1）

目标：把“即时绘制 UI”改成“UI 节点驱动”，并保持交互语义一致。

拆解为三块（对应现有代码）：

- 面板信息（`src/visual/panel_renderer.lua`）：把文本输出迁到 Label 节点；把按钮状态迁到 Button 节点（文本/可点/高亮）。
- 弹窗（`src/visual/modal.lua`）：用一组弹窗节点（标题/正文/按钮容器）表现；点击后转成 `modal_button/modal_confirm` 或直接 `choice_select/choice_cancel`。
- 棋盘（`src/visual/board_renderer.lua`）：第一版建议用“UI 格子节点/图片”表达棋盘，不急着做 3D 单位/相机。

交付物：

- 一套 UI 节点命名约定（例如 `btn_next/btn_auto/btn_restart/lbl_current_player/...`）。
- 一个 “UI 刷新函数”按 game 状态统一刷新（不要分散在很多地方拼字符串）。

## 阶段 4：输入与事件（替换 mousepressed/keypressed）（P1）

目标：把输入全部收口到 action，并且保证可回放/可自动化。

建议：

- UI 按钮点击：统一上报为 `ui_button` action（对应 `LoveLayer:handle_ui_button`）。
- 弹窗按钮：上报为 `modal_button` 或直接上报为 `choice_select/choice_cancel`。
- 键盘快捷键：如果蛋仔支持键盘事件，映射到 `key` action（不支持也可以不要）。

交付物：

- “事件 → action”映射表（写死在文档里，便于排查交互问题）。

## 阶段 5：存档与回放（P1）

目标：从“可玩”到“可维护/可迭代”。

- 存档建议保存 **store 快照** 或 “seed + actions 列表”：
  - 快照更简单；action 回放更适合做版本兼容与回归测试。
- 使用 `Role.get_archive_by_type/set_archive_by_type` 持久化；避免依赖本地文件读写权限。

交付物：

- 一键继续上次游戏（读取存档并恢复）。

## 阶段 6：3D 表现与特效（P2）

在规则与 UI 完全稳定后再做：

- 角色/棋盘 3D 单位创建与销毁：`GameAPI.create_unit_with_scale` / `GameAPI.destroy_unit`
- 相机：`GlobalAPI.set_camera_follow_unit` / `GlobalAPI.set_camera_property`（按回合/动画阶段切镜头）
- 特效/音频：`GameAPI.play_sfx_by_key` / `GameAPI.play_3d_sound`

交付物：

- 回合移动、建造升级、触发事件都有对应的 3D 表现（不改变规则层）。

## 验收标准（每阶段都要可验证）

- **规则一致性**：同 seed + 同 action 序列，应得到相同胜者与关键状态（现金/地块/道具/叠加状态）。
- **选择流程**：需要选择时必须进入 `pending_choice`，未选择不推进回合。
- **UI 可恢复**：任意时刻从存档恢复后，UI 节点展示与内部状态一致。

