# src/ui Clean Code 整治

本可执行计划是活文档。实施过程中必须持续更新"进度"、"意外与发现"、"决策日志"、"结果与复盘"。

遵循 `.agents/PLANS.md` 维护。


## 目的 / 全局视角


`src/ui/` 是游戏的视图层，包含 16 个 Lua 模块。代码审查（`report.md`）发现 19 处 Clean Code 违规，其中 5 项高严重度。本计划的目标是消除这些问题，使 UI 层更易读、更易改、更少重复，同时不改变任何运行时行为。

完成后的可观察结果：运行 `lua .agents/tests/all.lua` 全部通过；用 grep 确认死代码和重复代码已消失；模块公开接口保持不变（调用方无需修改）。


## 进度


- [x] (2026-02-08) M1：删除死代码与未使用符号
- [x] (2026-02-08) M2：合并重复函数，删除纯转发包装
- [x] (2026-02-08) M3：提取 UIModel 共用构建逻辑
- [x] (2026-02-08) M4：拆分 open_choice_modal，修复可读性问题
- [x] (2026-02-08) M5：消除 UIEventHandlers 模块级可变状态
- [x] (2026-02-08) 最终验证：全量测试 + grep 确认全部通过


## 意外与发现


- M2：回归测试 `regression.lua:945` 打桩了 `ui_view.refresh_board` 为空函数。删除转发后 `render()` 直接调用 `board_view.refresh_board`，绕过了打桩。修正方案：将打桩目标从 `ui_view` 改为 `board_view`。
- M4：BoardScene.lua 第一个 `45`（空路径回退默认值）无法替换为 `#tile_ids`（此时为 0），仅替换了第二处。


## 决策日志


暂无。


## 结果与复盘


5 个里程碑全部完成，全量测试通过，7 项 grep 验证均无命中。

改动文件汇总：
- `src/ui/MoveAnim.lua` — 删除死代码、未使用参数、重命名模块变量
- `src/ui/BoardScene.lua` — 删除注释代码、替换魔法数字
- `src/ui/UIView.lua` — 合并 `_set_label`/`_set_button`、删除转发包装、拆分 `open_choice_modal`
- `src/ui/UIModel.lua` — 提取三个共用构建函数
- `src/ui/UIPanel.lua` — 统一标点
- `src/ui/UIEventHandlers.lua` — 模块状态收归 context 表
- `src/app/init.lua` — 新增 `board_view` require，直接调用 `board_view.*`
- `.agents/tests/regression.lua` — 打桩目标从 `ui_view` 改为 `board_view`


## 背景与导读


本项目是一款基于蛋仔编辑器（Eggy）的大富翁游戏，使用 Lua 编写。`src/ui/` 目录包含所有与 UI 渲染、事件绑定、动画相关的模块。

关键文件与职责：

- `src/ui/UIView.lua` — 视图层入口，负责刷新面板、棋盘、弹窗、选择框。对外暴露 `render`、`open_choice_modal`、`close_choice_modal`、`push_popup`、`close_popup` 等方法。
- `src/ui/UIModel.lua` — 数据层，将游戏状态转换为 UI 视图模型。暴露 `build` 和 `update` 两个方法。
- `src/ui/UIEventRouter.lua` — 事件绑定层，把 UI 节点点击映射为游戏意图并分发给 `TurnDispatch`。
- `src/ui/UIEventHandlers.lua` — 游戏事件监听，把 MonopolyEvents 转为日志输出和动画清除。
- `src/ui/BoardView.lua` — 棋盘渲染，管理地块颜色、玩家棋子位置。
- `src/ui/MarketView.lua` — 市场面板渲染。
- `src/ui/MoveAnim.lua` — 玩家移动动画。
- `src/ui/ActionAnim.lua` — 道具使用动画（投骰、路障、地雷等）。
- `src/ui/BoardScene.lua` — 棋盘 3D 场景初始化。
- `src/ui/TileRenderer.lua` — 单个地块的颜色/文字渲染。
- `src/ui/BuildingEffects.lua` — 建筑升级特效。
- `src/ui/UIPanel.lua` — HUD 面板数据构建。
- `src/ui/UIChoice.lua` — 选择弹窗数据构建。
- `src/ui/UIAliases.lua` — UI 节点名英文别名映射。
- `src/ui/MarketLayout.lua` — 市场面板节点名常量。
- `src/ui/UIEvents.lua` — Canvas 显示/隐藏事件。

外部调用 `src/ui/` 的文件（改动不可波及）：

- `src/app/init.lua` — 引用 UIView、UIModel、UIEventRouter、UIEvents、BoardScene。
- `src/game/turn/GameplayLoop.lua` — 引用 UIEventHandlers、UIView、MoveAnim。
- `src/game/turn/TickUISync.lua` — 引用 UIView、UIModel。

