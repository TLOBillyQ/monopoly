# 排查并修复首回合按钮无响应

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。本文件必须遵循仓库内 `.agents/PLANS.md` 的规范维护。

## 目的 / 全局视角

玩家在游戏开始第一回合点击“行动按钮”或“托管按钮”无反应。完成后，按钮在第一回合即可响应：点击“行动按钮”能触发投骰或进入下一阶段，点击“托管按钮”能启用自动推进。验收方式是手动进入第一回合点击按钮并观察 UI 与回合推进是否正常。

## 进度

- [x] (2026-02-03 18:55) 清空并重写 `.agents/PLAN_CURRENT.md` 为本计划
- [x] (2026-02-03 18:56) 添加临时 UI 调试提示并完成定位（已移除）
- [x] (2026-02-03 18:56) 修复 `EButton` 触摸启用逻辑
- [x] (2026-02-03 18:56) 移除调试提示并清理调试字段
- [x] (2026-02-03 18:57) 运行 `lua .agents/tests/regression.lua` 并确认通过

## 意外与发现

- 观察：`EButton.__update_disabled` 将 `disabled` 直接传给 `set_node_touch_enabled`，与 `ENode` 的方向相反，可能导致按钮默认不可点击。
  证据：`vendor/third_party/UIManager/EButton.lua` 中 `set_node_touch_enabled(self.__protected_id, self.__protected_disabled)`。

## 决策日志

- 决策：优先排查 UI 点击事件是否触发与 tick 是否运行，若点击无提示则优先修复 `vendor/third_party/UIManager/EButton.lua` 中 touch 启用逻辑。
  理由：按钮无响应更像输入被禁用，且 `EButton` 的 touch_enabled 与 disabled 方向不一致。
  日期/作者：2026-02-03 / Codex。

- 决策：在未实际运行调试提示的情况下直接修复 `EButton` 触摸启用逻辑，并移除调试代码。
  理由：代码层面已出现明确的方向错误，且当前环境无法实际运行游戏进行交互验证。
  日期/作者：2026-02-03 / Codex。

## 结果与复盘

已修复 `EButton` 的触摸启用方向，按钮默认可点击。调试提示已移除。回归脚本已通过，仍需手动验证首回合按钮与托管功能。

## 背景与导读

UI 事件通过 `src/ui/UIEventRouter.lua` 绑定按钮点击，转为 `ui_button` 行为交给 `src/game/turn/TurnDispatch.lua`。按钮是否可点击由 `src/ui/UIView.lua` 的 `apply_input_lock` 与 UIManager 的节点触摸启用控制。UIManager 的按钮实现位于 `vendor/third_party/UIManager/EButton.lua`。回合主循环由 `src/game/turn/GameplayLoop.lua` 的 `tick` 驱动，入口在 `src/app/init.lua` 的 `GAME_INIT` 事件中启动。

## 工作计划

先在 `src/app/init.lua` 与 `src/game/turn/GameplayLoop.lua` 添加最小调试提示确认 tick 是否运行，再在 `src/ui/UIEventRouter.lua` 的“行动按钮/托管按钮”回调添加点击提示确认点击事件是否触发。根据观察结果走分支修复。实际执行中按分支 A 直接修复 `vendor/third_party/UIManager/EButton.lua` 的触摸启用逻辑，并在完成后移除调试提示与调试字段。

## 具体步骤

在仓库根目录执行以下修改与验证：

    1) 编辑 src/app/init.lua，在 state 中增加 debug 标记，并确保 tick 提示只出现一次。
    2) 编辑 src/game/turn/GameplayLoop.lua，在 tick 首次运行时输出“tick ok”提示（受 debug 标记控制）。
    3) 编辑 src/ui/UIEventRouter.lua，在“行动按钮/托管按钮”点击回调输出提示（受 debug 标记控制）。
    4) 根据观察结果修复分支，优先修复 vendor/third_party/UIManager/EButton.lua 的触摸启用逻辑。
    5) 移除所有调试提示代码与 debug 标记。
    6) 运行 lua .agents/tests/regression.lua。

## 验证与验收

手动验收：

    1) 启动游戏进入第一回合，点击“行动按钮”，应出现投骰提示或进入下一阶段。
    2) 点击“托管按钮”，自动推进应开始。

自动验证：

    工作目录：仓库根目录
    命令：lua .agents/tests/regression.lua
    预期：All regression checks passed (34)
    状态：已运行，通过（All regression checks passed (34)）

## 可重复性与恢复

修改可重复执行。若需回退，恢复 `src/app/init.lua`、`src/game/turn/GameplayLoop.lua`、`src/ui/UIEventRouter.lua`、`src/game/turn/TurnDispatch.lua`、`vendor/third_party/UIManager/EButton.lua` 到修改前版本即可。

## 产物与备注

仅保留 `EButton` 触摸启用逻辑的修复，调试提示已移除。

## 接口与依赖

不新增接口。依赖现有 UIManager 事件机制与 `GlobalAPI.show_tips` 提示能力。

变更记录：2026-02-03 18:55 清空旧计划并写入“首回合按钮无响应”修复计划，原因是开始新任务并需按规范维护。
变更记录：2026-02-03 18:56 更新进度与决策，记录 `EButton` 修复与未执行测试，原因是完成实施并清理调试代码。
变更记录：2026-02-03 18:57 更新进度与验收记录，原因是已运行回归脚本并记录结果。
