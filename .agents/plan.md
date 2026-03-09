# 修正本地玩家移动结束后仍持续跑步的问题

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循仓库规范 `.agents/harness/PLANS.md` 维护。本轮实现依据 `.agents/swarm_plan.md` 执行，当前文件作为实际实施记录与验证真源。

## 目的 / 全局视角

这次修复要解决一个用户可见问题：本地玩家在移动动画结束、甚至棋盘同步已经把角色 snap 回地块后，角色仍会原地跑步。修复完成后，本地玩家在单步移动、多步移动被覆盖、以及 board sync 强制清理这三类路径里，都只能在整段移动期间保持控制锁豁免；移动结束后豁免会被释放，角色停止跑步，等待选择与回合间阶段不再残留 moving 视觉。

可观察结果有三类。第一，`move_anim` 的 sequence 级 lock 生命周期存在且只触发一次开始、一次结束。第二，`board_sync_place_players` 在清 token 时会同步释放 sequence lock，不会留下 stale exempt。第三，相关 suite 与全量回归通过，证明没有打断既有 step 级 lock 流程和 presentation 同步流程。

## 进度

- [x] (2026-03-09 15:54+08:00) 已读取 `.agents/swarm_plan.md`、`.agents/harness/PLANS.md`、`move_anim.lua`、`anim_ports.lua`、`board/placement.lua` 与相关测试，确认现状仍是 step-level lock 控制本地 role-control 豁免。
- [x] (2026-03-09 16:08+08:00) 已在 `src/presentation/view/render/move_anim.lua` 引入按玩家记录的 active sequence entry，并把清 token、序列替换、序列完成三条路径统一接到 sequence lock release。
- [x] (2026-03-09 16:12+08:00) 已在 `src/presentation/runtime/ports/anim_ports.lua` 把 role-control 豁免维护从 `on_step_lock` 迁到 `on_sequence_lock`，保留 `on_step_lock` 仅作原有 step 生命周期回调。
- [x] (2026-03-09 16:18+08:00) 已增强 `stop_player_presentation` 的动画清理链，新增 `interrupt_multi_animation`、`stop_play_body_anim`、`stop_play_upper_anim` 的可选调用，同时保留原有 motion stop 优先级。
- [x] (2026-03-09 16:26+08:00) 已补充 `presentation.move_anim` 与 `presentation.board_sync` 覆盖：单步 sequence lock、重叠 sequence 替换、role-control exempt 整段保持、board sync forced clear 释放 sequence lock。
- [x] (2026-03-09 16:31+08:00) 已运行 `presentation.move_anim`、`presentation.board_sync`、`presentation_ui.timing_anim`、`presentation_ui_action_status_part2`，全部通过。
- [x] (2026-03-09 16:35+08:00) 已运行 `lua tests/regression.lua`，全量回归通过并输出 `All regression checks passed (457)`、`dep_rules ok`、`legacy_path_guard ok`、`arch_view_guard ok`。
- [x] (2026-03-09 17:36+08:00) 已修正 `_read_bool_method(...)` 对宿主零参数探针 `is_moving` / `is_forced_moving` 的调用方式，避免编辑器运行时出现 `params count mismatch`。
- [x] (2026-03-09 17:40+08:00) 已补充宿主零参数探针回归用例并重跑 `presentation.move_anim`、`presentation.board_sync`、`presentation_ui.timing_anim`、`presentation_ui_action_status_part2` 与 `lua tests/regression.lua`；全部通过，新增测试后全量回归计数更新为 `458`。

## 意外与发现

- 观察：`move_anim.clear_player_token` 之前只清 `active_token_by_player_id`，不会处理任何“序列级”生命周期，因此 board sync 虽然能清 stale token，却无法释放控制锁豁免。
  证据：修复前 `src/presentation/view/render/move_anim.lua` 的 `clear_player_token` 只把 `runtime.active_token_by_player_id[player_id]` 设为 `nil`。

- 观察：`anim_ports` 把 role-control 豁免绑在 `on_step_lock` 上，会导致单步移动在 step finish 同帧立即重新套回 `BUFF_FORBID_CONTROL`。
  证据：修复前 `src/presentation/runtime/ports/anim_ports.lua` 在 `anim_ctx.on_step_lock` 中直接调用 `_update_role_control_lock_exempt(state, enabled, meta)`。

- 观察：role-control 相关测试若把异步 finish callback 放到 patch 作用域外执行，会因为 `Enums.BuffState.BUFF_FORBID_CONTROL` 恢复为 `nil` 而得到误报。
  证据：第一次测试运行时出现 `missing Enums.BuffState.BUFF_FORBID_CONTROL`；把 scheduled callback 移回 `_with_patches(...)` 作用域后测试通过。

- 观察：全量回归通过，但仓库仍存在大量 market paid goods mapping warning，以及少量 `The system cannot find the file specified.` 的环境噪声；这些不是本轮修改引入的新失败。
  证据：`lua tests/regression.lua` 最终输出 `All regression checks passed (457)`，同时伴随既有 warning/环境日志。

