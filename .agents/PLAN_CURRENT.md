# 载具移动降级：禁用 move API，改为 set_position 逐格跳

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `/.agents/PLANS.md` 维护。

## 目的 / 全局视角

当前载具 `move` 事件链不稳定，导致移动表现偶发异常。本次改动将有载具玩家的移动执行从 `forward_eca_event_move` 降级为 `forward_eca_event_set_position` 逐格跳转，保留原分支并加开关控制，默认禁用 move API。改造后，用户可见行为是：有载具玩家仍按路径逐格移动（跳格），无载具玩家保持原来逻辑，回合流程与 enter/exit/stop 不变。

## 进度

- [x] (2026-02-10) 清空并重写 `/.agents/PLAN_CURRENT.md`，建立本次任务文档。
- [x] (2026-02-10) 新增运行时开关并改造 `MoveAnim` 载具执行路径。
- [x] (2026-02-10) 调整 `/.agents/tests/suites/ui.lua` 并补充回滚开关测试。
- [x] (2026-02-10) 执行 `lua .agents/tests/regression.lua` 并回填结果（82 通过）。

## 意外与发现

- 观察：默认禁用 move API 后，载具路径的 step_time 仍需沿用载具速度/加速度模型，否则观感会明显变慢。
  证据：`MoveAnim._calc_step_time` 已改为“只要是载具动画就按载具模型算时长”，不再依赖 move helper 可用性。
- 观察：开关回滚路径需要测试保护，避免后续误删 move 分支。
  证据：新增测试 `_test_move_anim_vehicle_move_api_enabled_uses_move_event`。

## 决策日志

- 决策：保留旧 move 分支，仅通过 `vehicle_move_api_enabled` 开关控制是否启用。
  理由：降低回滚成本，后续验证稳定后可一键恢复。
  日期/作者：2026-02-10 / Codex
- 决策：默认 `vehicle_move_api_enabled = false`。
  理由：当前需求是“暂时屏蔽 move API”。
  日期/作者：2026-02-10 / Codex
- 决策：首跳仍保留 `consume_enter_delay` 逻辑。
  理由：避免载具刚刷出时首跳丢失。
  日期/作者：2026-02-10 / Codex

## 结果与复盘

本次降级目标已完成：默认情况下，载具移动不再发送 `forward_eca_event_move`，改为按路径逐格发送 `forward_eca_event_set_position`。同时保留了旧 move 分支，并通过 `vehicle_move_api_enabled` 开关实现可回滚控制。首跳 enter 延迟逻辑保持不变。

测试侧已更新默认路径断言，并新增“开关开启恢复 move API”回归用例。全量回归结果：`lua .agents/tests/regression.lua` 输出 `All regression checks passed (82)`，验收标准全部满足。

## 背景与导读

改动核心集中在以下文件：

- `Config/RuntimeConstants.lua`：新增开关 `vehicle_move_api_enabled`。
- `src/ui/MoveAnim.lua`：新增“跳格模式”判断，默认用 set_position 逐格执行。
- `/.agents/tests/suites/ui.lua`：把载具移动断言从 `forward_eca_event_move` 改为 `forward_eca_event_set_position`，并新增“开关恢复 move”测试。

不改动：

- `RuntimeContext` 导出接口与 helper 结构；
- `enter/exit/stop` 生命周期；
- `BoardView` 的回合末位置拉回机制。

## 工作计划

先在常量层加开关，再改 `MoveAnim` 的模式选择：默认走 set_position 逐格跳，开关打开才走 move API。随后调整 UI 测试覆盖默认与回滚两条路径。最后跑全量回归并记录结果。

## 具体步骤

工作目录：`/Users/billyq/Dev/Github/Lua/monopoly`

1. 修改 `Config/RuntimeConstants.lua`，新增 `vehicle_move_api_enabled = false`。
2. 修改 `src/ui/MoveAnim.lua`：
   - 新增 `_is_vehicle_jump_mode(anim_ctx)`；
   - 收敛 `_use_vehicle_helper` 为“仅开关开启时”；
   - 在 `one_step` 中跳格模式改为 `forward_eca_event_set_position(player_id, target_pos)`；
   - 保留 `consume_enter_delay`，首跳延迟不变。
3. 修改 `/.agents/tests/suites/ui.lua`：
   - 更新默认模式测试断言为 set_position；
   - 保留首跳延迟测试；
   - 新增开关开启时恢复 move API 的测试。
4. 执行：
   lua .agents/tests/regression.lua

## 验证与验收

验收标准：

- 默认开关关闭时，有载具移动不调用 `forward_eca_event_move`，逐格调用 `forward_eca_event_set_position`。
- 开关开启时，恢复调用 `forward_eca_event_move`，不走 set_position 路径。
- 首跳 enter 延迟仍生效。
- 无载具路径行为不变。
- 全量回归通过。

## 可重复性与恢复

本次改动可重复执行。若需恢复旧行为，仅将 `vehicle_move_api_enabled` 设为 `true`。若出现异常，可按文件粒度回滚 `MoveAnim` 与测试修改。

## 产物与备注

产物包含：一个运行时开关、`MoveAnim` 双路径逻辑（默认跳格 + 可回滚 move）、以及 UI 回归用例更新。

## 接口与依赖

新增配置字段：

- `runtime_constants.vehicle_move_api_enabled`（boolean）

依赖保持不变：

- `vehicle_helper.forward_eca_event_set_position`
- `vehicle_helper.forward_eca_event_move`
- `vehicle_helper.consume_enter_delay`

计划更新说明（2026-02-10）：按“载具移动降级”需求重写本计划，替换上一任务内容。
计划更新说明（2026-02-10）：完成代码改造、测试补充与全量回归验证，回填实施证据与复盘结论。
