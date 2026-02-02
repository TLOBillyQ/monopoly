# 移除全局 G 并归位初始化流程

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 .github/agent/PLANS.md。


## 目的 / 全局视角

本次改动的目标是拆除全局变量 `G` 的使用方式，把 UI 资源、棋盘单位、地面单位、玩家控制单位等初始化行为放入对应的 manager，并在明确的初始化流程中完成。完成后，UI 刷新、动画播放与建筑特效不再依赖 `G`，初始化顺序清晰可追踪。可观察结果是：`G` 在仓库中不再被引用；`init.lua` 只负责调用各 manager 的初始化入口；回归脚本能通过，并且游戏启动后界面与动画行为与现状一致。


## 进度

- [x] (2026-02-02 14:02Z) 梳理 `G` 的字段来源与所有调用点，确认各自应归属的 manager。
- [x] (2026-02-02 14:02Z) 新增或扩展 manager 初始化入口，承接 `init.lua` 中的 `G` 初始化逻辑。
- [x] (2026-02-02 14:02Z) 替换 `G` 访问为 manager/状态字段，并删除 `G` 全局。
- [x] (2026-02-02 14:02Z) 运行回归脚本并记录结果，补齐可能遗漏的初始化依赖。


## 意外与发现

- 观察：旧逻辑在 `init.lua` 中对 1 号角色的控制单位重复调用 `add_state`（位于 `ALLROLES` 循环内）。
  处理：在新的 `BoardScene.init` 中按角色数重复调用，以保持行为一致。


## 决策日志

- 决策：使用 `state.board_scene` 作为棋盘相关运行态容器，集中存放 tile/building/ground/role/ctrl_unit 等资源。
  理由：这些资源由棋盘显示与移动动画共同依赖，集中管理便于初始化与断言收口。
  日期/作者：2026-02-02 / Codex
- 决策：使用 `state.ui_refs` 承接 `Globals.Refs`，UI 刷新与市场面板通过 `state` 读取。
  理由：引用表属于 UI 资源，不应放在全局变量中，同时 `state` 已在 UI 层广泛传递。
  日期/作者：2026-02-02 / Codex
- 决策：保留 `BUFF_FORBID_CONTROL` 的重复调用次数，只作用于 1 号控制单位。
  理由：旧逻辑在 `ALLROLES` 循环内重复调用该状态，保持一致以规避行为差异。
  日期/作者：2026-02-02 / Codex


## 结果与复盘

已完成 `G` 的全量拆除，将棋盘场景初始化迁入 `BoardScene.init`，将 UI 资源初始化迁入 `MainView.init_ui_assets`，并在 `init.lua` 中按顺序调用。回归脚本通过，UI/棋盘刷新仍走原路径但不再依赖全局变量。


## 背景与导读

当前仓库使用全局变量 `G` 存放多种初始化资源。`init.lua` 在 `EVENT.GAME_INIT` 中创建 `G`，包含 `refs`、`tiles`、`buildings`、`ground`、`role`、`unit` 等字段，并负责查询棋盘单位与设置 UI 图标。下列模块直接依赖 `G`：`Manager/BoardManager/GUI/BoardView.lua`、`Manager/BoardManager/GUI/MoveAnim.lua`、`Manager/BoardManager/GUI/BuildingEffects.lua`、`Manager/MarketManager/GUI/UIMarket.lua`、`Manager/TurnManager/GUI/UIState.lua`。这造成初始化职责混杂且难以追踪。需要将这些资源分别归到棋盘相关 manager 与 UI manager，并通过 `state` 或明确的上下文对象传递。


## 工作计划

首先梳理 `G` 字段的来源与去向，确定哪些属于棋盘场景资源、哪些属于 UI 资源。接着新增或扩展棋盘相关 manager（例如 `Manager/BoardManager/GUI/BoardScene.lua` 或在现有模块中新增初始化函数），把 tile/building/ground/ctrl_unit 的查询与缓存集中在该 manager，并让 `GameplayLoop` 在 `GAME_INIT` 之后调用它，把结果写入 `state.board_scene`。UI 资源部分由 UI 侧 manager 负责，例如在 `Manager/TurnManager/GUI/MainView.lua` 或 `Manager/TurnManager/GUI/UIState.lua` 中新增初始化函数，读取 `Globals.Refs` 并设置道具槽位图标，将引用表写入 `state.ui_refs`。随后逐个替换 `G` 的访问路径：`BoardView`/`MoveAnim`/`BuildingEffects` 使用 `state.board_scene`；`UIMarket` 与 `UIState` 使用 `state.ui_refs`；最后删除 `init.lua` 中的 `G` 全局创建与相关字段。所有改动保持行为不变，只调整数据来源与初始化位置。


