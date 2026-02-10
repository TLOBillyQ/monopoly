# 基础屏隐藏扩展与托管本地化（不依赖当前回合）

本可执行计划是活文档。实施过程中持续维护“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `/.agents/PLANS.md` 维护。

## 目的 / 全局视角

本次改造解决两个直接体验问题：一是基础屏在“不可操作/输入锁定”时只隐藏了部分节点，容易残留孤立文案；二是托管按钮之前受当前回合和全局开关影响，不能稳定表达“只控制本客户端玩家”。改造后，基础屏隐藏范围扩展到周边 label，托管按钮始终保持可见并按点击者玩家切换 `player.auto`，不再改整局全局开关。

## 进度

- [x] (2026-02-10 03:35Z) 完成现状排查：确认 `auto` 仍走当前回合校验，且依赖 `ui.auto_play` 全局开关。
- [x] (2026-02-10 03:42Z) 完成 `UIModel` 改造：新增玩家级托管状态映射与托管文案映射。
- [x] (2026-02-10 03:47Z) 完成 `UIView` 改造：新增基础屏隐藏组、周边 label 隐藏、托管例外、输入锁定例外。
- [x] (2026-02-10 03:50Z) 完成 `TurnDispatch` 改造：`auto` 改为玩家级切换，`next/item_slot` 保持当前回合强校验。
- [x] (2026-02-10 03:52Z) 完成 `AutoRunner/GameplayLoop/UIEventRouter` 联动：输入锁定下放行 `auto`，自动推进改看 `current_player_auto`。
- [x] (2026-02-10 03:57Z) 完成 `ui/gameplay` 用例更新与新增，共 60 条回归通过。
- [x] (2026-02-10 03:58Z) 完成 UI 文档同步（`01_UI_基础屏.md`、`00_UI_架构与画布.md`）。

## 意外与发现

- 观察：`apply_input_lock` 新增 role 迭代后，在测试环境 `UIManager` 为空会直接报错。
  证据：`attempt to index global 'UIManager' (a nil value)`。
- 处理：给 `_set_client_role` 增加空保护，避免无 UI 运行环境崩溃。
- 观察：`AutoRunner` 新增 `current_player_auto` 条件后，会连带影响 `ai_turn_runner`。
  证据：AI 自动推进用例失败，返回 `nil`。
- 处理：`step_ai_turn_runner` 显式设置 `ctx.current_player_auto = true`，保持 AI 通道原语义。

## 决策日志

- 决策：保留 `ui.auto_play` 字段作为兼容字段，不作为托管核心状态。
  理由：最小化对既有状态结构和外部引用的冲击，托管新语义完全迁移到 `player.auto`。
  日期/作者：2026-02-10 / Codex
- 决策：基础屏隐藏触发定义为“不可操作或输入锁定”，并把倒计时 label 纳入隐藏组。
  理由：与现有“可操作性”语义一致，避免 UI 残留文本。
  日期/作者：2026-02-10 / Codex
- 决策：托管控件（按钮+状态 label）作为显式例外，不参与隐藏组且输入锁定不禁用。
  理由：满足“托管与当前回合无关、只控制本地玩家”的产品约束。
  日期/作者：2026-02-10 / Codex

## 结果与复盘

改造后，`auto` 点击链路从“全局开关”改为“玩家本地开关”，并增加了 role->player 映射失败的硬拦截；基础屏隐藏覆盖了周边 label，且托管链路保持可见可控（观战禁用）。自动化回归全部通过（60/60），没有扩展到通用选择屏、黑市屏、弹窗屏的语义，范围与目标一致。

## 背景与导读

核心改动跨 4 个层次：

- `src/ui/UIModel.lua`：构建玩家级 UI 数据。
- `src/ui/UIView.lua`：基础屏渲染、隐藏策略、输入锁定行为。
- `src/ui/UIEventRouter.lua` + `src/game/turn/TurnDispatch.lua`：点击意图与权限拦截。
- `src/game/turn/AutoRunner.lua` + `src/game/turn/GameplayLoop.lua`：自动推进触发条件。

