# 载具事件化移动系统接入（enter/exit/move/stop/set_position）

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `/.agents/PLANS.md` 维护。

## 目的 / 全局视角

当前有载具玩家移动仍走角色 `start_move_by_direction`，与关卡侧载具 ECA 流程脱节。本次改动后，有载具玩家将走统一的 `eca_event.vehicle` 事件链，并新增“载具位置纠偏”事件，保证回合结束后载具与逻辑位置一致。用户可观察到：载具获取/更换/销毁有 enter/exit 生命周期，移动由载具事件驱动，回合末有 stop + 位置拉回。

## 进度

- [x] (2026-02-10) 清空并重写 `/.agents/PLAN_CURRENT.md`，建立本次实施文档骨架。
- [x] (2026-02-10) 扩展 `RuntimeConstants/RuntimeContext` 的载具事件与 helper 状态。
- [x] (2026-02-10) 改造 `GameState/TurnMove/CompositionRoot/UIModel` 载具同步字段。
- [x] (2026-02-10) 改造 `BoardView/MoveAnim`，接入载具事件路径与梯形速度模型。
- [x] (2026-02-10) 增加 `gameplay/ui` 回归用例并执行全量回归（77 通过）。

## 意外与发现

- 观察：测试环境可能缺少 `vehicle_helper` 或未挂载 ECA 监听，载具动画链路仍需保持可运行。
  证据：`MoveAnim` 中保留“helper 不可用时回退 unit 移动”路径；`lua .agents/tests/regression.lua` 通过。
- 观察：回合末 stop 与位置纠偏应当解耦，避免仅凭位置快照无法触发重对齐。
  证据：新增 `turn.vehicle_resync_seq`，并在 `BoardView` 以序列变化强制触发 set_position。

## 决策日志

- 决策：设置载具位置事件名固定为 `set_position_vehicle_forward`。
  理由：沿用现有 `*_vehicle_forward` 命名风格，便于关卡 ECA 对齐。
  日期/作者：2026-02-10 / Codex
- 决策：载具运动时间按“每步梯形速度模型”计算。
  理由：能同时利用 `vehicle_speed` 与 `vehicle_accel`，实现稳定且可预测。
  日期/作者：2026-02-10 / Codex
- 决策：首次上车/换车后下一次移动前固定等待 `1.2s`。
  理由：规避 enter 刷载具 1~2 秒延迟导致的首步移动丢失。
  日期/作者：2026-02-10 / Codex

## 结果与复盘

本次计划已完成。核心结果是把“有载具玩家移动”切换到事件化通道，并补齐回合末位置纠偏机制。`set_player_seat` 现在会处理 `exit -> enter` 生命周期，`MoveAnim` 对载具路径改为按步发送 `vehicle.move` 并按速度/加速度推导时长，`BoardView` 对有载具玩家改为发送 `set_position` 事件而非直接改角色单位位置。测试方面新增了 seat 生命周期、载具移动分流、enter 延迟一次性消费、回合末 `vehicle_resync_seq` 与 set_position 触发验证。

验收结果：`lua .agents/tests/regression.lua` 输出 `All regression checks passed (77)`，满足“新增覆盖 + 全量回归通过”的目标。

## 背景与导读

本次改动集中在以下模块：

- `Config/RuntimeConstants.lua`：新增载具 enter 延迟与 set_position 事件常量。
- `src/core/RuntimeContext.lua`：扩展 `vehicle_helper` 状态、事件转发与导出函数。
- `src/game/game/GameState.lua`：接管载具 enter/exit 生命周期，回合末发 stop 并递增 resync 序列。
- `src/ui/MoveAnim.lua`：有载具路径走事件驱动并使用梯形速度模型。
- `src/ui/BoardView.lua`：有载具玩家位置同步改为 set_position 事件，支持 `vehicle_resync_seq` 强制同步。
- `/.agents/tests/suites/gameplay.lua` 与 `/.agents/tests/suites/ui.lua`：补充回归验证。

## 工作计划

先把运行时常量和 helper 能力补齐，再向游戏状态层接入 seat 生命周期管理，随后把 UI 同步模型补字段，最后替换动画与位置同步路径。验证阶段以新增测试覆盖关键生命周期和移动路径，再跑全量回归确认无载具路径不回归。

## 具体步骤

工作目录：`/Users/billyq/Dev/Github/Lua/monopoly`

1. 修改 `Config/RuntimeConstants.lua` 与 `src/core/RuntimeContext.lua`，新增 set_position 事件、enter 延迟、helper 状态与导出函数。
2. 修改 `src/game/game/GameState.lua`、`src/game/game/CompositionRoot.lua`、`src/game/turn/TurnMove.lua`、`src/ui/UIModel.lua`，补齐回合与模型字段。
3. 修改 `src/ui/BoardView.lua` 与 `src/ui/MoveAnim.lua`，接入载具事件移动和回合末拉回机制。
4. 修改 `/.agents/tests/suites/gameplay.lua` 与 `/.agents/tests/suites/ui.lua`，补充测试并执行：
   lua .agents/tests/regression.lua

## 验证与验收

运行 `lua .agents/tests/regression.lua`，预期全量通过，且新增测试覆盖：

- 有载具玩家不走 `unit.start_move_by_direction`。
- 首次上车移动含 enter 延迟，后续同载具不重复等待。
- 换车时事件顺序为 `exit(old)` -> `enter(new)`。
- 载具销毁触发 `set_player_seat(..., nil)` 后发送 `exit`。
- 回合结束全员 stop 且触发 resync 序列，`BoardView` 对有载具玩家发 set_position。
- 无载具路径保持原行为。

## 可重复性与恢复

本次改动可按文件分批回退。若回归失败，按“RuntimeContext -> GameState -> UI层 -> 测试”逆序回滚定位。`set_position` 事件即使关卡未绑定也应保持逻辑层无崩溃。

## 产物与备注

产物包括：载具事件常量扩展、helper 生命周期控制、移动动画路径分流、位置纠偏事件、回归测试补齐。

## 接口与依赖

新增/调整接口：

- `runtime_constants.vehicle_enter_delay`
- `runtime_constants.eca_event.vehicle.set_position`
- `vehicle_helper.forward_eca_event_set_position(role_id, pos)`
- `vehicle_helper.consume_enter_delay(role_id, vehicle_id)`
- `get_vehicle_set_position()`
- `turn.vehicle_resync_seq`

计划更新说明（2026-02-10）：按“载具事件化移动系统接入”需求重写 `PLAN_CURRENT.md`，用于实现跟踪。
计划更新说明（2026-02-10）：完成全部代码与测试改造，补充执行证据与复盘结论，确保文档状态与实际一致。
