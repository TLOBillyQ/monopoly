# 建筑升级屏正文改为“购买/加盖 + 地块名？”

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `.agents/PLANS.md` 维护。

## 目的 / 全局视角

玩家在落地后的建筑升级屏（买地/加盖二选一）看到的正文，直接变为“购买 福州路？”或“加盖 福州路？”这类问题句式，帮助快速理解当前操作对象。实现后打开建筑升级屏，正文不再显示原有说明文字，而是只显示“购买/加盖 + 地块名 + ？”。

## 进度

- [x] (2026-02-14 03:32Z) 明确建筑升级屏与落地可选效果的数据流。
- [x] (2026-02-14 03:32Z) 在 UI 渲染层新增正文替换逻辑，仅作用于买地/加盖选择屏。
- [ ] (2026-02-14 03:32Z) 运行验证脚本并记录结果。

## 意外与发现

暂无。

## 决策日志

- 决策：建筑升级屏正文完全替换为“购买/加盖 地块名？”不保留原正文。
  理由：符合需求，信息更聚焦。
  日期/作者：2026-02-14 / Codex
- 决策：仅影响“落地可选效果”形成的买地/加盖二选一建筑升级屏。
  理由：避免误伤其它选择场景，风险最小。
  日期/作者：2026-02-14 / Codex

## 结果与复盘

待验证补充：实际 UI 展示效果、测试结果与是否存在兼容性问题。

## 背景与导读

建筑升级屏由 `src/presentation/ui/ChoiceScreenRenderer.lua` 的 `open_building_screen` 渲染标题与正文。落地可选效果（买地/加盖）在 `src/game/systems/effects/EffectPipeline.lua` 组装 `choice_spec`，并在 `meta` 中携带 `tile_id`。UI 侧选择数据由 `src/presentation/state/UIModelProjection.lua` 通过 `src/presentation/ui/UIChoice.lua` 生成 `choice` 视图，建筑升级屏正文目前直接使用 `choice.body`。

## 工作计划

在 `ChoiceScreenRenderer` 中新增私有函数用于构建建筑升级屏正文：仅当 `route_policy.is_building_choice(choice)` 为 true 时生效，读取 `choice.meta.tile_id` 通过 `game.board:get_tile_by_id(tile_id)` 获取地块名，根据选中 option id 决定动词（`buy_land` → “购买”，`upgrade_land` → “加盖”），返回单行正文“购买 {tile.name}？”或“加盖 {tile.name}？”。若信息缺失则回退为原 `choice.body`，不抛错。随后在 `open_building_screen` 设置 `screen.body` 时改用该函数返回值。

## 具体步骤

在仓库根目录编辑 `src/presentation/ui/ChoiceScreenRenderer.lua`，新增 `_build_building_screen_body(choice, game, selected_option_id)`，并在 `open_building_screen` 使用其结果赋值正文。完成后执行以下命令进行最小验证，并记录输出。

    lua .agents/tests/gameplay_loop_no_ui.lua

## 验证与验收

落地触发买地/加盖选择屏，正文显示“购买 地块名？”或“加盖 地块名？”，不再显示旧正文。若选项切换，正文随选项更新。最小测试脚本运行无新增失败。

## 可重复性与恢复

改动仅涉及 UI 渲染逻辑，可重复执行。若出现异常，回退 `src/presentation/ui/ChoiceScreenRenderer.lua` 相关改动即可恢复原行为。

## 产物与备注

本次修改涉及 `src/presentation/ui/ChoiceScreenRenderer.lua` 与 `.agents/PLAN_CURRENT.md`。

## 接口与依赖

复用 `src/presentation/interaction/UIChoiceRoutePolicy.is_building_choice(choice)` 判断范围，依赖 `game.board:get_tile_by_id(tile_id)` 获取地块名，不新增外部依赖，不修改公共接口。

变更说明（2026-02-14 / Codex）：重写计划为建筑升级屏正文改造，记录当前进度与待验证步骤。
