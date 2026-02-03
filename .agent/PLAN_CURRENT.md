# Store 驱动倒计时与脏标记增量刷新


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `/.agent/PLANS.md` 的要求维护。

## 目的 / 全局视角


目标是让 UI 不再每帧全量重建，而是由 Store 的脏标记驱动增量刷新，并新增 1Hz 的倒计时显示。玩家能看到“回合 + 倒计时”始终显示，且在有选择或弹窗时倒计时每秒变化；当没有有效倒计时，显示 0。性能上应减少每帧渲染与 GC。验证方式是运行游戏并观察倒计时变化，同时确认无选择/弹窗时 UI 不再每帧重建。

## 进度


- [x] (2026-02-03 12:20Z) 将现有零散说明整理为可执行计划结构。
- [x] (2026-02-03 12:40Z) 更新 Store 脏标记结构与版本号，并确保通过 Store:set 触发。
- [x] (2026-02-03 12:50Z) 在初始状态加入倒计时字段，并在 GameplayLoop 中按 1Hz 更新并写入 Store。
- [x] (2026-02-03 13:00Z) 增加 UIModel 的增量更新入口，调整 UIPanel 文案与 UIView 的局部刷新。
- [x] (2026-02-03 13:05Z) 更新 GameplayLoop 以脏标记触发刷新，并在 UI 状态变化时置 ui_dirty。
- [x] (2026-02-03 13:10Z) 自测与验收记录。

## 意外与发现


- 观察：回归脚本中 UI 层无 `ui` 字段时，倒计时局部刷新会报错。
  证据：`regression.lua: tick should not error without anim: src/ui/UIView.lua:122: attempt to call method 'set_label' (a nil value)`

## 决策日志


- 决策：先将计划改为 PLANS 规范格式，再开始实现。
  理由：PLANS.md 要求执行过程中持续维护可执行计划，避免后续无法按要求更新。
  日期/作者：2026-02-03 Codex
- 决策：`refresh_turn_label` 在缺失 `ui` 时直接返回。
  理由：测试环境 UI 为空时不应阻塞逻辑，且运行时 UI 正常存在。
  日期/作者：2026-02-03 Codex

## 结果与复盘


已完成 Store 脏标记、倒计时 1Hz 写入与 UI 增量刷新。倒计时展示为“回合: X | 倒计时: Y”，仅倒计时变化时刷新标签，其他变更由脏标记触发更新。回归脚本通过。后续若需要进一步降低刷新成本，可继续细分 UIView 的局部刷新接口。

## 背景与导读


当前 UI 每帧通过 `src/game/turn/GameplayLoop.lua` 调用 `src/ui/UIView.lua` 全量渲染，`src/ui/UIModel.lua` 每次构建完整模型。Store 仅提供 get/set，没有脏标记；多数状态更新通过 Store:set，但 `src/game/game/GameState.lua` 中的若干写入直接修改 Store 状态。倒计时目前只用于超时逻辑，不在 UI 中展示。

本次改动涉及：
`src/core/Store.lua` 增加 version/dirty 与 consume_dirty。
`src/game/game/CompositionRoot.lua` 初始状态加入 `turn.countdown_seconds`。
`src/game/turn/GameplayLoop.lua` 增加倒计时更新与脏标记驱动刷新。
`src/game/game/GameState.lua` 的写入改用 Store:set 以触发脏标记。
`src/ui/UIModel.lua` 增加增量更新入口。
`src/ui/UIPanel.lua` 改为显示回合与倒计时。
`src/ui/UIView.lua` 增加只刷新倒计时标签的能力，并在弹窗/选择框开关时置 ui_dirty。

术语说明：
“脏标记”是一个记录哪些状态被修改的结构，用来决定 UI 需要刷新的部分。“增量刷新”是指只更新受影响的 UI 片段，而不是重建全部 UI 模型和视图。

## 工作计划