- 观察：宿主提供的 `LifeEntity.is_moving()` 与 `CharacterComp.is_forced_moving()` 是零参数 API，不接受 Lua 冒号调用风格附带的 self。
  证据：编辑器运行日志直接报 `expected: 0, got 1`，而 `EggyAPI.lua` 里的声明也是 `function LifeEntity.is_moving() end`、`function CharacterComp.is_forced_moving() end`。

## 决策日志

- 决策：在 `board_scene._move_anim_runtime` 中新增 `active_sequence_by_player_id`，而不是把 sequence 数据塞进原 token map。
  理由：token 仍然负责 stale callback 判定；sequence entry 负责生命周期、meta 与 release 状态，两者职责不同，拆开更清晰。
  日期/作者：2026-03-09 / Codex

- 决策：sequence lock 的 release 统一走三条路径：新序列覆盖旧序列、`clear_player_token` 强制清理、正常 finish callback。
  理由：这三条路径正好覆盖了本轮定位出的 stale exempt 来源；统一 release 点能避免重复或遗漏。
  日期/作者：2026-03-09 / Codex

- 决策：保留 `on_step_lock` 原语义，不再让它管理 role-control 豁免。
  理由：`presentation_ui.timing_anim` 已经对 step unlock/relock 有既有断言；按计划应保留兼容，降低回归风险。
  日期/作者：2026-03-09 / Codex

- 决策：`stop_player_presentation` 只增加动画层清理，不引入 `stop_ai` 或更激进的宿主控制停止。
  理由：本轮目标是修正本地玩家 locomotion/lock 时序，不扩大到 synthetic AI 生命周期，避免无关风险。
  日期/作者：2026-03-09 / Codex

- 决策：moving 状态日志探针保持启用，但 `_read_bool_method(...)` 必须用零参数 `pcall(method)` 调用宿主 API。
  理由：问题出在调用约定而不是探针本身；保留探针能继续验证 stop 前后状态，同时避免新的运行时噪声。
  日期/作者：2026-03-09 / Codex

## 结果与复盘

本轮目标已完成。`move_anim` 现在有 sequence 级生命周期：开始时只 unlock 一次，序列替换、forced clear、正常 finish 时只 release 一次。`anim_ports` 现在只在 sequence 生命周期内维护本地角色的 control-lock 豁免，不会在每一步结束时重新上锁。`board_sync_place_players` 在清 token 时也会同步清掉 sequence entry，避免 stale exempt 残留到等待阶段。

验证结果符合目标。`presentation.move_anim`、`presentation.board_sync`、`presentation_ui.timing_anim`、`presentation_ui_action_status_part2` 全部通过；`lua tests/regression.lua` 通过并给出 `All regression checks passed (458)`。本轮没有修改 turn phase、await 流程或路径计算，影响面保持在 move animation 生命周期、role-control exempt 时序和 stop 清理链。

剩余缺口只在编辑器真机验收层：仍建议按 `.agents/swarm_plan.md` 的预期，在本地运行一段单步移动场景，确认 `finish_stop` 日志里的 `is_moving_before -> is_moving_after` 变化符合预期，且 `wait_choice` / `inter_turn_wait` 阶段不再出现原地跑步；同时确认不再出现 `is_moving` / `is_forced_moving` 的参数个数报错。

## 背景与导读

本问题涉及三个直接协作的模块。`src/presentation/view/render/move_anim.lua` 负责把一个移动序列拆成多个 step，并在结束时停止角色表现。`src/presentation/runtime/ports/anim_ports.lua` 是 presentation runtime 到动画层的端口适配器，它会在调用 move anim 时附加一些运行时钩子。`src/presentation/view/render/board/placement.lua` 负责 board refresh 时的 stop-and-snap，同样会清理 move token 并强制把角色放回当前地块。

这里的 “sequence lock” 指的是整段移动动画期间的角色控制锁豁免生命周期，而不是单步动画的 begin/end 回调。这里的 “step lock” 指 `move_anim.one_step(...)` 在每一步开始和结束时触发的 `on_step_lock`。本轮修复的核心，就是把 role-control 豁免从 step lock 迁到 sequence lock。

与本轮直接相关的关键文件如下：

- `src/presentation/view/render/move_anim.lua`
- `src/presentation/runtime/ports/anim_ports.lua`
- `src/presentation/view/render/board/placement.lua`
- `tests/suites/presentation/presentation_move_anim.lua`
- `tests/suites/presentation/presentation_board_sync.lua`
- `tests/suites/presentation/presentation_ui_timing_anim.lua`
- `tests/suites/presentation/presentation_ui_action_status_part2.lua`

## 工作计划

先修改 `move_anim.lua`。在 `_move_anim_runtime` 中增加 `active_sequence_by_player_id`，把 sequence entry 定义为至少包含 `token`、`player_id`、`seq`、`total_time`、`anim_ctx`、`lock_released`。`play_sequence(...)` 在总时长大于零时创建 sequence entry，并在序列开始时调用一次 `anim_ctx.on_sequence_lock(false, total_time, meta)`。`clear_player_token(...)` 在清 token 的同时也释放 active sequence；如果该玩家存在 sequence entry，则必须调用 release 逻辑并删掉 entry。`_stop_active_sequence(...)` 在 finish stop 时读取 stop 前后 moving 状态，记录日志，然后释放 sequence lock 并清 token。若新序列覆盖旧序列，则 `_set_active_sequence(...)` 需要先释放旧序列，但 stale finish callback 不得影响新序列。

