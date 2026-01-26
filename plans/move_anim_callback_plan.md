# 移动动画完成回调等待接入

本 ExecPlan 是一个活文档，`Progress`、`Surprises & Discoveries`、`Decision Log`、`Outcomes & Retrospective` 必须随执行进度持续更新。

本仓库的 ExecPlan 规范位于 `.agent/PLANS.md`，执行与维护必须遵循该文件要求。

## Purpose / Big Picture

完成后，回合移动流程会在“移动动画播放完成”之前暂停，等待外部适配层（`src/adapters/*`）发出完成事件再继续结算。玩家能直观看到：当棋子开始移动时，流程不再立刻进入落地与触发效果，而是在动画结束后继续。无 UI 的脚本与回归测试保持原行为（不等待）。

## Progress

- [x] (2026-01-26 15:35) 读取 `src/gameplay/turn_move.lua`、`src/gameplay/turn_manager.lua`、适配层 `src/adapters/*`，确认当前仅有 `wait_choice` 等待点且无移动动画等待逻辑。
- [x] (2026-01-26 16:13) 设计并确认等待协议（Store 数据、回调动作、状态机位置）与不阻塞无 UI 场景的条件。
- [x] (2026-01-26 16:13) 在移动流程中加入等待：生成移动动画上下文、进入 `wait_move_anim` 状态、完成后继续处理移动中断与落地。
- [x] (2026-01-26 16:13) 在适配层读取移动动画上下文并发送 `move_anim_done` 动作，覆盖 Love2D/Eggy/Oasis。
- [x] (2026-01-26 16:13) 增加回归验证用例覆盖 `wait_move_anim`。
- [x] (2026-01-26 16:14) 运行 `lua tests/deps_check.lua`、`lua tests/regression.lua`。
- [ ] 手工验证：在 UI 运行时触发移动，确认等待与恢复顺序正确。

## Surprises & Discoveries

- 当前流程只有 `wait_choice` 等待逻辑，`turn_move` 直接返回 `landing`，移动后没有任何回调等待点。
- 回归测试使用自定义 TurnManager 绕过 `turn_start` 时，需要先写入 `game.last_turn`，否则 `turn_move` 会因 `last_turn` 为空而报错。

## Decision Log

- Decision: 使用 Store 的 `turn.move_anim` 作为移动动画上下文，并配合 `turn.move_anim_seq` 做去重，新增动作 `move_anim_done` 作为恢复信号。
  Rationale: Store 已是跨层共享状态，适配层可直接读取，无需引入新的事件总线；序号可避免旧动画回调误恢复。
  Date/Author: 2026-01-26 / Codex
- Decision: 仅当 `game.ui_port` 显式标记支持等待（如 `ui_port.wait_move_anim == true`）时进入等待状态。
  Rationale: 保持无 UI/无动画环境的行为不变，避免测试或 AI 运行被卡住。
  Date/Author: 2026-01-26 / Codex
- Decision: `turn_move` 在恢复路径复用同一函数，通过 `args.move_result` 标记“已完成移动计算”，避免新增冗余阶段函数。
  Rationale: 保持移动逻辑单一实现，降低改动范围并符合 CodingDiscipline 的“相似逻辑合并”。
  Date/Author: 2026-01-26 / Codex
- Decision: 适配层对每个 `move_anim.seq` 只派发一次 `move_anim_done`，不引入计时延迟。
  Rationale: 当前无真实动画实现，直接完成可避免阻塞与重复派发，同时保持实现最小化。
  Date/Author: 2026-01-26 / Codex

## Outcomes & Retrospective

已完成代码接入与回归用例新增，依赖检查与回归测试通过；待 UI 手工验证。

## Context and Orientation

移动流程在 `src/gameplay/turn_roll.lua` → `src/gameplay/turn_move.lua` → `src/gameplay/turn_land.lua` 之间流转，状态机由 `src/gameplay/turn_manager.lua` 驱动并写入 `store.turn.phase`。`turn_move` 会调用 `src/gameplay/movement_service.lua` 计算路径并立刻更新玩家位置与 `game.last_turn.move_result`。适配层通过 `game.ui_port` 访问游戏实例，运行时循环在 `src/adapters/love2d/love_runtime.lua`、`src/adapters/eggy/eggy_layer.lua`、`src/adapters/oasis/oasis_layer.lua` 中。当前没有“移动动画完成”事件的等待点，也没有 Store 字段承载动画上下文。