先修改 Store，让每次 `Store:set` 都能记录路径对应的脏标记，并提供 `consume_dirty` 取出并重置脏状态。接着在初始状态加入 `turn.countdown_seconds` 字段，并在 GameplayLoop 内依据 `pending_choice_elapsed` 或 `ui_modal_elapsed` 按 1Hz 计算倒计时，只有变化时才写回 Store。然后调整 UIModel 与 UIPanel：让回合标签包含倒计时，并提供 `ui_model.update` 以根据脏标记更新局部数据。UIView 增加只更新倒计时标签的方法，并在选择框/弹窗的打开关闭处置 `ui_dirty`。最后修改 GameplayLoop 的渲染逻辑：读取脏标记并决定是否刷新，且在仅倒计时变化时只刷新标签，其他情况使用增量更新或全量更新。完成后进行本地脚本自测并记录结果。

## 具体步骤


1. 编辑 `src/core/Store.lua`：
   - 在 `store:init` 初始化 `version` 与 `dirty`，提供一个创建初始脏结构的内部函数。
   - 在 `store:set` 中根据 path 设置脏标记与 version，并记录玩家 inventory 的 pid。
   - 新增 `store:consume_dirty()`，返回当前脏标记并重置为初始结构。
2. 编辑 `src/game/game/CompositionRoot.lua`：
   - 在 `_build_initial_state` 的 `turn` 中加入 `countdown_seconds = 0`。
3. 编辑 `src/game/game/GameState.lua`：
   - 将写入 `store.state` 的位置改为使用 `self.store:set`，确保脏标记被触发，行为保持不变。
4. 编辑 `src/ui/UIPanel.lua` 与 `src/ui/UIModel.lua`：
   - `build_turn_label` 改为接收 `turn_count` 与 `countdown_seconds`。
   - `ui_model.build` 传入倒计时并生成新文案。
   - 新增 `ui_model.update(prev, store_state, env, dirty)`，按脏标记更新 panel、board、item_slots、choice、market、popup。
5. 编辑 `src/ui/UIView.lua`：
   - 新增 `refresh_turn_label(layer, label_text)`，只更新倒计时标签。
   - 在 `open_choice_modal`、`close_choice_modal`、`push_popup`、`close_popup` 中设置 `layer.ui_dirty = true`。
6. 编辑 `src/game/turn/GameplayLoop.lua`：
   - 新增 `_update_countdown(game, state)`，按规则计算倒计时并写入 Store。
   - 在 `tick` 中调用倒计时更新，读取 `store:consume_dirty()`，并按脏标记决定刷新范围；仅倒计时变化时只刷新标签。
   - 在 `dispatch_action` 中对 UI 相关动作设置 `state.ui_dirty = true`。
   - 初始化或切换游戏时设置 `state.ui_dirty = true` 以触发首次渲染。
7. 运行自测（工作目录为仓库根）：
   - `lua .agent/tests/regression.lua`

## 验证与验收


运行 `lua .agent/tests/regression.lua`，预期脚本正常执行且无报错。进入游戏后观察：
- 无选择/弹窗时，倒计时显示为 0，UI 不再每帧全量刷新。
- 出现选择或弹窗时，倒计时按秒递减，格式为 “回合: X | 倒计时: Y”。
- 倒计时为 0 时，现有超时逻辑与原行为一致。

## 可重复性与恢复


所有修改均为代码变更，可重复应用。若出现 UI 不刷新或倒计时异常，可回滚到修改前版本并重新执行步骤。无需数据迁移。

## 产物与备注


测试输出节选：
  All regression checks passed (32)

## 接口与依赖


新增接口：`Store:consume_dirty()`。
新增字段：`Store.version`、`Store.dirty`、`store.state.turn.countdown_seconds`。
新增函数：`ui_model.update(prev, store_state, env, dirty)`、`ui_view.refresh_turn_label(layer, label_text)`。
调整函数签名：`panel.build_turn_label(turn_count, countdown_seconds)`。

变更说明：更新进度与验收结果，补充测试发现与处置记录。
