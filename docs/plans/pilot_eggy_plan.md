# Love2D 视图模型移植 + Eggy 黑市 UI 试点 ExecPlan

本 ExecPlan 是一份活文档。`Progress`、`Surprises & Discoveries`、`Decision Log`、`Outcomes & Retrospective` 四个章节必须在执行过程中持续更新。

本仓库有 ExecPlan 规范文件 `.agent/PLANS.md`，本计划必须按该规范维护。

## Purpose / Big Picture

本计划聚焦两件事：一是把 Love2D 的视图模型与 UI 数据结构移植到 Eggy 适配层，保证 Eggy UI 使用与 Love2D 相同的 `view` 结构（包含 `state`、`board.tiles`、`board.overlays` 等），消除 UI 读取字段不一致与格子数据缺失的问题；二是引入 Eggy UI 管理器与三选一 UI 库，为“黑市购买”提供卡片式选择界面。完成后，Eggy 的面板与格子详情能稳定显示与 Love2D 相同的业务信息，黑市购买在 Eggy 端优先使用 ChooseOption 展示三选一界面，Love2D 行为保持不变。验证方式是通过 Lua 命令生成 `view` 并检查字段，同时运行现有依赖与回归脚本；如具备 Eggy 运行环境，再用 UI 手工验证格子、面板渲染与黑市选择界面。

## Progress

- [x] (2026-01-21 11:40Z) 根据 2026-01-21 架构审查结果，确定试点范围仅聚焦 Eggy 与 Love2D 的视图模型一致性，暂停 Oasis 适配层深度改造。
- [x] (2026-01-21 12:30Z) 学习 `docs/eggy/lib/eggy_ui_manager` 与 `docs/eggy/lib/eggy_choose_option` 的用法与限制，确认可用于 Eggy UI 管理与黑市三选一界面。
- [ ] 把 Love2D 的 Presenter 迁移为平台无关实现，并统一 Eggy/Love2D/Oasis 的引用路径。
- [ ] 确保 Eggy 构建的 `view` 结构与 Love2D 一致，且 Eggy UI 读取路径不变或等价替换。
- [ ] 引入 UIManager 管理 Eggy UI 节点查询与事件绑定，替换或包装现有 `LuaAPI.query_ui_node` 路径。
- [ ] 用 ChooseOption 接入黑市购买选择：当可选项不超过 3 个时显示三选一界面，超过 3 个时回退原弹窗选择。
- [ ] 运行 `lua tests/deps_check.lua` 与 `lua tests/regression.lua` 并记录结果。
- [ ] 运行最小 `view` 生成命令验证 `board.tiles`、`board.overlays` 与 `state` 可用；有 Eggy 环境时补充 UI 手工验证。

## Surprises & Discoveries

- Observation: Eggy 当前 `Presenter.present` 直接返回 `store_state.board`，其中 `board.tiles` 仅含地皮状态而非完整格子配置，导致 UI 使用 `view.board.tiles[idx]` 时可能为空。
  Evidence: `src/adapters/eggy/presenter.lua` 读取 `store_state.board`，而 `src/gameplay/composition_root.lua` 的 `board.tiles` 只记录地皮状态。
- Observation: ChooseOption 固定三张卡片结构，依赖容器内子节点序号与自定义事件名，且需要 ImageKey 图标；当前 `src/config/items.lua` 与 `src/config/vehicles.lua` 没有图标映射。
  Evidence: `docs/eggy/lib/eggy_choose_option/ChooseOption/Container.lua` 固定读取 3 个子节点并要求 `icon`，而配置表仅含 `name/tier` 等字段。

## Decision Log

- Decision: 本试点优先完成 Love2D 视图模型向 Eggy 的移植，暂不推进 Oasis UI 结构整理，仅做必要的引用路径修正。
  Rationale: Eggy 视图模型不一致风险最高，修复后即可为后续 Oasis 统一提供稳定基础，同时控制改动范围。
  Date/Author: 2026-01-21 / Codex

