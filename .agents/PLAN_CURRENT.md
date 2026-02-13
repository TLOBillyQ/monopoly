# 基础屏托管光效与调试屏开关可执行计划

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `/Users/billyq/Dev/Github/Lua/monopoly/.agents/PLANS.md` 维护。

## 目的 / 全局视角

把“基础屏-AI托管光效”绑定到本地角色玩家的托管状态，同时把“基础_行动日志按钮”作为调试屏的单击开关（仅本地角色生效）。完成后，玩家能在基础屏直观看到托管开关状态，也可用行动日志按钮快速切换调试屏。验证方式是：在基础屏切换托管开关时光效跟随显隐；点击行动日志按钮仅本地调试屏显隐；“图片_82”的 10 连点逻辑仍可用。

## 进度

- [x] (2025-03-08 08:12Z) 清空旧计划并建立新计划骨架。
- [x] (2025-03-08 08:16Z) 实现基础屏 AI 托管光效显隐逻辑。
- [x] (2025-03-08 08:20Z) 接入行动日志按钮切换调试屏（本地角色）。
- [ ] (2025-03-08 08:20Z) 自测基础屏托管与调试屏显隐。

## 意外与发现

- 暂无。

## 决策日志

- 决策：托管光效仅跟随“本地角色玩家”状态，无法映射时隐藏。
  理由：与“本地角色生效”要求一致，避免观战或无映射角色误显示。
  日期/作者：2025-03-08 / Codex

- 决策：调试屏显隐通过 `UIManager.client_role` 仅本地切换。
  理由：UI 事件广播默认全角色，使用本地 client_role 更稳妥地控制本地显隐。
  日期/作者：2025-03-08 / Codex

## 结果与复盘

已完成代码改动，尚未进行人工验证。

## 背景与导读

基础屏 UI 节点由 `Data/UIManagerNodes.lua` 提供，显示/隐藏与触控设置由 `UIRuntimePort` 与 UIManager 节点访问完成。托管状态来源于 `player.auto` 字段，经 `UIModelProjection.build_auto_enabled_by_player` 生成 `ui_model.auto_enabled_by_player`。基础屏 UI 刷新由 `UIPanelPresenter.refresh` 执行，调试屏显隐由 `UIView.set_debug_visible` 控制。

术语解释：
- “本地角色玩家”指 `UIRoleContext.resolve` 结果中的 `role_id` 映射到玩家时的角色。
- “托管开关”指 `player.auto` 的布尔值。

## 工作计划

先扩展 `UIPanelPresenter.refresh`，在 per-role 刷新流程中同步 `基础屏-AI托管光效` 的显示状态。状态取自 `ui_model.auto_enabled_by_player`，按 `UIRoleContext.resolve` 计算的 `role_id` 映射，无法映射时隐藏。必要时新增小的私有函数用于计算“本地角色玩家”的托管状态，避免逻辑散落。

随后修改 `UIEventRouter._build_route_specs`，新增 `基础_行动日志按钮` 的路由。点击后切换调试屏显示/隐藏，但仅对本地角色生效：通过 `UIManager.client_role` 设置到当前点击的 `data.role`，并调用 `UIView.set_debug_visible`。保持原有“图片_82” 10 连点逻辑不变。

最后补充简要自测步骤，验证托管光效与调试屏显隐符合预期。

## 具体步骤

1) 托管光效显隐

在 `src/presentation/ui/UIPanelPresenter.lua` 中新增私有函数，基于 `ui_model.auto_enabled_by_player` 与 `UIRoleContext.resolve` 计算 `基础屏-AI托管光效` 的可见性。把该函数放入 `refresh` 的 `runtime.for_each_role_or_global` 循环内执行，确保 per-role 生效。

2) 行动日志按钮切换调试屏

在 `src/presentation/interaction/UIEventRouter.lua` 的 `_build_route_specs` 中新增一条路由，name 为 `基础_行动日志按钮`，点击后调用新的 `_toggle_debug_visible_for_role`。该函数将 `UIManager.client_role` 临时设置为 `data.role`（若为 nil 则使用当前值），再调用 `UIView.set_debug_visible` 切换显隐。

3) 自测

进入基础屏：
- 点击“托管按钮”，本地角色 `基础屏-AI托管光效` 随托管开关显隐。
- 点击“基础_行动日志按钮”，调试屏本地显隐切换，其他角色不受影响。
- “图片_82” 10 连点仍可切换调试屏。

## 验证与验收

人工验收即可：按“自测”步骤观察 UI 行为。若需回归，可运行 `.agents/tests/` 下既有脚本，但本次不强制。

## 可重复性与恢复

变更为纯 UI 显隐逻辑，可重复执行。若行为异常，回退对应函数改动即可恢复。

## 产物与备注

改动文件：

    src/presentation/ui/UIPanelPresenter.lua
    src/presentation/interaction/UIEventRouter.lua
    src/presentation/api/UIView.lua
    src/presentation/interaction/UIEventState.lua
    src/game/flow/turn/TickUISync.lua

## 接口与依赖

- `UIView.set_debug_visible(state, visible)` 继续作为调试屏显隐入口。
- `UIRoleContext.resolve(role, ui_model, { runtime = runtime })` 用于本地角色映射。

变更说明（2025-03-08 / Codex）：创建新计划并准备实现托管光效与调试屏切换。

变更说明（2025-03-08 / Codex）：更新进度与产物列表，记录已完成实现。
