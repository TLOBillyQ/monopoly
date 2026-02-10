# 修复“玩家1后无法正常进入玩家2回合”：AI 回合自动推进（0.4s）

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `/.agents/PLANS.md` 维护。

## 目的 / 全局视角

本次改造修复“玩家1结束后卡住，不进入玩家2回合”的核心体验问题。改造后，当当前回合玩家是 AI 且未开启托管时，系统会按 0.4 秒节奏自动触发 `next`，无需人工点击。用户可见结果是：P1 结束后，AI2 会自动开始并推进回合；人类回合仍保持手动操作权限边界。

## 进度

- [x] (2026-02-10 04:10Z) 梳理根因，确认问题来自 AI 回合缺少推进触发源，而非 `current_player_index` 未切换。
- [x] (2026-02-10 04:14Z) 新增规则配置 `ai_auto_turn_interval_seconds = 0.4`。
- [x] (2026-02-10 04:22Z) 在 `GameplayLoop` 增加 `step_ai_turn_runner`，实现“AI 且非托管”自动推进通道。
- [x] (2026-02-10 04:25Z) 在 `init` 与 `set_game` 中补齐 `ai_turn_runner` 初始化与重置，避免跨局脏状态。
- [x] (2026-02-10 04:30Z) 补充 gameplay 回归用例（AI 自动推进、人类不误触发、阻断态不推进、托管不重复触发）。
- [x] (2026-02-10 04:34Z) 运行 `lua .agents/tests/regression.lua`，58/58 通过。

## 意外与发现

- 观察：直接单跑 `.agents/tests/suites/gameplay.lua` 会缺少 `TestSupport` 路径配置。
  证据：Lua 报错 `module 'TestSupport' not found`。
- 观察：统一从 `.agents/tests/regression.lua` 入口运行可正确装配测试路径。
  证据：`All regression checks passed (58)`。

## 决策日志

- 决策：保持 `TurnDispatch` 的权限校验不变，不放宽人工点击权限。
  理由：目标是“AI 自动运行”，不是“允许非当前 role 越权操作”。
  日期/作者：2026-02-10 / Codex
- 决策：AI 自动推进与 `auto_play` 托管并存，且 `auto_play=true` 时仅保留原 `auto_runner` 通道。
  理由：避免双通道重复触发 `next`。
  日期/作者：2026-02-10 / Codex
- 决策：AI 自动推进节奏固定走 `GameplayRules.ai_auto_turn_interval_seconds`，默认 0.4s。
  理由：避免硬编码，后续可按体验统一调参。
  日期/作者：2026-02-10 / Codex

## 结果与复盘

已完成“AI 回合无人推进导致卡回合”的修复。当前行为：当轮到 AI 玩家且未开托管时，系统每 0.4s 自动尝试推进回合；动画/阻断阶段不会误推进；托管开启时仍走既有自动流程。回归测试通过，未改动回合权限模型与 UI 按钮使能规则，风险控制在最小变更范围内。

## 背景与导读

回合推进入口在 `src/game/turn/GameplayLoop.lua`。现有 `step_auto_runner` 只在 `ui.auto_play=true` 下产生活动；当 `ui.auto_play=false` 且当前玩家是 AI 时，系统没有触发 `next` 的来源，因此会停在 AI 回合起点。权限校验仍由 `src/game/turn/TurnDispatch.lua` 限制 `actor_role_id == current_player_index`，这本身是正确的，不能通过放宽权限来“掩盖”问题。

关键文件：

- 配置：`Config/GameplayRules.lua`
- 运行态初始化：`src/app/init.lua`
- 回合 tick 与自动推进：`src/game/turn/GameplayLoop.lua`
- UI 文档：`.agents/docs/ui/01_UI_基础屏.md`
- 回归测试：`.agents/tests/suites/gameplay.lua`

## 工作计划

先在规则层新增 AI 自动推进节奏配置，再在 GameplayLoop 增加 AI 专用 runner 分支。该分支复用现有 action dispatch 路径，确保和人工点击、托管自动推进共用同一权限与状态机逻辑。随后在 init/set_game 中补齐 runner 生命周期管理，最后通过 gameplay suite 场景覆盖关键边界，再跑总回归确认无副作用。

## 具体步骤

工作目录：`c:\Users\Lzx_8\Desktop\dev\monopoly`

1. 配置节奏：

    编辑 `Config/GameplayRules.lua`，新增 `ai_auto_turn_interval_seconds = 0.4`。

2. 初始化运行态：

    编辑 `src/app/init.lua`，创建 `state.ai_turn_runner` 与 `state.ai_turn_runner_active`。

3. 增加 AI 自动推进通道：

    编辑 `src/game/turn/GameplayLoop.lua`：
    - 新增 `_is_auto_player_turn` 与 `_build_auto_context`。
    - 新增 `step_ai_turn_runner`，满足 AI/非托管/非阻断条件时按 0.4s 触发 `ui_button next`。
    - 在 `tick` 中调用 `step_ai_turn_runner`。
    - 在 `set_game` 重置 `ai_turn_runner`。

4. 文档与测试：

    - 更新 `.agents/docs/ui/01_UI_基础屏.md` 的 AI 回合自动推进说明。
    - 更新 `.agents/tests/suites/gameplay.lua` 新增 4 个用例。
    - 运行：
        lua .agents/tests/regression.lua

## 验证与验收

- 自动化验收：运行 `lua .agents/tests/regression.lua`，预期全部通过。
- 手工验收：
  - P1 结束后切到 AI2，约 0.4s 自动推进，不需点击。
  - 人类回合在非托管模式下不自动推进。
  - `wait_move_anim`/`wait_action_anim` 等阻断态不推进。
  - 开启托管后沿用既有 `auto_runner` 行为。

## 可重复性与恢复

本次改动为增量可重复修改。若需回滚，可按文件级回退：

1. 回退 `GameplayLoop.lua` 中 `step_ai_turn_runner` 及其调用；
2. 回退 `init.lua` 的 `ai_turn_runner` 状态；
3. 回退 `GameplayRules.lua` 新配置与测试用例；
4. 重新执行 `lua .agents/tests/regression.lua` 验证回退后状态。

## 产物与备注

关键验证输出：

    ..........................................................
    All regression checks passed (58)

## 接口与依赖

- `GameplayRules` 新增内部配置字段：
  - `ai_auto_turn_interval_seconds: number`（默认 `0.4`）
- `ui_state` 新增内部运行态：
  - `ai_turn_runner`
  - `ai_turn_runner_active`
- 未改动对外 API；未改动 `TurnDispatch` 权限模型。

---

计划更新说明（2026-02-10 04:34Z）：新建并完成本任务计划。原因：本任务涉及回合调度与权限边界，属于需要可追溯决策的跨模块改动。
