# 修正本地玩家移动结束后仍持续跑步的问题（二次定位版）

## Summary

新日志已经证明第一版修复命中了我们能想到的单位级停止链：本地玩家在 `finish_stop` 和后续 `board_refresh_stop_and_snap` 中都执行了 `stop_forced_move`、`stop_anim`、`model_stop_animation`，但视觉仍不停。这说明问题不再是“漏调 stop API”，而是本地玩家在更上层的控制/动画状态里被重新保持为 moving。

当前代码里唯一仍会在移动结束同一时刻额外干预本地玩家的，是 `anim_ports` 通过 `on_step_lock` 对 `role_control_lock_exempt` 做按步切换。对单步移动，这个“重新上锁”与 `finish_stop` 发生在同一时间点，极可能把本地玩家重新压进宿主 locomotion 状态；AI 不走这条本地控制链，所以没有同类问题。下一版修复应把“本地角色控制锁豁免”从按步切换改成按整段移动切换，并补充 moving 状态日志来验证这一点。

## Key Changes

- 在 `src/presentation/view/render/move_anim.lua` 中把移动序列运行时从“只记录 token”升级为“按玩家记录 active sequence entry”，至少包含 `token` 和 sequence 级释放逻辑。
- 为 `play_sequence` 增加 `anim_ctx.on_sequence_lock(enabled, total_time, meta)` 生命周期钩子：
  - 序列真正开始时只调用一次 `on_sequence_lock(false, ...)`
  - 序列结束、被新序列顶掉、或被 `clear_player_token` 强制清理时只调用一次 `on_sequence_lock(true, ...)`
  - 保留现有 `on_step_lock`，但它不再承担 role control 管理职责
- 在 `src/presentation/runtime/ports/anim_ports.lua` 中把 `role_control_lock_exempt_by_role` / `role_control_lock_exempt_count_by_role` 的维护从 `on_step_lock` 挪到 `on_sequence_lock`：
  - 移动整段期间，本地玩家持续豁免 `BUFF_FORBID_CONTROL`
  - 只有在 `finish_stop` 或 forced clear 后才恢复锁
  - 不再在每一步结束时重新套 lock
- 同时强化 `stop_player_presentation` 的动画层清理，但保持风险可控：
  - 保留现有 `force_stop_move` / `stop_forced_move` / `ai_command_stop_move`
  - 在动画层增加 `interrupt_multi_animation`、`stop_play_body_anim`、`stop_play_upper_anim`
  - 暂不引入 `stop_ai`，避免影响 synthetic AI 生命周期
- 调试日志改为同时输出 stop 前后状态：
  - `is_moving_before` / `is_moving_after`
  - `is_forced_moving_before` / `is_forced_moving_after`
  - `role_control_lock_active`
  - `role_control_exempt`
  这样可以直接验证问题是“stop 没生效”还是“stop 后又被控制层重新拉回 moving”。

## Interfaces

- 不新增对外 public API。
- 内部新增 `anim_ctx.on_sequence_lock` 约定，作为 `move_anim.play_sequence` 的可选输入字段；`anim_ports.build().play_move_anim` 负责填充它。
- `move_anim.clear_player_token` 需要具备“如果该玩家存在未释放的 sequence lock，则在清 token 时释放”的语义，避免 stale token 或 board sync 清理后遗留豁免状态。
- `on_step_lock` 继续保留现状语义，避免影响现有 step 级测试与其他潜在调用方。

## Test Plan

- 在 `tests/suites/presentation/presentation_move_anim.lua` 增加 sequence-lock 生命周期用例：
  - 单步移动：`on_sequence_lock(false)` 只在开始触发一次，`on_sequence_lock(true)` 只在 finish 触发一次
  - 重叠序列：旧序列被新序列覆盖时，旧序列的 sequence lock 会释放，但 stale finish callback 不会释放新序列
- 在 `tests/suites/presentation/presentation_board_sync.lua` 增加 forced clear 用例：
  - `clear_player_token(..., "board_sync_place_players")` 会同步释放 sequence lock，不留下 active exempt 状态
- 在 `tests/suites/presentation/presentation_ui_action_status_part2.lua` 或现有 role-control 相关 suite 中增加用例：
  - 本地玩家在整段 move anim 期间保持 exempt
  - 不会在每一步结束时重新加 `BUFF_FORBID_CONTROL`
  - finish 后才恢复正常 lock 状态
- 保留并继续通过现有 step 级测试：
  - `presentation_ui_timing_anim` 里的 `on_step_lock` 测试仍应成立
- 回归命令至少执行：
  - `presentation.move_anim`
  - `presentation.board_sync`
  - 包含 role_control_lock 的 presentation suite
- 编辑器验收：
  - 本地玩家 1 步移动后，在 `finish_stop` 前后日志中可见 moving 状态从 `true -> false`
  - `wait_choice` 和 `inter_turn_wait` 阶段不再出现本地玩家原地跑动
  - 日志中 role control 豁免只在序列结束后释放，不再与单步 finish 同帧反复切换

## Assumptions

- 本地玩家问题主要来自角色控制锁与宿主 locomotion 状态的时序冲突，而不是再次缺少某个基础 stop API。
- `interrupt_multi_animation`、`stop_play_body_anim`、`stop_play_upper_anim` 对本地玩家 ctrl unit 是安全的；若方法不存在则静默跳过。
- 本次修复默认不改 turn phase、await 流程和移动路径计算；只修正 move animation 的 sequence 生命周期与本地控制锁时序。