- Decision: Presenter 作为平台无关实现从 Love2D 目录迁移到 `src/adapters/core/`，由 Eggy/Love2D/Oasis 共同引用。
  Rationale: 同一份视图模型逻辑至少被两个平台使用，符合“≥2 调用点”的抽象条件，且能消除跨平台依赖方向不清的问题。
  Date/Author: 2026-01-21 / Codex

- Decision: Eggy 端引入 UIManager 管理 UI 节点，并将黑市购买界面优先映射到 ChooseOption；当可选项超过 3 个时回退原文本弹窗，保证购买范围不缩水。
  Rationale: UIManager 提供稳定的节点管理与事件监听，ChooseOption 可复用三选一 UI，但黑市配置项远超 3 个，为避免功能缩水必须保留原弹窗作为兜底。
  Date/Author: 2026-01-21 / Codex

## Outcomes & Retrospective

尚未执行，实现完成后补充实际结果、剩余工作与经验总结。

## Context and Orientation

适配层位于 `src/adapters/`。当前 Love2D 通过 `src/adapters/love2d/presenter.lua` 生成 `view`，其中 `view.board.tiles` 来自配置表，`view.board.overlays` 来自 `game.board:get_overlays()`。Eggy 通过 `src/adapters/eggy/presenter.lua` 生成 `view`，但其 `board` 来自 `store_state`，并不包含配置表格子信息。Eggy UI 逻辑在 `src/adapters/eggy/eggy_layer.lua` 的 `refresh_panel`、`refresh_tile_detail` 与 `refresh_board` 中依赖 `view.state` 与 `view.board.tiles` 进行渲染。

本计划中的“视图模型”指 Presenter 生成的 `view` 表，包含当前回合状态、玩家信息与可渲染的格子列表。“移植”指在 Eggy 适配层复用 Love2D 的视图模型结构，确保 UI 读取的数据完整一致。

Eggy UI 工具库位于 `docs/eggy/lib/`：`eggy_ui_manager` 提供 `UIManager.Builder` 构建节点树、`query_nodes_by_name/query_node_by_id` 查询节点，以及事件监听器；`eggy_choose_option` 提供三选一容器 `ChooseOption.build`，通过 `choose_event` 与 `confirm_event` 驱动选择确认。ChooseOption 依赖固定 UI 子节点结构（容器内第 1~3 张卡片等），并要求图标 `ImageKey`。这些库需要被拷贝到运行时 Lua 路径中才能被 `require`。

## Plan of Work

首先把 `src/adapters/love2d/presenter.lua` 迁移到 `src/adapters/core/presenter.lua`，保持函数 `present(store_state, env)` 行为一致，并在其中补足 Eggy 需要的派生字段（例如当前玩家名、现金、回合数），确保 Love2D 仍然输出原有字段。然后更新 Love2D、Eggy、Oasis 对 Presenter 的引用路径到新的核心位置，保证行为一致且无跨平台依赖倒置。

接着更新 Eggy 适配层使用新的 Presenter。若 Presenter 已提供 Eggy 所需的派生字段，则 `EggyLayer:_log_status` 保持字段读取方式不变；若未提供，则在 Eggy 层使用 `view.state` 重新计算并保持日志文本一致。确保 `refresh_panel`、`refresh_tile_detail`、`refresh_board` 读取的 `view.board.tiles` 与 `view.board.overlays` 与 Love2D 对齐。

随后引入 UIManager：将 `docs/eggy/lib/eggy_ui_manager/UIManager` 与 `ClassUtils.lua` 拷贝到运行时 Lua 根目录，保持 `require "UIManager.Utils"` 可用；把 Eggitor 导出的 UI 节点数据放入 `src/adapters/eggy/ui_nodes.lua`（或等价路径），在 Eggy 初始化后调用 `UIManager.Builder` 载入节点。更新 `src/adapters/eggy/ui_state.lua` 的节点查询逻辑：优先用 UIManager 按名称查询节点，找不到再回退 `LuaAPI.query_ui_node`，确保行为不变但可统一节点管理。

