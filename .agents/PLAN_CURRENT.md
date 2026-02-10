# 相机逻辑清理与 1s 原位阻断（仅保留回合切换跟随）

本可执行计划是活文档。实施过程中持续更新“进度”“意外与发现”“决策日志”“结果与复盘”。

本文件遵循 `.agents/PLANS.md`。

## 目的 / 全局视角

本次改动要把非回合切换相机逻辑全部删除，只保留“回合切换时相机跟随当前玩家”。原先依赖焦点相机的流程停顿，改成在同一触发点通过 `action_anim.duration` 阻断 1 秒（默认来自 `Config/GameplayRules.lua` 的 `action_anim_default_seconds`）。

用户可见结果：

1. 回合切换仍会触发跟随。
2. 道具/事件不再触发聚焦玩家或格子，也不再做锁相机/恢复相机。
3. 原有焦点节点仍会阻断流程约 1 秒。

## 进度

- [x] (2026-02-10 18:08Z) 清空并重写 `PLAN_CURRENT.md`，建立本次活文档。
- [x] (2026-02-10 18:15Z) 移除 `CameraFocus` 链路与运行时状态字段。
- [x] (2026-02-10 18:18Z) 删除全部 `focus_target_*` 字段，并在原位补 `duration`。
- [x] (2026-02-10 18:23Z) 更新相关回归测试（`ui.lua`、`item.lua`）。
- [x] (2026-02-10 18:25Z) 运行 `lua .agents/tests/regression.lua` 并修正失败用例。
- [x] (2026-02-10 18:26Z) 完成结果复盘与计划收尾。

## 意外与发现

- 观察：首轮回归失败于 `ui.lua` 新增测试，`camera_helper.target_role_id` 为 `nil`。
  证据：`turn switch should follow current player | expected=2 got=nil`。

- 观察：失败原因是该 tick 只触发倒计时增量刷新，命中“仅倒计时更新”分支，未走 `_refresh_view`，因此不会触发跟随事件。
  证据：将测试状态加 `ui_dirty = true` 后通过。

## 决策日志

- 决策：阻断范围采用“替代原焦点动画”而非扩大到全部动作动画。
  理由：与需求“原位阻断”一致，影响面最小。
  日期/作者：2026-02-10 / Codex

- 决策：清理强度采用“连字段一起删”。
  理由：避免残留无效字段导致后续误用。
  日期/作者：2026-02-10 / Codex

- 决策：1 秒来源使用 `GameplayRules.action_anim_default_seconds`。
  理由：满足当前 1 秒需求且保留配置弹性。
  日期/作者：2026-02-10 / Codex

## 结果与复盘

- 已完成目标：非回合切换相机逻辑已移除，回合切换跟随保留，原焦点节点改为 `duration` 阻断。
- 已完成验证：仓库中不再出现 `focus_target_player_id` 与 `focus_target_tile_index`；`src/ui/CameraFocus.lua` 已删除；全量回归通过。
- 回归结果：`lua .agents/tests/regression.lua` 输出 `All regression checks passed (83)`。
- 经验：`TickUISync` 的相机跟随触发在 `_refresh_view` 内，测试需要显式保证进入该路径。

## 背景与导读

当前相机相关逻辑分两条路径：

1. 回合切换跟随：位于 `src/game/turn/TickUISync.lua`，按 `(turn_count, current_player_id)` 触发跟随事件。
2. 动作焦点相机：位于 `src/ui/CameraFocus.lua`，由 `src/ui/ActionAnim.lua` 调用，根据 `focus_target_player_id` 或 `focus_target_tile_index` 进行聚焦与恢复。

回合流程阻断通过 `TurnFlow` 的 `wait_action_anim` 状态实现，动画时长由 `ActionAnim.play` 返回值驱动 `SetTimeOut`。因此改动只需更换 action payload，不改 `TurnFlow` 状态机。

## 工作计划

先删除焦点相机模块引用与状态字段，保证项目中不再依赖该模块。随后逐个清理所有 action payload 的 `focus_target_*` 字段，并在同一位置补齐 `duration = gameplay_rules.action_anim_default_seconds`（已有 `duration` 的保持不变）。

接着修改 `TickUISync`，移除对 `state.camera_focus_active` 的耦合判断，保持仅回合切换跟随。最后更新回归测试：删除焦点相关用例，改为验证“无焦点字段 + 有 duration + 回合切换仍跟随”。

## 具体步骤

在仓库根目录执行：

1. 编辑与删除代码文件：
   - `src/ui/CameraFocus.lua`（删除）
   - `src/ui/ActionAnim.lua`
   - `src/app/init.lua`
   - `src/game/turn/TickUISync.lua`
   - `src/game/item/ItemPostEffects.lua`
   - `src/game/item/ItemRoadblock.lua`
   - `src/game/item/ItemSteal.lua`
   - `src/game/item/ItemExecutor.lua`
   - `src/game/item/ItemDemolish.lua`
   - `src/game/item/ItemRegistry.lua`
   - `src/game/chance/ChanceRegistry.lua`
   - `src/game/land/Landing.lua`
   - `src/game/land/Land.lua`
   - `src/game/effect/MineEffect.lua`

2. 更新测试：
   - `.agents/tests/suites/ui.lua`
   - `.agents/tests/suites/item.lua`

3. 运行回归：

       lua .agents/tests/regression.lua

## 验证与验收

必须同时满足：

1. 代码中不再出现 `focus_target_player_id` 与 `focus_target_tile_index`。
2. `src/ui/CameraFocus.lua` 已删除且无引用。
3. 回合切换仍触发相机 follow。
4. 相关 action payload 提供 `duration`，默认值取 `action_anim_default_seconds`。
5. `lua .agents/tests/regression.lua` 全通过。

## 可重复性与恢复

本次改动是纯代码与测试修改，可重复执行。若回归失败，按失败用例定位并仅修复与本计划相关代码。若需回退，直接用 git 还原本次修改文件。

## 产物与备注

关键输出：

    $ lua .agents/tests/regression.lua
    ...................................................................................
    All regression checks passed (83)

## 接口与依赖

内部 action payload 变更：

- 删除字段：`focus_target_player_id`、`focus_target_tile_index`
- 统一使用：`duration` 作为流程阻断时长

依赖不新增；继续使用现有模块：`TurnFlow`、`TurnAnim`、`ActionAnim`、`GameplayRules`。

---

变更记录（2026-02-10 / Codex）：新建本计划，明确“删除焦点相机 + 原位 1s 阻断 + 回归验证”的完整实施路径。
变更记录（2026-02-10 / Codex）：完成全部实现与回归，补充失败定位过程、修复动作与最终验收结果。
