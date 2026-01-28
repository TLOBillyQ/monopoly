# UI 画布清理与基础屏重构可执行计划

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循仓库内的 .agent/PLANS.md，所有调整都必须保持该规范。

## 目的 / 全局视角


本任务要清理遗留的 UI 功能，让基础屏只保留必要信息，并把棋盘渲染与道路障碍/地雷覆盖转回场景单位渲染。完成后，base_screen 不再渲染 tile_1..tile_45 文本，也不再显示“格子详情”面板；玩家信息区域只显示头像、现金、地块数量、总资产，item_slot 以可点击图片显示道具。验收方式是在 Eggy 运行时打开基础屏，确认没有格子文本与格子详情，玩家信息四项正确刷新，道具槽位可点击，且棋盘上的地块显示与覆盖物由场景单位呈现。

## 进度


- [ ] (2026-01-28 05:15Z) 创建并确认本可执行计划范围与验收口径。
- [x] (2025-09-24 01:20Z) 创建并确认本可执行计划范围与验收口径。
- [x] (2025-09-24 01:20Z) 盘点 UI 渲染链路与棋盘渲染链路的现状，确认移除范围与资产来源。
- [ ] (2025-09-24 01:20Z) 部分完成：已完成代码与文档调整、测试清单更新；剩余：Eggitor 删除节点并重新导出 `ui_data.lua`。
- [ ] (2025-09-24 01:32Z) 部分完成：已运行 `lua tests/deps_check.lua` 与 `lua tests/regression.lua`；剩余：Eggitor 手工验收与截图。

## 意外与发现


- 观察：暂无新的意外与发现。
  证据：无。

## 决策日志


- 决策：玩家信息区保留玩家名作为标题，但状态字段只展示头像、现金、地块数量、总资产，其它细节全部移除。
  理由：不改变玩家识别能力，同时满足“仅展示四项信息”的要求。
  日期/作者：2026-01-28 / Codex
- 决策：移除 UI 的 tile_1..tile_45 与 tile_detail_* 显示逻辑，并删除对应模块与调用点。
  理由：棋盘与覆盖物应在场景单位呈现，UI 渲染属于遗留功能，删除可减少维护。
  日期/作者：2026-01-28 / Codex
- 决策：玩家总资产展示复用 `panel_player_*_detail` 标签，并在 UI 层按地块数量与投资额合并计算。
  理由：现有 UI 结构中可复用的标签最少改动，且与总资产需求一致。
  日期/作者：2025-09-24 / Codex
- 决策：道具槽位以贴图形式展示，优先使用 `G.refs` 的道具 id；缺失时回退到“空”贴图。
  理由：保持点击逻辑不变，确保图片显示稳定。
  日期/作者：2025-09-24 / Codex

## 结果与复盘


已完成代码与文档调整与脚本测试，尚未执行 Eggitor 节点清理与手工验收，结果与复盘待全部验收后补写。

## 背景与导读


当前 Eggy UI 由 `src/adapters/eggy/eggy_layer_ui.lua` 负责面板刷新，由 `src/adapters/eggy/eggy_layer_board.lua` 负责棋盘相关展示，其中包含对 `src/adapters/core/ui_tile.lua` 的依赖以生成 UI 上的 tile 标签与格子详情。基础屏节点在 `docs/ui/ui_naming_list.md`、`docs/ui/01_canvas_inventory.md`、`docs/ui/02_base_screen.md` 中定义，UI 数据由 `ui_data.lua` 提供并由 Eggitor 导出。需求变更要求去除 UI 上的格子文本与格子详情，并将 overlay 改为场景单位呈现，同时调整玩家信息显示为头像、现金、地块数量、总资产，以及 item_slot 以可点击图片显示道具。

## 工作计划


