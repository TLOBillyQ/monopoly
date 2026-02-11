# 行动按钮等待倒计时与超时自动推进

本可执行计划是活文档。实施过程中必须持续更新“进度”“意外与发现”“决策日志”“结果与复盘”。

本文件遵循 `.agents/PLANS.md`。

## 目的 / 全局视角

完成后，玩家进入回合、等待按下“行动按钮”的空档会显示倒计时，并在超时后自动触发“行动按钮”。验收方式是进入游戏观察基础屏倒计时从满值开始递减，超时自动推进回合，且在弹窗/选择期间倒计时切换为对应逻辑。

## 进度

- [x] (2026-02-11 15:00) 清空并写入 `.agents/PLAN_CURRENT.md`
- [x] (2026-02-11 15:00) 增加行动按钮等待计时与超时自动触发
- [x] (2026-02-11 15:00) 倒计时展示覆盖行动按钮等待阶段
- [x] (2026-02-11 15:00) 增加/调整回归测试
- [ ] (2026-02-11 15:02) 运行回归并做手动验收（已完成：回归；剩余：手动验收）

## 意外与发现

暂无。

## 决策日志

- 决策：行动按钮等待倒计时使用 `Config.Generated.Constants.action_timeout_seconds`。
  理由：复用现有超时配置，避免新增字段与配置分散。
  日期/作者：2026-02-11 / Codex

- 决策：倒计时超时自动派发 `ui_button` 的 `next`。
  理由：与选择/弹窗超时一致，保证回合能自动推进。
  日期/作者：2026-02-11 / Codex

- 决策：倒计时仅在基础屏可操作状态下生效（无选择/市场/弹窗、未输入锁）。
  理由：避免与选择/弹窗倒计时冲突，也避免动画期间误触发。
  日期/作者：2026-02-11 / Codex

## 结果与复盘

已完成行动按钮等待计时、超时自动派发与倒计时展示接入，并新增回归测试覆盖自动推进与输入锁场景。回归脚本已通过，仍需手动验收倒计时与自动推进表现。

## 背景与导读

回合逻辑由 `src/game/turn/GameplayLoop.lua` 驱动，选择与弹窗超时由 `src/game/turn/TickTimeout.lua` 处理，倒计时显示由 `src/game/turn/TickUISync.lua` 计算并写入 `game.turn.countdown_seconds`。当前倒计时只在 `pending_choice` 或 `popup_active` 时激活，基础屏等待“行动按钮”时没有倒计时。行动按钮派发发生在 `src/game/turn/TurnDispatch.lua`，点击 `next` 会调用 `game:advance_turn()`。

## 工作计划

先在状态对象中新增“行动按钮等待”计时字段，并在 `GameplayLoop.tick` 中统一维护计时与超时自动派发。随后在 `TickUISync.update_countdown` 中补上该阶段倒计时显示。最后在 `gameplay` 测试套件中新增回归用例，覆盖“等待阶段超时会自动派发 next”和“输入锁时不会自动派发”。

## 具体步骤

工作目录为 `C:\Users\Lzx_8\Desktop\dev\monopoly`。先清空 `.agents/PLAN_CURRENT.md` 并写入本计划内容。接着修改 `src/app/init.lua` 在 `_build_state()` 中新增 `action_button_elapsed` 与 `action_button_active` 初始化字段，并在 `src/game/turn/GameplayLoop.lua` 中加入行动按钮等待计时逻辑：仅当基础屏可操作且无选择/弹窗时递增 `action_button_elapsed`，达到 `action_timeout_seconds` 后自动派发 `{ type = "ui_button", id = "next", actor_role_id = game.turn.current_player_index }`，同时重置计时。随后在 `src/game/turn/TickUISync.lua` 的 `update_countdown` 中新增分支，当 `action_button_active` 为真时使用 `action_button_elapsed` 计算剩余秒数并更新 `countdown_seconds`。最后更新 `.agents/tests/suites/gameplay.lua` 增加用例，模拟等待阶段超时触发 `game:advance_turn()`，并确保输入锁时不触发。

## 验证与验收

运行 `lua .agents/tests/regression.lua`，预期全部通过。进入游戏后观察基础屏倒计时在等待行动按钮阶段从满值递减，计时归零时自动推进回合；在选择/弹窗出现时倒计时应切换为对应选择/弹窗计时；动画输入锁期间不自动派发。

## 可重复性与恢复

改动可重复执行。若需要回滚，可对涉及文件执行 `git checkout -- <file>` 并重新运行回归脚本。

## 产物与备注

本次改动涉及以下文件：`src/app/init.lua`、`src/game/turn/GameplayLoop.lua`、`src/game/turn/TickUISync.lua`、`.agents/tests/suites/gameplay.lua`、`.agents/PLAN_CURRENT.md`。

回归输出摘要：
  All regression checks passed (100)

## 接口与依赖

新增状态字段：`action_button_elapsed`（数值，单位秒），`action_button_active`（布尔）。这些字段仅在 UI 运行态使用，不对外暴露公共 API。行动按钮超时仍使用 `Config.Generated.Constants.action_timeout_seconds`。

修改说明：更新进度与结果，补充回归通过证据并保留手动验收待办。