## 具体步骤

1) 在仓库根目录定位 `G` 使用点，明确字段来源。

   运行：

       rg -n "\\bG\\b|G\\." --glob '!Library/**'

   预期看到 `init.lua` 与上述 GUI 模块命中。

2) 设计并实现棋盘场景初始化入口。

   在 `Manager/BoardManager/GUI/BoardScene.lua`（或选定的现有模块）中新增初始化函数，例如 `BoardScene.init(state, map_cfg)`，负责：
   - 查询 tile/building/ground 单位（当前在 `init.lua` 完成的逻辑）。
   - 收集 `GameAPI.get_role` 与 `get_ctrl_unit`，生成 `units_by_player_id`。
   - 初始化 `building_unit_groups` 容器。
   - 写入 `state.board_scene`。

   同时调整 `init.lua`，在 `EVENT.GAME_INIT` 中调用该初始化入口，而不再创建 `G`。

3) 设计并实现 UI 资源初始化入口。

   在 `Manager/TurnManager/GUI/MainView.lua` 或 `Manager/TurnManager/GUI/UIState.lua` 增加初始化函数，例如 `MainView.init_ui_assets(state)`，负责：
   - 读取 `Globals.Refs` 并写入 `state.ui_refs`。
   - 完成道具槽位图标与控制状态的初始化（当前位于 `init.lua` 的 `UIManager.query_nodes_by_name` 循环）。

   由 `init.lua` 在 `EVENT.GAME_INIT` 中调用该初始化函数，替换原逻辑。

4) 替换各模块对 `G` 的访问。

   - `Manager/BoardManager/GUI/BoardView.lua`：改用 `state.board_scene` 的 `tiles/buildings/ground`。
   - `Manager/BoardManager/GUI/MoveAnim.lua`：调整 `one_step` 签名，传入 `state.board_scene` 或 `state`，使用 `scene.tiles` 与 `scene.units_by_player_id`。
   - `Manager/BoardManager/GUI/BuildingEffects.lua`：改用 `state.board_scene.buildings` 与 `state.board_scene.building_unit_groups`。
   - `Manager/MarketManager/GUI/UIMarket.lua` 与 `Manager/TurnManager/GUI/UIState.lua`：改用 `state.ui_refs`。

   这些改动必须保持行为一致，仅改变数据来源。

5) 删除 `init.lua` 中的 `G` 全局创建与其字段初始化。

   确保所有调用点已经替换完成后，移除 `G = { ... }` 以及相关字段赋值。


## 验证与验收

在仓库根目录运行回归脚本：

    lua .github/tests/regression.lua

预期输出包含：

    All regression checks passed (N)

其中 N 为脚本当前测试总数。若失败，优先检查 `state.board_scene` 与 `state.ui_refs` 是否在 `GAME_INIT` 中完成初始化，并确保 `MoveAnim` 与 `BoardView` 的调用路径使用了新的上下文对象。


## 可重复性与恢复

本改动可重复执行。若需要回退，可先恢复 `init.lua` 中的 `G` 初始化与各模块对 `G` 的引用，再逐步恢复 manager 初始化入口。每次回退后运行回归脚本确认状态一致。


## 产物与备注

应保留如下证据片段：

    rg -n "\\bG\\b|G\\." --glob '!Library/**'
    (无命中，或仅剩与说明文本相关的结果)

    lua .github/tests/regression.lua
    All regression checks passed (31)

本次修改说明：更新进度与验证结果，补充行为保持相关决策与发现，原因是实现已经完成并通过回归验证。


## 接口与依赖

需要新增或扩展以下接口（示例名称可按实现调整，但必须稳定）：

在 `Manager/BoardManager/GUI/BoardScene.lua` 中定义：

    BoardScene.init(state, map_cfg) -> scene

并要求 `scene` 至少包含：

    scene.tiles
    scene.buildings
    scene.ground
    scene.units_by_player_id
    scene.building_unit_groups

在 `Manager/TurnManager/GUI/MainView.lua` 或 `Manager/TurnManager/GUI/UIState.lua` 中定义：

    MainView.init_ui_assets(state) -> nil

并要求 `state.ui_refs` 在初始化后可被 UI 模块读取。