先从渲染链路切断 UI 对 tile 的依赖，删除 `EggyLayerBoard.refresh_board` 中对 tile_1..tile_45 的标签刷新，并移除 `src/adapters/core/ui_tile.lua` 及所有引用。随后删除格子详情功能，包括 `EggyLayerUI.refresh_tile_detail`、`EggyLayer:refresh_tile_detail`、`EggyLayer:dispatch_action` 中的 `ui_tile_select` 分支，以及 UI 状态中的 selected_tile 字段，同时清理 panel_tile_title 与 tile_detail_* 节点在 UI 文档与命名清单中的出现。接着把玩家信息刷新逻辑改为写入 `panel_player_X_avatar`、`panel_player_X_cash`、`panel_player_X_land_count`、`panel_player_X_base`，其中总资产的计算沿用 `src/game.lua` 的 `total_assets` 逻辑，在 UI 层按玩家拥有地块与投资额汇总。item_slot 渲染改为设置图片纹理，优先使用 `G.refs` 的道具 id 贴图，空槽位使用“空”贴图，并保留点击事件。最后更新 `docs/ui` 中的基础屏与命名清单，并在 Eggitor 中移除不再使用的节点后重新导出 `ui_data.lua`。

## 具体步骤


在仓库根目录先用 `rg` 确认 tile 与格子详情的所有入口，核对 `eggy_layer_ui.lua`、`eggy_layer_board.lua`、`eggy_layer.lua` 与 `ui_tile.lua` 的调用关系，并记录需要删除的函数与字段。随后按工作计划完成删除与改写，确保 `EggyLayerUI.refresh_panel` 仅写入新的玩家信息字段，`EggyLayerBoard.refresh_board` 只负责场景单位定位与渲染，item_slot 的刷新改为图片纹理设置且保留点击事件。文档更新完成后，在 Eggitor 内同步删除 tile_1..tile_45 与格子详情相关节点，并重新导出 `ui_data.lua`，确保命名与类型一致。

本步骤涉及的命令示例如下，命令执行位置为仓库根目录：

    rg -n "tile_detail|tile_\\d+|ui_tile|ui_tile_select" src/adapters -S
    lua tests/deps_check.lua
    lua tests/regression.lua

已执行并通过的命令输出如下：

    > lua tests/deps_check.lua
    Dependency self-check passed

    > lua tests/regression.lua
    ..............................
    All regression checks passed (30)

## 验证与验收


先运行 `lua tests/deps_check.lua` 与 `lua tests/regression.lua`，两者必须通过（已通过）。随后在 Eggy 运行时进入基础屏，确认界面不再出现 tile_1..tile_45 文本与格子详情面板，玩家信息区仅展示头像、现金、地块数量与总资产，道具槽位以图片显示且点击仍能触发道具选择。覆盖物显示应来自场景单位而非 UI，若缺少覆盖物资产或 prefab，需要补齐后再复验。

## 可重复性与恢复


代码修改均在 `src/adapters` 与 `docs/ui` 下进行，可通过版本控制回滚；UI 资源调整需要在 Eggitor 中删除节点并重新导出 `ui_data.lua`，在执行前先备份当前 UI 资源与导出文件以便恢复。

## 产物与备注


产物包含更新后的 `src/adapters/eggy/eggy_layer_ui.lua`、`src/adapters/eggy/eggy_layer_board.lua`、`src/adapters/eggy/eggy_layer.lua`、`src/adapters/core/ui_panel.lua`、`tests/ui_nodes_audit.lua`、`docs/ui` 下对应文档，并删除 `src/adapters/core/ui_tile.lua`。仍需在 Eggitor 中清理节点并重新导出 `Data/ui_data.lua`。验收时需保留测试输出片段与一张基础屏对照截图以证明 UI 已按需求简化。

本次更新：完成 UI 清理代码、玩家信息与道具槽位逻辑更新，并同步文档与 UI 节点审计及 Lua 测试执行，原因是计划 6 要求去除格子文本与详情，同时将玩家信息与道具展示改为精简版本。

## 接口与依赖


本次调整仍依赖 `src/game.lua` 中的资产计算逻辑与 `src/adapters/eggy/market_ui.lua` 的黑市配置，不引入新的抽象层。要求保留 `EggyLayer.new`、`EggyLayer:tick`、`EggyLayer:dispatch_action` 等对外接口，只删除与 tile 详情相关的分支。里程碑结束时应存在以下核心函数或替代实现，且签名保持可调用：

    EggyLayerUI.build_ui_state()
    EggyLayerUI.refresh_panel(layer, view)
    EggyLayerUI.refresh_item_slots(layer, view)
    EggyLayerBoard.refresh_board(layer, view, log_once, build_log_prefix)
