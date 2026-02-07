# GameplayLoop 二次分拆（SRP 清理）

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

遵循 `.agents/PLANS.md` 维护。

## 目的 / 全局视角

本次工作只做 `GameplayLoop` 内部清理，不改玩法结果。目标是把 `tick` 里的混杂职责拆成可读的私有函数，让后续改动不会在同一大函数里互相干扰。用户可见结果是：功能行为不变，回归测试全绿，`GameplayLoop.lua` 更容易维护。

## 进度

- [x] (2026-02-07 16:00Z) 审计 `GameplayLoop.lua` 的职责混杂点
- [x] (2026-02-07 16:08Z) 抽取输入锁同步与统一分发函数
- [x] (2026-02-07 16:15Z) 拆分默认 choice/modal 超时流程
- [x] (2026-02-07 16:22Z) 拆分动画阶段、phase 标志同步、debug 面板同步
- [x] (2026-02-07 16:30Z) 修复前向引用问题（`_build_ui_env` 可见性）
- [x] (2026-02-07 16:33Z) 运行 `lua .agents/tests/all.lua` 并通过

## 意外与发现

- 观察：把 `_refresh_ui_from_dirty` 提前定义后，Lua 词法作用域会把 `_build_ui_env` 解析成全局，导致运行时报 nil。
  证据：`global '_build_ui_env' is not callable (a nil value)`。
- 处理：将 `_refresh_ui_from_dirty` 移到 `_build_ui_env` / `_refresh_view` 之后，保持同文件内依赖顺序清晰。

## 决策日志

- 决策：不新增文件，只在 `GameplayLoop.lua` 内拆私有函数。
  理由：本轮目标是低风险清理，避免跨文件迁移引入额外耦合。
  日期/作者：2026-02-07 / Codex

- 决策：保留现有 assert 级别，不借本轮做断言策略调整。
  理由：当前任务是结构整理，不改变边界策略，降低回归风险。
  日期/作者：2026-02-07 / Codex

## 结果与复盘

- 完成结果：
  - `tick` 主要流程已拆为独立步骤（默认 choice 超时、默认 modal 超时、phase 动画、phase 标志、dirty 刷新、debug 同步）。
  - 重复逻辑已收敛：`on_close_choice` 分发闭包与 input_blocked 同步逻辑不再多处复制。
  - 动画播放细节已从 `tick` 主干移出，主流程更聚焦“调度”。

- 验证结果：
  - 命令：`lua .agents/tests/all.lua`
  - 结果：`All tests passed`

- 复盘：
  - 这轮收益主要是可读性和局部可变更性。
  - 若继续分拆，下一步可把动画执行逻辑下沉到 `TurnAnim` 或专用 runner，但应先补针对 `tick` 的契约测试。

## 背景与导读

目标文件是 `src/game/turn/GameplayLoop.lua`。它负责回合 UI 驱动、自动玩家行动、choice/modal 超时、动画阶段推进、脏数据刷新与 debug 面板刷新。问题在于：以前 `tick` 同时承载“调度 + 细节实现”，单函数体积过大，改一处时难以确认影响面。

## 工作计划

先识别 `tick` 里重复和低内聚片段，再把它们提炼为局部私有函数。每次拆分都以“行为等价”为前提，不改外部接口，不改数据路径。完成后立即跑全量测试，若失败先修作用域或依赖顺序，再次验证。

## 具体步骤

在仓库根目录 `/Users/billyq/Dev/Github/Lua/monopoly` 执行：

    lua .agents/tests/all.lua

预期输出包含：

    Running .agents/tests/regression.lua
    ...
    All tests passed

## 验证与验收

- 回归与契约测试全部通过：`lua .agents/tests/all.lua`
- 行为约束：不新增玩法分支，不修改外部调用接口。
- 代码约束：`tick` 主流程可读，不再内嵌大段动画和超时实现细节。

## 可重复性与恢复

- 本改动可重复执行。
- 若需要回滚，直接恢复 `src/game/turn/GameplayLoop.lua` 到上一个提交并重跑测试。
- 若再次出现前向引用问题，优先检查 local 函数定义顺序。

## 产物与备注

主要产物：

- 修改：`src/game/turn/GameplayLoop.lua`

关键新增私有函数：

- `_step_default_choice_timeout`
- `_step_default_modal_timeout`
- `_step_phase_animation`
- `_sync_phase_flags`
- `_refresh_ui_from_dirty`
- `_sync_debug_log_panel`

## 接口与依赖

对外接口保持不变：

- `gameplay_loop.tick(game, state, dt)`
- `gameplay_loop.step_choice_timeout(...)`
- `gameplay_loop.step_modal_timeout(...)`
- `gameplay_loop.step_move_anim(...)`
- `gameplay_loop.step_action_anim(...)`

依赖保持不变：`TurnDispatch`、`TurnAnim`、`UIModel`、`UIView`、`StorePaths`。

---

变更说明（2026-02-07）：本文件按“继续分拆 GameplayLoop”新任务重写，替换此前计划内容，记录本轮 SRP 清理的步骤、决策与验证证据。