测试入口：

- `/.agents/tests/suites/ui.lua`
- `/.agents/tests/suites/gameplay.lua`
- `/.agents/tests/regression.lua`

## 工作计划

先改模型层，把托管状态切到玩家维度，保证每个 role 都能拿到自己的托管文案。再改视图层，把非玩家区隐藏抽成统一分组，并把托管控件做成显式例外。然后改事件与分发：`auto` 不再受当前回合拦截，改为必须映射到有效玩家，`next/item_slot` 继续强校验。最后改自动推进，把“是否自动下一步”绑定到当前玩家 `player.auto`，并回归验证。

## 具体步骤

工作目录：`c:\Users\Lzx_8\Desktop\dev\monopoly`

1. 改模型：
   - 编辑 `src/ui/UIModel.lua`，新增 `auto_enabled_by_player` 与 `panel.auto_label_by_player`。
2. 改视图：
   - 编辑 `src/ui/UIView.lua`，新增 `base_hidden_nodes/base_hidden_labels/auto_control_nodes`；
   - 新增基础屏隐藏 helper 与托管控件独立渲染 helper；
   - 调整 `refresh_panel` 与 `apply_input_lock`。
3. 改事件与分发：
   - 编辑 `src/ui/UIEventRouter.lua`，输入锁定判断改传完整 intent；
   - 编辑 `src/game/turn/TurnDispatch.lua`，拆分 `auto` 与 `next/item_slot` 权限。
4. 改自动推进：
   - 编辑 `src/game/turn/AutoRunner.lua`、`src/game/turn/GameplayLoop.lua`，引入 `current_player_auto` 条件并移除 `ui.auto_play` 控制耦合。
5. 改测试与文档：
   - 编辑 `/.agents/tests/suites/ui.lua`、`/.agents/tests/suites/gameplay.lua`；
   - 编辑 `/.agents/docs/ui/01_UI_基础屏.md`、`/.agents/docs/ui/00_UI_架构与画布.md`。
6. 回归：
       lua .agents/tests/regression.lua

## 验证与验收

- 自动化验收：
  - 运行 `lua .agents/tests/regression.lua`
  - 预期输出：`All regression checks passed (60)`
- 关键行为验收：
  - 非当前回合点击 `auto` 可切换点击者玩家 `player.auto`；
  - 非当前回合点击 `next/item_slot` 被拒绝；
  - 输入锁定时 `auto` 仍可点，`next/item_slot` 仍禁用；
  - 非当前回合基础屏隐藏组（含倒计时 label）隐藏，但托管控件可见。

## 可重复性与恢复

本次改动可重复执行。若需回滚，按文件级回退以下文件并重跑回归：

- `src/ui/UIModel.lua`
- `src/ui/UIView.lua`
- `src/ui/UIEventRouter.lua`
- `src/game/turn/TurnDispatch.lua`
- `src/game/turn/AutoRunner.lua`
- `src/game/turn/GameplayLoop.lua`
- `/.agents/tests/suites/ui.lua`
- `/.agents/tests/suites/gameplay.lua`
- `/.agents/docs/ui/01_UI_基础屏.md`
- `/.agents/docs/ui/00_UI_架构与画布.md`

## 产物与备注

关键验证输出：

    ............................................................
    All regression checks passed (60)

## 接口与依赖

- `UIModel` 新增并稳定：
  - `auto_enabled_by_player: { [player_id]: boolean }`
  - `panel.auto_label_by_player: { [player_id]: string }`
  - 保留兼容 `panel.auto_label`（当前回合玩家文案）
- `TurnDispatch` 权限语义：
  - `ui_button:auto` 不再校验当前回合，改校验 `actor_role_id -> player` 映射
  - `ui_button:next/item_slot_*` 继续校验当前回合
- `AutoRunner` 环境入参新增依赖：
  - `env.current_player_auto`

---

计划更新说明（2026-02-10 03:58Z）：重写为“基础屏隐藏扩展 + 托管本地化”任务计划，并同步记录最终实现与回归结果。