测试入口：`lua .agents/tests/all.lua`，在仓库根目录执行。


## 工作计划


工作分为 5 个里程碑，每个里程碑独立可验证，按风险从低到高排列。


### M1：删除死代码与未使用符号

目标是把所有注释掉的代码块、未使用的变量和参数从 `src/ui/` 中彻底删除。这一步改动量最小、风险最低，但立即提升可读性。

具体改动：

1. `src/ui/MoveAnim.lua` — 删除行 3-5 的 `rad_to_deg` 定义（仅在注释代码中使用）。删除行 31-53 的全部注释代码块。删除 `one_step` 函数签名中未使用的 `dir` 参数（第 27 行），改为 `one_step(scene, player_id, from_index, to_index)`。同步修改行 110 和 113 的 `one_step` 调用，去掉 `dir` 实参。

2. `src/ui/BoardScene.lua` — 删除行 21 注释掉的 `set_physics_active`。删除行 25-29 注释掉的 TODO 禁用逻辑块。

3. 检查 `MoveAnim.one_step` 的外部调用方。`src/game/turn/GameplayLoop.lua` 可能调用了 `one_step` 并传入 `dir` 参数。需要同步更新该调用。如果 GameplayLoop 中传入了 `dir`，去掉该实参即可——`dir` 在 `one_step` 内部从未被使用，移除不改变行为。

验收：运行 `lua .agents/tests/all.lua` 通过。用 grep 确认 `rad_to_deg`、`BUFF_FORBID_CONTROL`、`set_physics_active(false)` 均不出现在 `src/ui/` 目录。


### M2：合并重复函数，删除纯转发包装

目标是消除 UIView 中的函数重复和无意义包装层。

具体改动：

1. `src/ui/UIView.lua` — 将 `_set_label` 和 `_set_button`（行 35-43）合并为一个 `_set_text(_, name, text)`。在 `build_ui_state()` 返回的表中，`set_label` 和 `set_button` 都指向 `_set_text`。

2. `src/ui/UIView.lua` — 删除三个纯转发函数：`refresh_board`（行 213-215）、`on_tile_upgraded`（行 289-291）、`on_tile_owner_changed`（行 293-295）。在外部调用方（`src/game/turn/TickUISync.lua`、`src/game/turn/GameplayLoop.lua`）把 `ui_view.refresh_board` 改为 `board_view.refresh_board`，`ui_view.on_tile_upgraded` 改为 `board_view.on_tile_upgraded`，`ui_view.on_tile_owner_changed` 改为 `board_view.on_tile_owner_changed`。这些调用方需要新增 `require("src.ui.BoardView")`。注意 `ui_view.render` 内部（行 270）也调用了 `ui_view.refresh_board`，需改为直接调用 `board_view.refresh_board`。

3. 同理审视 `select_market_option`（行 297-303）。它比纯转发多了一个 nil 守卫和 warn 日志，保留。

验收：运行测试通过。grep `function ui_view.refresh_board` 和 `function ui_view.on_tile_` 在 UIView.lua 中不存在。


### M3：提取 UIModel 共用构建逻辑

目标是消除 `UIModel.lua` 中 `build()` 与 `update()` 之间的三段重复代码。

具体改动：

1. 提取 `_build_item_slots(current, slot_count)` 私有函数，封装行 60-68（build）和 177-191（update）的共同逻辑。两处均改为调用此函数。

2. 提取 `_build_choice_and_market(store_state, env)` 私有函数，封装行 78-94（build）和 194-214（update）的共同逻辑。两处均改为调用此函数，返回 `choice, market` 两个值。

3. 提取 `_build_popup(ui_runtime)` 私有函数，封装行 95-102（build）和 217-226（update）的共同逻辑。

验收：运行测试通过。`UIModel.build` 和 `UIModel.update` 中不再有重复的 item_slots / choice / popup 构建代码。


### M4：拆分 open_choice_modal，修复可读性问题

目标是拆分职责过重的函数，修复散落的可读性问题。

具体改动：

1. `src/ui/UIView.lua` — 将 `open_choice_modal`（行 305-371）拆为两个私有函数：`_open_market_panel(state, choice, market)` 处理 `choice.kind == "market_buy"` 分支，`_open_generic_choice(state, choice)` 处理通用选择弹窗分支。`open_choice_modal` 成为一个路由，只做前置检查和分支调用。

2. `src/ui/UIPanel.lua` 行 58 和 60 — 统一冒号为全角 `"自动：关"`（与 `"自动：开"` 一致）。