最后接入 ChooseOption 作为黑市购买 UI：当 `choice.kind == "market_buy"` 时，如果可选项数量不超过 3，则创建/复用 ChooseOption 容器并填充三张卡片；超过 3 时继续使用原来的文本弹窗（`_open_choice_modal`），避免购买范围缩水。ChooseOption 的卡片内容由 market 选项构建：标题取道具/座驾名称，描述包含价格与币种，等级可暂按道具 `tier` 或座驾 `tier` 映射到 1~3（超出范围就夹紧），图标先使用占位 ImageKey 或新增映射表（需明确数据来源）。保留 “不买/取消” 行为：在 Eggy UI 中补一个取消按钮并走 `choice_cancel`，或当未选中卡片时把确认视为取消。

收尾运行 Lua 依赖检查与回归脚本，并添加一个最小的命令行验证步骤，直接构建 `view` 并断言关键字段存在。如果具备 Eggy 运行环境，手工确认面板、格子详情、路障/地雷标记与黑市三选一界面能正常显示与购买。

## Concrete Steps

在仓库根目录 `c:\Users\Lzx_8\Desktop\eggitor\1_开发中\大富翁\monopoly` 下执行以下步骤。

1) 迁移 Presenter 文件并更新引用。
   - 将 `src/adapters/love2d/presenter.lua` 移动为 `src/adapters/core/presenter.lua`。
   - 更新 `src/adapters/love2d/love_layer.lua`、`src/adapters/eggy/eggy_layer.lua`、`src/adapters/oasis/oasis_layer.lua` 的 `require` 路径。
   - 删除 `src/adapters/eggy/presenter.lua`，避免重复实现。

2) 补足 Presenter 返回值以满足 Eggy UI 需要。
   - 在 `src/adapters/core/presenter.lua` 中保证返回 `state`、`board.tiles`、`board.overlays`，并提供 `current_player_name`、`current_player_cash`、`turn_count` 等派生字段，保证 Eggy `_log_status` 与面板渲染行为不变。

3) 调整 Eggy 层对 view 的使用（仅当必要）。
   - 若 `view` 中字段已齐全，保持 `EggyLayer` 逻辑不变。
   - 若字段名发生变化，修改 `EggyLayer:_log_status` 与相关读取逻辑，使输出文本保持一致。

4) 接入 UIManager 管理节点。
   - 将 `docs/eggy/lib/eggy_ui_manager/UIManager` 与 `docs/eggy/lib/eggy_ui_manager/UIManager/ClassUtils.lua` 拷贝到仓库根目录（或其他 Lua 根目录），确保 `require "UIManager.Utils"` 可用。
   - 使用 Eggitor 导出 UI 节点数据到 `src/adapters/eggy/ui_nodes.lua`（或等价路径），并在 `EggyRuntime.install` 的 GAME_INIT 回调中调用 `UIManager.Builder(require("src.adapters.eggy.ui_nodes"))`。
   - 修改 `src/adapters/eggy/ui_state.lua` 的节点查询：优先 `UIManager.query_nodes_by_name(name)[1]`，并保留对 `LuaAPI.query_ui_node` 的回退。

5) 接入 ChooseOption 作为黑市购买界面。
   - 将 `docs/eggy/lib/eggy_choose_option/ChooseOption` 拷贝到 Lua 根目录，确保 `require "ChooseOption.__init"` 可用。
   - 在 Eggy 侧新增黑市 UI 配置（建议 `src/adapters/eggy/market_ui.lua`），包含 ChooseOption 容器 ID、确认按钮 ID、选择/确认事件名、取消按钮 ID（如有）。
   - 修改 `EggyLayer:_open_choice_modal` 或新增分支处理：当 `choice.kind == "market_buy"` 且 `#choice.options <= 3` 时，调用 ChooseOption 构建容器、填充三张卡片，并把卡片选择与确认事件转成 `choice_select/choice_cancel`。
   - 当 `#choice.options > 3` 时继续使用原有弹窗逻辑。

