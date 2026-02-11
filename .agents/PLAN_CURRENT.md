# 修复普通步行动画“立刻瞬移”根因（不回退）

本可执行计划是活文档。实施过程中持续更新“进度”“意外与发现”“决策日志”“结果与复盘”。

本文件遵循 `/.agents/PLANS.md`。

## 目的 / 全局视角

修复“普通步行角色移动时直接瞬移到终点”的问题，不通过关闭行为树或回退旧路径止血。  
改完后，移动动画应保持过程位移；即使移动回调内部异常，也要在日志里能直接看到失败上下文，不再静默吞错。

## 进度

- [x] (2026-02-11 12:10Z) 放宽 `src/ui/PlayerPositioning.lua` 的移动链路高度钳制为 fail-open。
- [x] (2026-02-11 12:14Z) 改 `src/game/turn/TurnAnim.lua`：动画回调异常写结构化错误日志。
- [x] (2026-02-11 12:17Z) 改 `src/ui/MoveAnim.lua`、`src/ui/PlayerMoveBehavior.lua`、`src/ui/PlayerMoveBehaviorStepBuilder.lua`：补时长一致性异常日志。
- [x] (2026-02-11 12:22Z) 改 `/.agents/tests/suites/ui.lua`：新增“缺失 ground 仍移动”“回调异常可观测”用例。
- [x] (2026-02-11 12:24Z) 执行 `lua .agents/tests/regression.lua`，回归通过（107）。

## 意外与发现

- 观察：`TurnAnim.step_anim` 之前用 `pcall`，回调报错后会直接派发 `*_anim_done`，导致外部观感是“动画瞬间结束”。
  证据：代码路径 `src/game/turn/TurnAnim.lua` 中 `pcall` 失败后仍执行 `game:dispatch_action({ type = done_action, ... })`。

- 观察：移动时长为 0 的情况以前没有统一记录，定位“瞬移”只能靠肉眼。
  证据：`MoveAnim`/`PlayerMoveBehavior`/`StepBuilder` 之前均未记录 from/to/len/speed/duration 的异常信息。

## 决策日志

- 决策：`clamp_to_safe_player_pos` 对 ground 缺失采用 fail-open，不抛错，直接返回原坐标。
  理由：移动链路里抛错会触发 `TurnAnim` 的 done 分支，表象就是“立刻瞬移”。
  日期/作者：2026-02-11 / Codex

- 决策：`TurnAnim` 保留“异常不阻塞状态机”的语义，但必须输出完整错误上下文。
  理由：避免卡死局面，同时确保问题可观测、可追踪。
  日期/作者：2026-02-11 / Codex

- 决策：不引入 BT/legacy 回退开关，只补诊断和根因修复。
  理由：遵守“只做根因修复，不做回退”的需求。
  日期/作者：2026-02-11 / Codex

## 结果与复盘

本轮结果：

- 修复了移动链路对 `ground` 的强依赖导致的回调异常风险。
- 动画回调异常会写 `logger.error`，包含 phase、anim_key、seq、player_id、from/to 和错误栈。
- 非预期的“非正移动时长”会在三个层级记录诊断日志，便于快速锁定是“步长计算”还是“步骤构建”。
- 新增回归验证了两个核心行为：缺失 ground 不中断移动；回调异常可观测且流程仍安全结束。

经验：

- “不阻塞状态机”与“可观测性”必须同时存在；只做前者会把故障伪装成业务现象。

## 背景与导读

相关模块关系：

- `src/game/turn/TurnAnim.lua`：负责在 `wait_move_anim / wait_action_anim` 期间驱动动画并派发 done。
- `src/ui/MoveAnim.lua`：移动动画入口，默认走行为树路径。
- `src/ui/PlayerMoveBehavior.lua`：行为树移动会话（准备、分步、收尾）。
- `src/ui/PlayerMoveBehaviorStepBuilder.lua`：按路径生成 step 与 step.duration。
- `src/ui/PlayerPositioning.lua`：玩家落点高度安全钳制。

## 工作计划

先修复“容易导致回调异常”的高度钳制，再补动画回调错误可观测性，随后增加时长一致性日志，最后用回归测试验证“不瞬移 + 可诊断”。

## 具体步骤

工作目录：`C:\Users\Lzx_8\Desktop\dev\monopoly`

1. 修改 `src/ui/PlayerPositioning.lua`：
   - `resolve_min_player_y(scene, opts)` 支持 `allow_missing`。
   - `clamp_to_safe_player_pos(scene, pos)` 在 ground 缺失时 fail-open。
2. 修改 `src/core/Logger.lua`：
   - 新增 `logger.error(...)`。
3. 修改 `src/game/turn/TurnAnim.lua`：
   - 用 `xpcall + traceback` 包裹动画回调。
   - 回调失败时记录结构化错误上下文。
4. 修改 `src/ui/MoveAnim.lua`：
   - 对 `play_sequence` 返回值做非正时长日志。
5. 修改 `src/ui/PlayerMoveBehavior.lua` 与 `src/ui/PlayerMoveBehaviorStepBuilder.lua`：
   - 对会话总时长与 step 时长做异常日志。
6. 修改 `/.agents/tests/suites/ui.lua`：
   - 新增 `_test_move_anim_bt_missing_ground_still_moves`。
   - 新增 `_test_move_anim_callback_error_logged_and_done`。
7. 执行：

    lua .agents/tests/regression.lua

## 验证与验收

- 回归命令：`lua .agents/tests/regression.lua`
- 预期：全部通过。
- 实际：通过，输出 `All regression checks passed (107)`。

验收点对应：

- 普通步行不再因 ground 缺失而直接进入 done：由 `_test_move_anim_bt_missing_ground_still_moves` 验证。
- 动画回调异常有日志证据：由 `_test_move_anim_callback_error_logged_and_done` 验证。
- 既有“防下沉 + 玩家碰撞控制”能力保留：全量回归通过。

## 可重复性与恢复

- 所有步骤可重复执行。
- 若需回滚：

    git checkout -- src/core/Logger.lua src/game/turn/TurnAnim.lua src/ui/MoveAnim.lua src/ui/PlayerMoveBehavior.lua src/ui/PlayerMoveBehaviorStepBuilder.lua src/ui/PlayerPositioning.lua .agents/tests/suites/ui.lua .agents/PLAN_CURRENT.md

## 产物与备注

本次改动文件：

- `src/core/Logger.lua`
- `src/game/turn/TurnAnim.lua`
- `src/ui/MoveAnim.lua`
- `src/ui/PlayerMoveBehavior.lua`
- `src/ui/PlayerMoveBehaviorStepBuilder.lua`
- `src/ui/PlayerPositioning.lua`
- `/.agents/tests/suites/ui.lua`
- `/.agents/PLAN_CURRENT.md`

## 接口与依赖

接口变化：

- `src/core/Logger.lua` 新增 `logger.error(...)`。
- `src/ui/PlayerPositioning.lua`：
  - `resolve_min_player_y(scene, opts)` 新增可选参数 `opts.allow_missing`。

依赖不变：

- `SetTimeOut` 仍由 `RuntimeEnvBindings` 注入。
- 动画状态机仍由 `TurnAnim` 派发 `move_anim_done / action_anim_done`。

## 本次更新说明

本次清空并重写 `PLAN_CURRENT.md`，原因是任务从“移动下沉与碰撞修复”转为“动画瞬移根因修复与可观测性增强”，需按新目标独立维护计划与验收证据。
