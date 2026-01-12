# 蛋仔大富翁（开发者指引）

> 里程碑 M1 聚焦“代码清理与可维护性”，不改玩法。

## 快速开始
- 依赖：Love2D 11.x，Lua 5.4（随 Love 安装即可）。
- 运行：在项目根目录执行 `love .`。
- 入口：`main.lua` 会创建游戏实例并挂载 `src/ui/love_layer.lua`。

## 主要模块
- `src/app.lua`：游戏状态容器，持有玩家、棋盘、回合管理，并注入 `game.services`（tile/chance/movement/item/market/status/bankruptcy）。
- `src/core/*`：核心数据结构（Board/Tile/Player/Dice 等）。
- `src/gameplay/*`：规则与流程
  - `services/*`：Movement/Tile/Item/Chance/Status/Market/Turn 等服务（依赖注入，不直接触达 UI）。
  - `turn/*`：状态机阶段（start/roll/move/land/end），`flow.lua`/`choice_resolver.lua`/`land_resolver.lua`。
  - `effects/*`：规则定义（如 land_effects）。
  - `store.lua` + `sync.lua`：集中式状态与同步。
- `src/visual/*`：Love 渲染层
  - `love_layer.lua`（主循环/输入），`layout.lua`（尺寸布局），`ui_state.lua`（主题/字体），
  - `board_renderer.lua`（棋盘/建筑/覆盖物/玩家），`panel_renderer.lua`（信息面板/日志），`modal.lua`（弹窗），`auto_runner.lua`（自动模式）。

## 质量与自检（M1 基线）
- 启动无报错：`love .` 应正常进入游戏。
- 手动回归（关键路径）
  - 掷骰移动，经过/停留起点奖励。
  - 路障/地雷放置与触发：覆盖物可见，触发有日志/弹窗，自动运行暂停在弹窗。
  - 建筑展示：拥有地块的建筑堆叠在格子外侧，等级文字可见。
- 道具交互：偷窃/均富/流放/查税/请神/送神/穷神需弹窗选择目标；偷窃可二级选择道具；怪兽/导弹卡弹窗选择目标格子后才生效。
- 代码风格：保持 ASCII、简短注释；按现有分层放置 UI 代码，不新增全局变量。
- 脚本自检：`lua scripts/regression.lua`（纯 Lua，小型回归：经过起点、路障停留、怪兽卡/导弹卡、地块可选行动等待/自动购买）。

## 常用命令
- 运行：`love .`
- 搜索：`rg <pattern>`（推荐全局搜索）。

## 后续里程碑（摘要）
- M2：补完未实现道具（怪兽/导弹等）。
- M3：美术与交互打磨（动画、主题、多语言）。
- M4：AI/策略和平衡优化。