术语说明：
- “外部适配层”指 `src/adapters/*` 下的运行时 UI 代码，通过 `game.ui_port` 与回合逻辑交互。
- “移动动画完成事件”指适配层在动画播放结束后，向 `game:dispatch_action` 发送 `move_anim_done` 动作。

## Plan of Work

在 `src/gameplay/turn_move.lua` 里新增“移动后可等待”的分支：先记录移动起点、调用 `movement.move` 得到 `move_result`，写入 `game.last_turn.move_result`；若适配层开启等待，则生成 `turn.move_anim` 上下文并返回新状态 `wait_move_anim`，恢复参数携带 `move_result`，避免重复移动。恢复后再处理路障、偷窃/黑市中断与落地流程，保证动画结束后才触发后续逻辑。

在 `src/gameplay/turn_manager.lua` 增加 `wait_move_anim` 状态：当收到 `move_anim_done` 且序号匹配时清理 `turn.move_anim` 并进入 `resume_state`；否则保持等待。该状态会写入 `store.turn.phase = "wait_move_anim"` 供适配层识别。

在 `src/gameplay/composition_root.lua` 的初始状态里补充 `turn.move_anim_seq` 与 `turn.move_anim` 字段，便于序号递增与清理。

在适配层加入读取 `turn.move_anim` 的逻辑并发送回调：优先在 `src/adapters/core/adapter_layer.lua` 增加一个小型轮询函数（如 `step_move_anim`），由 Love2D/Eggy/Oasis 的 `update/tick` 调用，检测新的 `move_anim.seq`，启动动画或计时器，完成后触发 `move_anim_done`。若适配层暂时无动画，实现可以“即时完成”（下一帧立刻回调），以免阻塞。

最后在 `tests/regression.lua` 增加回归用例，构造一个带 `ui_port.wait_move_anim = true` 的游戏，直接调用 `turn_move` 或驱动 TurnManager 进入 `wait_move_anim`，断言等待状态被触发，并在手动发送 `move_anim_done` 后不再停留于 `wait_move_anim`。

## Concrete Steps

1) 在仓库根目录 `C:\Users\Lzx_8\Desktop\eggitor\1_开发中\大富翁\monopoly` 打开并理解以下文件：
   - `src/gameplay/turn_move.lua`
   - `src/gameplay/turn_manager.lua`
   - `src/gameplay/composition_root.lua`
   - `src/adapters/core/adapter_layer.lua`
   - `src/adapters/love2d/love_runtime.lua`
   - `src/adapters/eggy/eggy_layer.lua`
   - `src/adapters/oasis/oasis_layer.lua`

2) 修改 `src/gameplay/turn_move.lua`：
   - 在调用 `movement.move` 前记录 `start_index = player.position`。
   - 若 `args.move_result` 已存在，跳过 `movement.move`，并确保不再次进入等待分支。
   - 当 `game.ui_port` 存在且 `game.ui_port.wait_move_anim == true` 时：
     - 递增 `store.turn.move_anim_seq`。
     - 写入 `store.turn.move_anim = { seq, player_id, from_index, to_index, visited, steps, interrupt_flags }`。
     - 返回 `"wait_move_anim"`，并携带 `resume_state = "move"` 与 `resume_args = { player, total, raw_total, move_result }`。

3) 修改 `src/gameplay/turn_manager.lua`：
   - 在 `_build_flow` 中新增 `states.wait_move_anim`，写入 `turn.phase = "wait_move_anim"`。
   - 当收到 `action.type == "move_anim_done"` 且序号匹配（或未提供序号）时：
     - 清理 `store.turn.move_anim`。
     - 跳转到 `resume_state`。
   - 其他动作保持等待并清理 `pending_action`，避免错误动作堆积。

4) 修改 `src/gameplay/composition_root.lua` 的初始状态：
   - 在 `turn` 中增加 `move_anim_seq = 0` 与 `move_anim = nil`。

