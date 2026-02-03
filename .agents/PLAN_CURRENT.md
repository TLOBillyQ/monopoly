# 动作动画生成道具 prefab 并维护障碍物可视状态

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。本文件必须遵循仓库内 `.agent/PLANS.md` 的规范维护。

## 目的 / 全局视角


玩家在使用路障、地雷、导弹、清障卡时，动作动画会在目标格子生成对应的 prefab，并在障碍物被清除或触发时同步移除。验收方式是：使用道具能看到模型出现，触发清除或爆炸后模型消失，且回合流程不改变。

## 进度


- [x] (2026-02-03 19:05) 清空并重写 `.agent/PLAN_CURRENT.md` 为本计划
- [x] (2026-02-03 19:05) 修改 `src/ui/ActionAnim.lua` 支持生成与清理 prefab
- [x] (2026-02-03 19:05) 修改 `src/game/turn/GameplayLoop.lua` 传入 `state`
- [x] (2026-02-03 19:05) 新增地雷触发事件并在 UI 清理地雷/路障模型
- [x] (2026-02-03 19:06) 运行 `lua .agent/tests/regression.lua` 并确认通过

## 意外与发现


- 观察：`regression.lua` 环境没有 `math.Vector3`，直接加载 `ActionAnim.lua` 会报错。
  证据：`Macro.lua:1: attempt to call field 'Vector3' (a nil value)`

## 决策日志


- 决策：路障/地雷 prefab 作为持久障碍物，清障卡、导弹、路障触发、地雷引爆时移除对应模型。
  理由：与需求一致，保证视觉与棋盘覆盖物状态同步。
  日期/作者：2026-02-03 / Codex。

- 决策：清障机器人在使用者所在格生成，动画结束后销毁。
  理由：按指定行为，实现简单且清晰。
  日期/作者：2026-02-03 / Codex。

- 决策：地雷 prefab 优先读取 `prefab.group/unit["地雷"]`，不存在则提示并跳过创建。
  理由：当前配置缺失地雷 prefab，按容错策略处理。
  日期/作者：2026-02-03 / Codex。

- 决策：UI 事件处理中延迟加载 `ActionAnim.lua`。
  理由：避免回归脚本环境缺少 `math.Vector3` 导致加载失败。
  日期/作者：2026-02-03 / Codex。

## 结果与复盘


已完成动作动画生成 prefab、障碍物清理与地雷触发事件联动，回归脚本通过。待手动验证道具视觉表现与高度偏移，如需调整可在 `ActionAnim.lua` 中统一修改偏移量。

## 背景与导读


动作动画由 `src/ui/ActionAnim.lua` 负责，游戏层在 `src/game/turn/GameplayLoop.lua` 的 `wait_action_anim` 阶段调用它。棋盘场景由 `src/ui/BoardScene.lua` 初始化，格子单位可通过 `scene.tiles[index]` 获取位置。建筑升级效果在 `src/ui/BuildingEffects.lua` 使用 `GameAPI.create_unit_group` 创建 prefab，可作为参考。

## 工作计划


先改 `ActionAnim.play` 以接收 `state`，从而访问棋盘场景与玩家信息。再加入 prefab 生成与清理逻辑：路障、地雷保存到 `scene.overlay_units` 中，导弹与清障机器人在动画时长结束后销毁。最后新增地雷触发事件与 UI 清理逻辑，并修正回归环境加载问题。

## 具体步骤


在仓库根目录执行以下修改与验证：

    1) 编辑 src/ui/ActionAnim.lua，新增 prefab 生成/清理逻辑，并对外提供 clear_overlay。
    2) 编辑 src/game/turn/GameplayLoop.lua，调用 action_anim.play(state, anim)。
    3) 编辑 src/game/MonopolyEvents.lua，新增 land.mine_hit。
    4) 编辑 src/game/effect/MineEffect.lua，在地雷引爆时触发事件。
    5) 编辑 src/ui/UIEventHandlers.lua，监听 roadblock_hit 与 mine_hit 并清理模型，同时延迟加载 ActionAnim。
    6) 运行 lua .agent/tests/regression.lua。

## 验证与验收


已运行：

    工作目录：仓库根目录
    命令：lua .agent/tests/regression.lua
    预期：All regression checks passed (34)

手动验收要点：

    1) 使用路障卡，目标格子出现路障模型；玩家触发路障后模型消失。
    2) 使用地雷卡，脚下出现地雷模型；触发地雷后模型消失。
    3) 使用导弹卡，目标格子出现导弹效果并在动画结束后消失，同时路障/地雷模型被清理。
    4) 使用清障卡，清障机器人在玩家格子出现并消失，被清除的格子上路障/地雷模型移除。

## 可重复性与恢复


本修改可重复执行。若需回退，恢复 `src/ui/ActionAnim.lua`、`src/game/turn/GameplayLoop.lua`、`src/game/MonopolyEvents.lua`、`src/game/effect/MineEffect.lua`、`src/ui/UIEventHandlers.lua` 到修改前版本即可。

## 产物与备注


新增的视觉覆盖物存放在 `scene.overlay_units.roadblocks/mines`。动作动画仍保留原有提示文本，新增 prefab 仅在动作动画触发时生成。

## 接口与依赖


`src/ui/ActionAnim.lua` 暴露 `action_anim.play(state, anim)` 与 `action_anim.clear_overlay(state, kind, tile_index)`。`src/game/MonopolyEvents.lua` 新增 `land.mine_hit` 事件。依赖 `Data/Prefab.lua` 中的 `路障`、`清障机器人`、`导弹` prefab，地雷 prefab 缺失时会提示并跳过创建。

变更记录：2026-02-03 19:06 完成本计划并更新结果，原因是已实现全部修改并通过回归脚本。
