# 面板玩家总资产显示计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

仓库中存在 PLANS.md，路径为 `.agent/PLANS.md`，本文件必须遵循其中的所有要求维护。

## 目的 / 全局视角


完成后，主界面玩家信息面板里的 `panel_player_1_detail` 会显示玩家总资产，口径为“现金 + 地块价值（购买价 + 已建升级成本）”。用户能在游戏里购买地块后直观看到总资产高于现金的数字，从而确认统计生效。

## 进度


- [x] (2026-01-28 17:20) 建立计划初版并确认相关文件位置。
- [x] (2026-01-28 19:40) 核对 UI 绑定与数据来源，确认总资产口径与数据路径。
- [x] (2026-01-28 19:40) 统计与展示逻辑已存在，无需额外修改。
- [x] (2026-01-28 19:40) 部分完成：已运行回归测试；剩余：界面手工验证。

## 意外与发现


- 观察：`Panel.build_player_statuses` 已计算 `total_assets` 并写入 UI，现有逻辑满足口径。
  证据：`src/adapters/core/ui_panel.lua` 内 `total_assets = "总资产: " .. tostring(total)`。
- 观察：`panel_player_*_detail` 节点与 UI 绑定已存在。
  证据：`Data/UIManagerNodes.lua` 与 `src/adapters/eggy/eggy_layer_ui.lua` 已包含对应节点与赋值。

## 决策日志


决策：总资产定义为现金 + 地块价值，地块价值使用 `Pricing.total_invested`（购买价 + 已升级成本）计算。
理由：该口径与现有土地价值计算一致，且无需引入新规则或新增数据源。
日期/作者：2026-01-28 / Codex。

## 结果与复盘


无需新增代码即可满足总资产显示口径，回归测试通过。仍需在可视环境完成一次界面验证，确认购买地块后总资产数值高于现金。

## 背景与导读


玩家面板数据来自 `src/adapters/core/ui_panel.lua` 的 `Panel.build_player_statuses`，该函数读取视图中的玩家状态与棋盘状态并拼接文字。视图由 `src/adapters/core/presenter.lua` 直接暴露 `store_state`，而 `store_state` 在 `src/gameplay/composition_root.lua` 初始化并持续更新。Eggy 侧的 UI 刷新在 `src/adapters/eggy/eggy_layer_ui.lua`，其中 `panel_player_*_detail` 的文本会被设置为每个玩家行的 `total_assets` 字段。UI 节点名在 `Data/UIManagerNodes.lua` 中声明。这里所说的“总资产”就是现金加上玩家名下地块的价值，地块价值以地块购买价和升级成本累计为准。

## 工作计划


先核对 `Panel.build_player_statuses` 当前是否把总资产写入 `total_assets`，以及 `EggyLayerUI.refresh_panel` 是否把该字段绑定到 `panel_player_1_detail`。若统计缺失或不完整，就在 `src/adapters/core/ui_panel.lua` 中补上总资产的计算，确保现金与地块价值都被纳入。地块价值使用 `src/gameplay/land_pricing.lua` 的 `Pricing.total_invested` 计算，并以玩家名下地块为基准；如发现玩家资产在视图中缺失，则改为从棋盘状态的 `owner_id` 反推玩家地块，再计算价值。最后确认 `Data/UIManagerNodes.lua` 中 `panel_player_1_detail` 节点存在并可写，保证 UI 能显示。

## 具体步骤


在仓库根目录执行搜索确认现状与绑定：

    rg -n "panel_player_1_detail|panel_player_.*_detail" src Data
    rg -n "build_player_statuses" src/adapters/core/ui_panel.lua

编辑 `src/adapters/core/ui_panel.lua`，在 `Panel.build_player_statuses` 中补齐总资产计算逻辑，确保总资产 = 现金 + 地块价值，并写入 `total_assets` 字段。若需要从 `board_state` 推导资产归属，也在此处实现。

如发现 `src/adapters/eggy/eggy_layer_ui.lua` 未绑定 `panel_player_*_detail`，则补上设置逻辑，保证玩家 1 的详情行至少显示总资产。

## 验证与验收


运行回归脚本验证基础行为不被破坏：

    lua .github/tests/regression.lua

在可运行 Eggy 的环境中启动 `main.lua`，让玩家购买一块地并升级一次，观察 `panel_player_1_detail` 显示形如 “总资产: <数值>”，且数值大于现金。若无法启动引擎，则在 Lua 里构造一局游戏并调用 `Panel.build_player_statuses`，确认返回值中的 `total_assets` 反映现金+地块价值。

## 可重复性与恢复


上述步骤为小范围改动，重复执行不会产生破坏性副作用。若需要回退，使用版本控制恢复 `src/adapters/core/ui_panel.lua` 与 `src/adapters/eggy/eggy_layer_ui.lua` 的修改，再重新运行回归脚本确认状态恢复。

## 产物与备注


预计产生的关键变更片段类似：

    total_assets = "总资产: " .. tostring(total)

如果使用了从棋盘状态反推地块归属的逻辑，也应有一段清晰可读的累计代码，便于新手核对计算路径。

## 接口与依赖


继续使用 `src/gameplay/land_pricing.lua` 的 `Pricing.total_invested(tile, level)` 作为地块价值口径，不新增新的价值算法。`Panel.build_player_statuses(view, game, max_players)` 必须返回包含 `total_assets` 字段的行对象，`src/adapters/eggy/eggy_layer_ui.lua` 需要把该字段绑定到 `panel_player_*_detail`。不新增新的 helper 或抽象层，保持计算逻辑集中在 `ui_panel.lua` 内。

本次更新说明：首次创建计划，用于补齐 `panel_player_1_detail` 的总资产统计，尚未实施。

改动说明：核对现有实现已满足总资产显示口径，记录回归测试通过并保留界面验证待办。