5) 修改 `src/adapters/core/adapter_layer.lua`：
   - 新增 `AdapterLayer.step_move_anim(layer, dt, opts)`，读取 `turn.move_anim` 并在完成时派发 `{ type = "move_anim_done", seq = pending.seq }`。
   - 记录当前处理的 `seq`，避免重复触发。

6) 在 Love2D/Eggy/Oasis 运行循环中调用 `AdapterLayer.step_move_anim`：
   - `src/adapters/love2d/love_runtime.lua` 的 `LoveLayer:update(dt)`。
   - `src/adapters/eggy/eggy_layer.lua` 的 `EggyLayer:tick(dt)`。
   - `src/adapters/oasis/oasis_layer.lua` 的 `OasisLayer:tick(dt)`。
   - 若暂无实际动画，实现可以设置为“下一帧即完成”，确保不会阻塞。

7) 在 `tests/regression.lua` 新增回归用例：
   - 创建游戏并注入 `ui_port = { wait_move_anim = true }`。
   - 直接调用 `turn_move` 或执行一次 `game:advance_turn()` 进入 `wait_move_anim`。
   - 断言 `store.turn.phase == "wait_move_anim"` 且 `store.turn.move_anim.seq` 有值。
   - 调用 `game:dispatch_action({ type = "move_anim_done", seq = <当前序号> })`，断言不再停留于 `wait_move_anim`。

8) 运行自测：

   工作目录：`C:\Users\Lzx_8\Desktop\eggitor\1_开发中\大富翁\monopoly`
   命令：
     lua tests/deps_check.lua
     lua tests/regression.lua

   期望：依赖检查无报错；回归用例全部通过。

## Validation and Acceptance

- 在 UI 适配层开启 `wait_move_anim` 后，玩家移动时回合阶段先变为 `wait_move_anim`，动画结束后自动恢复并继续结算。
- `move_anim_done` 只会恢复当前序号对应的等待，不会被旧回调误触发。
- 无 UI 或 `wait_move_anim == false` 时，移动流程与现有行为一致。
- `lua tests/deps_check.lua` 与 `lua tests/regression.lua` 均通过，新测试在改动前失败、改动后通过。

## Idempotence and Recovery

改动是运行时状态与流程控制，不会修改配置或生成文件。若出现卡死，首先检查 `wait_move_anim` 是否在无 UI 环境被误开启；可暂时将其关闭或回滚 `turn_move` 中的等待分支恢复原流程。

## Artifacts and Notes

示例 Store 数据（缩进展示）：

    turn.move_anim = {
      seq = 3,
      player_id = 1,
      from_index = 5,
      to_index = 9,
      visited = { 6, 7, 8, 9 },
      steps = 4,
      stopped_on_roadblock = false,
      market_interrupt = false,
      steal_interrupt = false,
    }

测试输出（节选）：

    Dependency self-check passed
    ...........................
    All regression checks passed (27)

## Interfaces and Dependencies

新增/调整接口与数据：
- Store：
  - `turn.move_anim_seq`（number）：移动动画序号，自增。
  - `turn.move_anim`（table|nil）：移动动画上下文。
- 动作：
  - `move_anim_done`：适配层在动画完成后发送，携带 `seq`。
- 适配层约定：
  - `game.ui_port.wait_move_anim == true` 时启用等待逻辑。
  - 适配层需在运行循环中读取 `turn.move_anim` 并派发完成动作。
  - UI 适配层可在 `AdapterLayer.attach` 中默认将 `wait_move_anim` 设为 `true`，保证启用等待。

本计划更新记录：
- 2026-01-26 15:35：创建初版 ExecPlan，定义移动动画等待流程与回调接口，原因是新增跨层等待需求需要可执行规格。
- 2026-01-26 16:13：更新进度与决策，记录已完成代码接入与测试用例新增，等待执行测试与手动验证。
- 2026-01-26 16:14：补充测试执行结果与回归发现，更新 Outcomes 状态。
- 2026-01-26 16:14：补充适配层默认开启等待的约定，保持实现细节可追溯。