6) 运行依赖与回归测试。

   - `lua tests/deps_check.lua`
   - `lua tests/regression.lua`

7) 执行最小 `view` 生成验证（无 Eggy 环境也可运行）。

   - `lua -e "local Game=require('src.game'); local Presenter=require('src.adapters.core.presenter'); local g=Game.new({players={'玩家1','AI2','AI3','AI4'},ai={[2]=true,[3]=true,[4]=true},auto_all=true}); local view=Presenter.present(g.store.state,{game=g,last_turn=g.last_turn,finished=g.finished,winner_name=nil}); assert(view.state and view.board and view.board.tiles and view.board.overlays); print('view ok', #view.board.tiles)"`

8) 若可运行 Eggy 环境，启动 Eggy 场景并观察：面板显示当前玩家与回合数，格子详情显示名称/价格/等级，路障与地雷提示随回合变化；黑市出现时在 Eggy 端优先展示三选一卡片界面，选择后能正确购买或取消。

## Validation and Acceptance

验收标准：

- `lua tests/deps_check.lua` 与 `lua tests/regression.lua` 均通过，无新增回归。
- 最小 `view` 生成命令输出 `view ok` 且 `#view.board.tiles` 为正整数。
- 在 Eggy 环境中，面板与格子详情可正常显示，且与 Love2D 行为一致（同一局面下名称、价格、等级、路障/地雷提示一致）。
- 黑市选择：当可选项不超过 3 个时，Eggy 端展示 ChooseOption 界面且选中后能正确购买；当可选项超过 3 个时，继续使用原文本弹窗且可购买任意商品。

## Idempotence and Recovery

所有改动均为文件迁移与字段对齐，可重复执行。若出现渲染异常或字段缺失，可临时回退 Eggy 到原 Presenter 实现以恢复显示，再逐步对齐字段并重新迁移。若 ChooseOption 接入导致黑市流程异常，可临时移除 Eggy 的 `market_buy` 分支，回退到原弹窗流程，保持游戏逻辑不变。

## Artifacts and Notes

建议保留 `EggyLayer` 日志文本格式不变，只允许字段来源变化。执行最小验证命令时，期望输出类似：

  view ok 36

## Interfaces and Dependencies

`Presenter.present(store_state, env)` 必须在 `src/adapters/core/presenter.lua` 提供，返回结构至少包含：

  view.state: 规则层状态快照（来自 `store_state`）。
  view.board.tiles: 由配置表构建的格子数组，每项包含 `id`、`name`、`type`、`price`、`row`、`col`。
  view.board.overlays: `game.board:get_overlays()` 返回的路障/地雷覆盖信息。
  view.current_player_name / view.current_player_cash / view.turn_count: Eggy 面板与日志需要的派生字段。

`env` 需要包含 `game`，并可选包含 `last_turn`、`finished`、`winner_name`。Love2D 与 Eggy 均以此结构调用 Presenter。Oasis 仅更新引用路径，不改变行为。

UIManager 依赖 `UIManager.Utils` 并在初始化时调用：

  UIManager.Builder(require("src.adapters.eggy.ui_nodes"))
  UIManager.query_nodes_by_name(name)

ChooseOption 需要在 Lua 根目录可 `require "ChooseOption.__init"`，并提供配置：

  container: ENode 容器 ID
  title: string 标题
  description: string 描述
  choose_event: string 选择事件名
  confirm_event: string 确认事件名
  confirm_button: ENode 确认按钮 ID

卡片显示必须提供 `icon`（ImageKey），`title`、`description`，可选 `label` 与 `icon_description`，并将 `level` 控制在 1~3。

## 变更记录

2026-01-21：首次建立试点计划，明确范围与执行步骤。
2026-01-21：补充 UIManager 与 ChooseOption 接入方案与黑市 UI 试点范围。