3. `src/ui/MoveAnim.lua` — 将模块变量名 `movement_manager` 改为 `move_anim`，与文件名一致。

4. `src/ui/BoardScene.lua` 行 35 和 46 — 将魔法数字 `45` 替换为 `#tile_ids`。

验收：运行测试通过。`open_choice_modal` 函数体不超过 15 行。grep `movement_manager` 不出现在 MoveAnim.lua 中。grep `"自动:关"` 不出现。


### M5：消除 UIEventHandlers 模块级可变状态

目标是将 `UIEventHandlers.lua` 的三个模块级变量（`installed`、`current_logger`、`current_state`）转为显式管理，消除隐式时序依赖。

当前问题：`install()` 首次调用时 `RegisterCustomEvent` 注册回调，这些回调通过闭包读取 `current_state` 和 `current_logger`。后续调用 `install()` 只更新这两个 upvalue，不重新注册。这意味着回调的行为依赖于最新一次 `install` 调用的参数——一种隐式远程耦合。

具体改动：

1. 将 `current_logger` 和 `current_state` 包装在一个 `context` 表里：`local context = { logger = nil, state = nil }`。回调通过 `context.logger` 和 `context.state` 访问。`install()` 写入 `context.logger = logger` 和 `context.state = state`。

2. 这样做的好处：语义更清晰——回调依赖的是"当前上下文"而非散落的独立 upvalue。日后如果需要支持重注册（销毁旧回调），只需扩展 context 带上 listener 列表。行为完全不变。

3. 外部接口不变：`event_handlers.install(_, logger, state)` 签名保持原样。

验收：运行测试通过。grep `local installed` / `local current_logger` / `local current_state` 不出现在 UIEventHandlers.lua 中。


## 具体步骤


在仓库根目录 `/Users/billyq/Dev/Github/Lua/monopoly` 执行所有操作。

每个里程碑完成后立即运行：

    lua .agents/tests/all.lua

预期输出包含 "All tests passed" 或类似全通过标识。如果任何测试失败，停止推进，在"意外与发现"记录失败内容，修复后再继续。

M1 的 `one_step` 参数变更需要检查外部调用方：

    grep -rn "one_step" src/

记录所有调用点，逐一更新签名。

M2 的转发删除需要检查所有引用：

    grep -rn "ui_view\.refresh_board\|ui_view\.on_tile_upgraded\|ui_view\.on_tile_owner_changed" src/

逐一改为 `board_view.*` 调用。


## 验证与验收


1. 运行 `lua .agents/tests/all.lua`，全部通过。
2. 以下 grep 命令在 `src/ui/` 下均返回空结果：
   - `grep -rn "rad_to_deg" src/ui/`
   - `grep -rn "BUFF_FORBID_CONTROL" src/ui/`
   - `grep -rn "function ui_view.refresh_board" src/ui/`
   - `grep -rn "function ui_view.on_tile_" src/ui/`
   - `grep -rn "movement_manager" src/ui/MoveAnim.lua`
   - `grep -rn '"自动:关"' src/ui/`
   - `grep -rn "local current_logger" src/ui/UIEventHandlers.lua`
3. 外部调用方文件（`src/app/init.lua`、`src/game/turn/GameplayLoop.lua`、`src/game/turn/TickUISync.lua`）仅在 M2 中有最小改动（替换 `ui_view.*` 为 `board_view.*`），其它地方不受影响。


## 可重复性与恢复


全部改动均为纯代码编辑，可通过 `git checkout -- src/ui/ src/game/turn/` 一键回滚。每个里程碑独立可验证，如果某个里程碑引入问题，可以只回滚该里程碑的文件改动。建议每个里程碑完成后做一次 git commit。


## 产物与备注


产物为 `src/ui/` 目录下约 8 个文件的局部修改，加上 `src/game/turn/` 下 1-2 个文件的 require 路径调整（仅 M2）。不新增任何文件。


## 接口与依赖


本次整治不改变任何模块的公开接口，只有以下两处外部可见变更：

1. `MoveAnim.one_step` 签名从 `(scene, player_id, dir, from_index, to_index)` 变为 `(scene, player_id, from_index, to_index)`——删除未使用的 `dir` 参数。所有调用方需同步更新。

2. 外部调用方原先通过 `ui_view.refresh_board` / `ui_view.on_tile_upgraded` / `ui_view.on_tile_owner_changed` 间接调用 `board_view`，改为直接调用 `board_view`。需新增 `require("src.ui.BoardView")`。

---

变更说明（2026-02-08）：清空旧计划，基于 `report.md` 审查结果写入 src/ui Clean Code 整治计划，包含 5 个里程碑。