然后修改 `anim_ports.lua`。`play_move_anim(...)` 在保留 `anim_ctx.on_step_lock` 向前兼容的同时，新增 `anim_ctx.on_sequence_lock` 包装层。role-control exempt 的增减只在 `on_sequence_lock` 中维护；`on_step_lock` 继续只调用原回调，不再操作 `role_control_lock_exempt_by_role`。这样本地角色在整段移动期间都维持 exempt，只有 finish 或 forced clear 后才恢复正常锁。

最后补测试并做验证。`presentation_move_anim.lua` 新增 sequence 生命周期测试、重叠 sequence 覆盖测试、以及通过 `anim_ports.build().play_move_anim(...)` 验证 exempt 仅在 sequence finish 后释放。`presentation_board_sync.lua` 新增 forced clear 释放 sequence lock 的用例。既有 `presentation_ui.timing_anim` 的 step lock 测试必须继续通过，证明本轮没有破坏 step 级行为。

## 具体步骤

在仓库根目录实施并验证本轮修复时，使用以下命令：

    lua -e 'package.path=package.path..";./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua;./?/init.lua"; require("TestHarness").run_all({require("suites.presentation.presentation_move_anim"), require("suites.presentation.presentation_board_sync"), require("suites.presentation.presentation_ui_timing_anim")})'

期望看到 `All regression checks passed (8)`。

然后运行 role-control 相关 suite：

    lua -e 'package.path=package.path..";./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua;./?/init.lua"; require("TestHarness").run_all({require("suites.presentation.presentation_ui_action_status_part2")})'

期望看到 `All regression checks passed (29)`。

最后运行全量回归：

    lua tests/regression.lua

期望看到：

    All regression checks passed (458)
    dep_rules ok
    legacy_path_guard ok
    arch_view_guard ok

## 验证与验收

验收标准如下。

第一，单步移动时 `on_sequence_lock(false)` 只在序列开始触发一次，`on_sequence_lock(true)` 只在 finish stop 触发一次；step 级 `on_step_lock` 仍保持 begin/end 各一次。

第二，重叠序列时，旧序列在新序列开始时立即释放 sequence lock，但旧序列自己的 stale finish callback 不得额外释放新序列。

第三，board sync 强制清理时，`clear_player_token(..., "board_sync_place_players")` 会同时清掉 token 与 sequence entry，不留下 `role_control_lock_exempt_by_role` 残留状态。

第四，本地玩家的 role-control exempt 在整个 sequence 存活期保持开启，finish 后才恢复；不会在每一步结束时重新套回 `BUFF_FORBID_CONTROL`。

## 可重复性与恢复

本轮步骤可重复执行。测试命令都是只读验证，不会改变仓库状态。若某次回归失败，应优先检查 sequence release 是否重复触发，或测试里的异步 callback 是否跑在 patch 作用域外。恢复时不要通过移除 sequence lock 逻辑或恢复 step-level exempt 管理来“临时过测”；应修正具体的 stale token、release 时序或测试补丁范围，然后重新运行同一组命令。

## 产物与备注

本轮直接产物为：

    src/presentation/view/render/move_anim.lua
    src/presentation/runtime/ports/anim_ports.lua
    tests/suites/presentation/presentation_move_anim.lua
    tests/suites/presentation/presentation_board_sync.lua
    .agents/plan.md

关键行为证据如下：

    All regression checks passed (8)
    All regression checks passed (29)
    All regression checks passed (458)
    dep_rules ok
    legacy_path_guard ok
    arch_view_guard ok

## 接口与依赖

`src/presentation/view/render/move_anim.lua` 现在要求 `_move_anim_runtime` 同时维护 `active_token_by_player_id` 与 `active_sequence_by_player_id`。`move_anim.play_sequence(board_scene, anim_ctx)` 支持可选 `anim_ctx.on_sequence_lock(enabled, total_time, meta)`，其中 `meta` 至少包含 `player_id`、`from`、`to`、`seq`、`token`、`reason`。`move_anim.clear_player_token(board_scene, player_id, reason)` 必须在存在 active sequence 时释放 sequence lock 并删除 entry。

`src/presentation/runtime/ports/anim_ports.lua` 中的 `play_move_anim(state, anim_ctx)` 必须把 role-control exempt 的更新绑定到 `on_sequence_lock`，而不是 `on_step_lock`。`on_step_lock` 继续保留，避免破坏 `presentation_ui.timing_anim` 等既有调用方与测试。

本文件于 2026-03-09 17:40+08:00 更新：回填宿主零参数状态探针修复后的测试结果与新回归计数，原因是实现和验证已完成，需让活文档与当前仓库状态一致。
