# 接入基础屏回合光效与地块 owner 颜色可执行计划

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `/Users/billyq/Dev/Github/Lua/monopoly/.agents/PLANS.md` 维护。

## 目的 / 全局视角

把基础屏的回合高亮、本地回合提示与地块 owner 颜色来源接入现有 UI 刷新链路。完成后，所有客户端都能看到当前回合玩家的高亮光效，本地玩家回合开始时出现 1 秒“星星中心爆开 + 行动提示”，购买地块后地块颜色与玩家底板颜色一致。验证方式是：运行回归脚本通过，并在编辑器内观察 UI 行为符合预期。

## 进度

- [x] (2025-03-08 03:32Z) 清空旧计划并建立新计划骨架。
- [x] (2025-03-08 03:42Z) 新增回合特效模块并接入 UI 刷新链路。
- [x] (2025-03-08 03:43Z) 注入 owner 颜色来源并接入初始化流程。
- [x] (2025-03-08 03:52Z) 运行回归脚本与依赖规则检查。

## 意外与发现

- 观察：UIManager 的 `EImage.image_color` 仅存于脚本封装层，缺少显式读取 API，读取需依赖节点对象上的 `image_color` 属性。
  证据：`vendor/third_party/UIManager/EImage.lua` 仅提供 `image_color` 字段，未暴露 `get_image_color` 函数。

## 决策日志

- 决策：以 `UIManager.query_node` 返回的 `EImage.image_color` 作为底板颜色来源，绑定 `game.players` 槽位顺序。
  理由：现有 UI 没有独立颜色表，EImage 具备可读写颜色属性，且与设计意图一致。
  日期/作者：2025-03-08 / Codex

- 决策：新增 `src/presentation/ui/UITurnEffects.lua`，由 `UIView.render` 触发同步。
  理由：将回合高亮与本地提示逻辑收敛为单一职责模块，避免分散在 UI 层。
  日期/作者：2025-03-08 / Codex

## 结果与复盘

已完成回合高亮、本地回合提示与 owner 颜色注入；回归脚本与依赖规则检查通过。仍需在 Eggy 编辑器内做一次人工验收，确认动画播放与颜色一致性。

## 背景与导读

基础屏 UI 节点由 `Data/UIManagerNodes.lua` 提供，显示/隐藏与属性设置通过 `UIRuntimePort` 与 UIManager 节点访问完成。当前回合信息在 `src/presentation/state/UIModel.lua` 中生成，UI 刷新在 `src/presentation/api/UIView.lua` 的 `render` 方法中触发。地块颜色渲染在 `src/presentation/render/TileRenderer.lua` 内通过 `PlayerColors.resolve_owner_color` 获取颜色。

术语解释：
- “当前回合玩家”指 `ui_model.current_player_id` 对应玩家。
- “本地回合提示”指仅本地客户端显示的 `基础_星星中心爆开` 与 `基础_行动提示`。
- “owner 颜色”指土地所有者颜色，应用到地块染色。

## 工作计划

先新增回合特效模块 `src/presentation/ui/UITurnEffects.lua`，提供 `sync` 方法，内部处理两类逻辑：全员可见的“当前回合高亮”，以及仅本地可见的“回合提示”。随后在 `UIView.render` 中调用该模块，确保在面板刷新后执行。

再扩展 `PlayerColors` 支持外部注入颜色映射，并在 `UIView` 增加 `capture_player_colors`，读取 `玩家1-4底板颜色` 的 `image_color`，按 `game.players` 顺序映射到 `owner_id`，在 `EVENT.GAME_INIT` 中调用。

完成后运行回归脚本，并在编辑器内观察 UI 行为。

## 具体步骤

1) 新增回合特效模块。

在 `src/presentation/ui/UITurnEffects.lua` 中实现：
- `sync(state, ui_model)`：调用回合高亮与本地提示同步函数。
- 回合高亮：设置 `基础_玩家1-4高亮光效` 可见性，仅当前槽位可见，使用 `runtime.set_client_role(nil)` 覆盖所有客户端。
- 本地提示：按 `role_id == current_player_id` 判定，仅本地显示“星星中心爆开 + 行动提示”1 秒并隐藏；用 `state.ui_turn_prompt_seq_by_role` 防抖。

2) 接入 UI 刷新链路。

在 `src/presentation/api/UIView.lua` 的 `render` 中，`panel_presenter.refresh` 后调用 `turn_effects.sync(state, ui_model)`。

3) 注入 owner 颜色来源。

- 在 `src/presentation/shared/PlayerColors.lua` 增加 `set_owner_colors(colors_by_owner_id)`。
- 在 `src/presentation/api/UIView.lua` 增加 `capture_player_colors(state, game)`：读取 `玩家1-4底板颜色` 节点的 `image_color`，按 `game.players` 顺序映射并注入。
- 在 `src/app/init.lua` 的 `EVENT.GAME_INIT` 中，`ui_view.init_ui_assets(state)` 后调用 `ui_view.capture_player_colors(state, current_game)`。

4) 验证。

运行回归脚本并观察 UI 行为。

## 验证与验收

命令：

    lua .agents/tests/regression.lua
    lua .agents/tests/gameplay_loop_no_ui.lua
    lua .agents/tests/dep_rules.lua

预期：全部无错误退出。

人工验收：
- 当前回合玩家高亮始终显示，回合切换时更新。
- 本地玩家回合开始时出现“星星中心爆开 + 行动提示”，1 秒后消失，非本地不显示。
- 购买地块后颜色与玩家底板颜色一致。

## 可重复性与恢复

所有步骤可重复执行。若回合特效表现异常，可临时在 `UIView.render` 中注释调用进行回退。颜色注入异常时，可恢复 `PlayerColors.lua` 默认颜色表。

## 产物与备注

已改动文件：

    src/presentation/ui/UITurnEffects.lua
    src/presentation/api/UIView.lua
    src/presentation/shared/PlayerColors.lua
    src/app/init.lua

关键证据（示例）：

    ..........................................................................................................................
    All regression checks passed (122)
    tick ok
    dep_rules ok

## 接口与依赖

- `PlayerColors.set_owner_colors(colors_by_owner_id)`：注入 owner 颜色映射。
- `UIView.capture_player_colors(state, game)`：从 UI 读取底板颜色并注入。
- `UITurnEffects.sync(state, ui_model)`：统一同步回合高亮与本地提示。

变更说明（2025-03-08 / Codex）：更新进度与验证结果，补充回归脚本输出。
