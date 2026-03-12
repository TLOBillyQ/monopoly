# CRAP <= 8 全仓库清零计划

## 摘要

- 验收口径固定为：在 `/Users/billyq/Dev/Github/Lua/monopoly` 运行 `lua scripts/crap.lua report --lane behavior --lane contract --out tmp/crap_report.json --top 300`，最终 `src/**/*.lua` 零个函数 `crap > 8`。
- 当前基线是 `212` 个函数高于 `8`；其中 `66` 个函数 `complexity >= 9`，单靠补测无法达标，必须拆复杂度。当前最大热点是 `/Users/billyq/Dev/Github/Lua/monopoly/src/presentation/model/init.lua` 的 `model_api.update`（361.33）和 `/Users/billyq/Dev/Github/Lua/monopoly/src/game/flow/turn/await.lua` 的 `await.move_anim`（182）。
- 修复规则固定为：`complexity >= 9` 必须先重构；`complexity = 8/7/6/5/4/3` 分别至少需要 `100% / 73% / 62% / 51% / 37% / 18%` 覆盖率。凡是 `complexity <= 8` 的热点，一律先补 characterization tests，再决定是否做最小 seam。
- 对外接口保持不变：不改 `/Users/billyq/Dev/Github/Lua/monopoly/src/core/ports/`、`/Users/billyq/Dev/Github/Lua/monopoly/src/game/ports/`、`choice/market/ui_model` 的数据 shape、`tests.behavior`/`tests.contract` 入口。所有 helper 只允许留在原 layer/subsystem 内，不跨层搬迁逻辑。
- 并行阶段不改 `/Users/billyq/Dev/Github/Lua/monopoly/tests/catalog.lua`，也不改共享测试支撑；共享 support 的整理统一留到 T8，避免多 agent 冲突。

## 并行波次

| Wave | Tasks | Can start when |
|------|-------|----------------|
| 1 | T1 | 立即 |
| 2 | T2, T3, T4, T5, T6, T7 | T1 完成 |
| 3 | T8 | T2-T7 完成 |
| 4 | T9 | T8 完成 |

## 任务

### T1 基线冻结
- depends_on: `[]`
- location: `/Users/billyq/Dev/Github/Lua/monopoly`
- description: 重新生成 CRAP 基线，冻结完整 `>8` 清单，并为每个热点打上 `must_refactor` 或 `coverage_first` 标签，再按 ownership 分到 T2-T7。若仓库漂移导致数量变化，以这次新报告为唯一真源，后续所有并行任务都以它为准。
- validation: 基线报告重新生成；开始编码前，全部执行者都使用同一份 `>8` 清单和同一组 bucket 划分。
- status: Completed
- log: 2026-03-12 生成双 lane CRAP 基线，落盘 `.agents/crap_baseline.json` 与 `.agents/crap_baseline.md`；按 T2-T8 标注 ownership 与 `must_refactor`/`coverage_first` 策略。最新基线为 over_8_count=210、T2=48、T3=5、T4=38、T5=48、T6=39、T7=31、T8=1。
- files edited/created: `.agents/plan.md`, `.agents/crap_baseline.json`, `.agents/crap_baseline.md`

### T2 Flow wait/landing cluster
- depends_on: `[T1]`
- location: `/Users/billyq/Dev/Github/Lua/monopoly/src/game/flow/turn/`，重点文件 `/Users/billyq/Dev/Github/Lua/monopoly/src/game/flow/turn/await.lua`、`/Users/billyq/Dev/Github/Lua/monopoly/src/game/flow/turn/start.lua`、`/Users/billyq/Dev/Github/Lua/monopoly/src/game/flow/turn/land.lua`、`/Users/billyq/Dev/Github/Lua/monopoly/src/game/flow/turn/phase_registry.lua`、`/Users/billyq/Dev/Github/Lua/monopoly/src/game/flow/turn/decision.lua`、`/Users/billyq/Dev/Github/Lua/monopoly/src/game/flow/turn/script.lua`；测试优先放在 `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/domain/landing.lua`、`/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/gameplay/gameplay_coroutine.lua`、`/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/gameplay/gameplay_turn_flow_and_interrupts.lua`
- description: 先钉住 wait-state 行为，再把 `await.move_anim`、`await.choice`、`_phase_start`、`handle_need_landing`、`_phase_land` 及其邻近分支拆成局部 helper，直到全部函数 `<= 8`。新 helper 只能留在 `flow/turn`，不得引入 presentation/runtime 细节。
- validation: 相关 behavior suites 通过；重新跑 CRAP 后，T2 负责的 `flow/turn` 文件不再出现 `crap > 8`。
- status: In Progress
- log: 2026-03-12 已拆分 `await.lua` 的 choice/action_anim/seconds/move_anim wait 辅助路径、`land.lua` 的 landing wait/post-action 收口，以及 `phase_registry.lua` 的 post_action wait 路由；`suites.gameplay.gameplay_coroutine`、`suites.gameplay.gameplay_turn_flow_and_interrupts`、`suites.gameplay.gameplay_timeout_and_auto_runner` 定向回归通过。
- log: 2026-03-12 继续补 T2 characterization tests：覆盖 `await.move_anim` 匹配/日志分支、`await.landing_visual`、`await.inter_turn`、`turn_start` pre_action wait 路由、`phase_registry` post_action wait 路由、`turn_land` 的 move_effect followup 延迟路径，并修复 `await.move_anim` 在 debug log 开启时 `opts=nil` 触发的空索引问题；最新双 lane CRAP 中 T2 residual 从 45 降到 30。
- log: 2026-03-12 新一轮收尾把 `turn_script` wait/phase 分发改成表驱动，拆平 `timer_policy` 的 action/detained/inter-turn timer 公共逻辑，并提炼 `move_followup` 的 steal/market resume helper；补充 `turn_script` wait_move_anim yield/resume 与 `move_followup` steal interrupt wait 的定向测试后，最新双 lane CRAP 将 T2 residual 从 30 降到 29。
- log: 2026-03-12 继续用覆盖率吃 T2 低复杂度热点：新增 `choice_auto_policy` preconsumed first-option、`timer_policy` detained/inter-turn timeout、`item_slot_data` role/fallback、`loop_ports` legacy flat override 用例，并将 `turn_script.create` 的 coroutine 主循环拆成 step/yield/finish helper；最新双 lane CRAP 将 T2 residual 从 29 降到 23。

### T3 Flow orchestration/AI cluster
- depends_on: `[T1]`
- location: `/Users/billyq/Dev/Github/Lua/monopoly/src/game/flow/` 中除 T2 之外的其余模块，以及 `/Users/billyq/Dev/Github/Lua/monopoly/src/game/ai/`；测试优先放在 `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/gameplay/gameplay_timeout_and_auto_runner.lua`、`/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/gameplay/gameplay_afk.lua`、`/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/gameplay/gameplay_intent_dispatch_and_event_feed.lua`、`/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/gameplay/gameplay_runtime_context_and_camera_sync.lua`
- description: 拆 AFK timing、auto-runner、timeout、dispatch、move_followup、AI decision 热点，优先抽成纯 helper，保持 ports 与 state shape 完全不变。凡是 `complexity >= 9` 仍超标的函数，一律做结构性拆分，不接受只补测。
- validation: 相关 gameplay suites 通过；重新跑 CRAP 后，T3 负责的 `src/game/flow/**/*` 与 `src/game/ai/**/*` 不再出现 `crap > 8`。
- status: Completed
- log: 2026-03-12 已拆分 `dispatch.lua`、`tick_choice_timeout.lua`、`movement/init.lua`、`agent.lua` 的分派/超时/移动/AI 选择路径；`suites.gameplay.gameplay_timeout_and_auto_runner`、`suites.gameplay.gameplay_afk`、`suites.gameplay.gameplay_intent_dispatch_and_event_feed`、`suites.gameplay.gameplay_runtime_context_and_camera_sync` 定向回归通过。
- log: 2026-03-12 补充 `intent_dispatcher` 与 AI/auto-runner 定向覆盖：新增 descriptor meta validator、popup dispatch、board target fallback、choice owner actor fallback 等用例；最新双 lane CRAP 中 T3 residual 收敛到 1。
- log: 2026-03-12 为 `intent_dispatcher._validate_choice_meta` 补上缺失 registry 退化路径测试，`suites.gameplay.gameplay_intent_dispatch_and_event_feed` 定向回归通过；完整双 lane CRAP 复核后 T3 当前 residual=0，已完成出桶。
- log: 2026-03-12 再补 `intent_dispatcher` 缺失 choice registry 的 fallback 用例，确保 `_validate_choice_meta` 在无 descriptor registry 时保持透传；定向 suite `tests.suites.gameplay.gameplay_intent_dispatch_and_event_feed` 通过，待下一轮双 lane CRAP 确认 T3 清零。
- log: 2026-03-12 继续收 T3 尾项：给 `intent_dispatcher` 补上 required-meta 缺失整表分支的 characterization case，并把 meta 校验/validator 路径收口成 helper；`suites.gameplay.gameplay_intent_dispatch_and_event_feed` 定向回归通过，待下一轮双 lane CRAP 确认 bucket 清零。

### T4 Gameplay systems/core cluster
- depends_on: `[T1]`
- location: `/Users/billyq/Dev/Github/Lua/monopoly/src/game/systems/` 和 `/Users/billyq/Dev/Github/Lua/monopoly/src/game/core/`；测试优先放在 `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/domain/`、`/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/gameplay/gameplay_items_startup.lua`、`/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/gameplay/gameplay_bankruptcy_and_tile_owner.lua`
- description: 用 characterization tests 覆盖 item post effects、bankruptcy feedback、market eligibility、chance handlers、board init、seat/state ops；`complexity >= 9` 的函数在原子系统内拆 resolver/helper，不把 presentation 或 host 细节带回 systems/core。
- validation: 相关 domain/gameplay suites 通过；重新跑 CRAP 后，T4 负责的 systems/core 文件不再出现 `crap > 8`。
- status: In Progress
- log: 2026-03-12 已对 `status_ops.lua`、`post_effects.lua`、`bankruptcy.lua`、`eligibility.lua`、`items/phase.lua` 做 helper 下沉与等待/收尾路径拆分；`suites.gameplay.gameplay_bankruptcy_and_tile_owner`、`suites.gameplay.gameplay_items_startup`、`suites.domain.item` 定向回归通过。
- log: 2026-03-12 继续收尾 T4：将 `items/strategy.can_offer_in_phase` 拆成 roadblock/target/rent-response helper，并在 `suites.domain.item` 增补 `can_offer_in_phase`、`item_phase` move_followup patch、`set_player_seat`、`board.advance`、`collect_from_others` 的 characterization tests；定向 item suite 通过，最新 CRAP 报告中 T4 residual 从 34 降到 27。

### T5 Presentation model/runtime cluster
- depends_on: `[T1]`
- location: `/Users/billyq/Dev/Github/Lua/monopoly/src/presentation/model/` 和 `/Users/billyq/Dev/Github/Lua/monopoly/src/presentation/runtime/`；测试优先放在 `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/presentation/presentation_ui_model_dispatch.lua`、`/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/presentation/presentation_ui_event_handlers.lua`、`/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/presentation/presentation_popup_visibility.lua`、`/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/presentation/presentation_ui_interaction.lua`、`/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/presentation/read_model_contract.lua`
- description: 把 `model_api.update`、`panel_slice.update` 一类 dirty-flag 扇出逻辑拆成按 slice 分工的 updater helpers；把 modal/event handler 的大分支拆成聚焦操作；补齐 popup/choice/game-result 路径覆盖。保持 canvas key、route key、`ui_model` 字段与 runtime APIs 不变。
- validation: 相关 presentation/contract suites 通过；重新跑 CRAP 后，T5 负责的 model/runtime 文件不再出现 `crap > 8`。
- status: In Progress
- log: 2026-03-12 已抽离 `model/init.lua`、`panel_slice.lua`、`event_handlers.lua`、`modal_controller.lua`、`view_command_ports.lua` 的 slice/route helper，并补充 UI model dispatch、event handler、interaction 定向用例；相关 presentation suites 通过。
- log: 2026-03-12 补充 presentation runtime 定向覆盖：新增 `raycast` camera/id fallback、`event_bindings` action-log fallback、`event_handlers` tile-id/tile-payload 路径用例；全量 CRAP 后 T5 残余由 38 降到 29，已清除 `raycast.lua` 与 `_resolve_tile_index` 热点。

### T6 Presentation view/input cluster
- depends_on: `[T1]`
- location: `/Users/billyq/Dev/Github/Lua/monopoly/src/presentation/view/` 和 `/Users/billyq/Dev/Github/Lua/monopoly/src/presentation/input/`；测试优先放在 `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/presentation/presentation_board_sync.lua`、`/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/presentation/presentation_action_anim_core.lua`、`/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/presentation/presentation_board_feedback.lua`、`/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/presentation/presentation_move_anim.lua`、`/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/presentation/presentation_status3d_and_turn_effects.lua`、`/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/presentation/presentation_choice_routes.lua`、`/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/presentation/presentation_target_pick.lua`
- description: 用现有 host doubles 覆盖 `board_scene.init`、status3d sync、render/overlay/tile 分支、target/pre-confirm 路由。view/input 中所有 `complexity >= 9` 的热点必须拆成 step helpers；简单热点优先靠覆盖率过线。
- validation: 相关 presentation suites 通过；重新跑 CRAP 后，T6 负责的 view/input 文件不再出现 `crap > 8`。
- status: In Progress
- log: 2026-03-12 已继续拆分 `item_slots.lua`、`game_action.lua`、`canvas_coordinator.lua`、`action_anim.lua` 的输入/画布/动画路径；`suites.presentation.presentation_item_slots`、`suites.presentation.presentation_choice_routes`、`suites.presentation.presentation_target_pick`、`suites.presentation.presentation_action_anim_core`、`suites.presentation.presentation_board_feedback` 定向回归通过。
- log: 2026-03-12 补充 presentation T6 characterization tests：覆盖 item_slot pre-confirm 打开 secondary confirm、`item_phase_ask` 单选项直接 dispatch、`anim_tip_text` 的 named/fallback player 与 clear_obstacles/change_skin 文案、`player_units` 的 `resolve_roles`/`resolve_role` fallback；定向套件 `presentation_market_confirm_flow`、`presentation_action_anim_core`、`presentation_board_sync`、`presentation_item_slots` 通过。最新 CRAP 将 T6 residual 压到 28。

### T7 Infrastructure/app/core sweep
- depends_on: `[T1]`
- location: `/Users/billyq/Dev/Github/Lua/monopoly/src/infrastructure/runtime/`、`/Users/billyq/Dev/Github/Lua/monopoly/src/app/`、`/Users/billyq/Dev/Github/Lua/monopoly/src/core/`；测试优先放在 `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/runtime/` 和 `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/architecture/`
- description: 清理 bootstrap/runtime/core 的低覆盖热点，包括 synthetic actors、default ports、runtime context、bootstrap wiring、config/state access；优先做小型同层抽取或直接补测。任何生产代码中新加的数值判断继续遵守 `NumberUtils` 约束。
- validation: runtime/contract/guard suites 通过；`lua scripts/arch.lua check` 保持通过；重新跑 CRAP 后，T7 负责的文件不再出现 `crap > 8`。
- status: In Progress
- log: 2026-03-12 已拆分 `synthetic_actor_registry.lua`、`context.lua`、`ui_bootstrap.lua` 的 fallback/anchor/wiring helper，并补充 runtime misc 覆盖；`lua scripts/arch.lua check` 与 `suites.runtime.misc` 通过。
- log: 2026-03-12 继续收尾 T7：重构 `eggy_paid_purchase_gateway` 的 paid goods mapping 流程与 `landing_visual_hold` 的 dirty/hold helper，给 `runtime.misc` 与 `gameplay_runtime_context_and_camera_sync` 补充 vehicle enter delay、wall diff、startup synthetic actors、landing_visual_hold deferred dirty、runtime editor camera target 覆盖；定向回归与 `lua scripts/arch.lua check` 通过。最新 CRAP 将 T7 residual 从 23 降到 14。
- log: 2026-03-12 继续用覆盖率吃 T7 低复杂度热点：为 `config_sanity.lua` 补充 release build 车辆内容拒绝、board feedback 缺失 effect/sound/followup 引用、未知 vehicle 引用，以及 `validate()` 缓存短路等 characterization tests；定向 suite `tests.suites.domain.config_sanity` 通过，待下一轮双 lane CRAP 确认 residual 变化。
- log: 2026-03-12 补充 `app/init.lua` 的 release/debug provider wiring 与 scheduler fallback 覆盖，修正 startup harness 对 `GlobalAPI`/`SetTimeOut` 生命周期的假设；定向 suite `tests.suites.runtime.startup_release` 通过。

### T8 Residual sweep and merge-safe cleanup
- depends_on: `[T2, T3, T4, T5, T6, T7]`
- location: 任意仍残留热点的源码文件；仅此任务允许碰共享测试 support
- description: 全量重跑 CRAP，按分数倒序收尾所有残留 `>8`。规则固定：`complexity >= 9` 先拆；`complexity <= 8` 先补测。若并行阶段产生了重复的 suite-local helpers，在这里统一合并；这是唯一允许做共享 support 收口的任务。
- validation: 重新生成的报告中，整个 `src/**/*.lua` 零个函数 `crap > 8`。
- status: In Progress
- log: 2026-03-12 最新双 lane CRAP 已降到 `src_over8=130`；当前 ownership bucket 为 `T2=30`、`T3=1`、`T4=27`、`T5=29`、`T6=28`、`T7=14`、`UNKNOWN=1`。本阶段已开始按最新报告继续收尾，但尚未清零。
- log: 2026-03-12 继续按最新报告收尾后，双 lane CRAP 更新为 `src_over8=129`；当前 ownership bucket 为 `T2=29`、`T3=1`、`T4=27`、`T5=29`、`T6=28`、`T7=14`、`UNKNOWN=1`。剩余头部热点已切到 `turn_script`、presentation runtime/view 的低覆盖 helper，以及 `effect_pipeline.run`。
- log: 2026-03-12 再跑一轮 T2 收尾后，双 lane CRAP 保持降到 `src_over8=123`；当前 ownership bucket 为 `T2=23`、`T3=1`、`T4=27`、`T5=29`、`T6=28`、`T7=14`、`UNKNOWN=1`。当前头部已基本转移到 `T5/T6/T7` 的 presentation/runtime helper 与 `app/init.lua`、`config_sanity.lua`。

### T9 Final verification
- depends_on: `[T8]`
- location: `/Users/billyq/Dev/Github/Lua/monopoly`
- description: 跑全量回归、架构检查和最终 CRAP 报告，并保留最后的 hotspot 输出作为证据。本轮保持 CRAP 为 report-only，不新增 failing CI/guard。
- validation: `MONO_REGRESSION_MODE=release_trimmed lua tests/regression.lua`、`lua scripts/arch.lua check`、`lua scripts/crap.lua report --lane behavior --lane contract --out tmp/crap_report.json --top 20` 全部成功，且最大函数 CRAP `<= 8`。

## 测试场景

- gameplay wait/turn：seq 不匹配继续等待、action anim 队列排空、landing visual hold 释放、detained/inter-turn 过渡、move_followup 恢复。
- systems/core：`place_mine`/`clear_obstacles`、bankruptcy winner/loser feedback、market visibility filtering、seat enter/exit/resync、board/chance side effects。
- presentation model/runtime：dirty flags 只刷新对应 slice、modal open/close、popup defer/replay、secondary confirm 文案刷新、game-result panels、event defer/flush。
- presentation view/input + infra/app：board scene init 宿主缺失保护、status3d/overlay/tile rendering 分支、target pick/pre-confirm 路由、synthetic actor/bootstrap/default ports/context fallback。

## 假设与默认值

- CRAP 真源固定为 behavior + contract 双 lane；单 lane 结果不作为最终验收。
- 本轮不修改 `/Users/billyq/Dev/Github/Lua/monopoly/scripts/crap.lua`，不修改 `/Users/billyq/Dev/Github/Lua/monopoly/tests/catalog.lua`，也不把 CRAP 变成新的强制 guard。
- 新 helper 优先留在原文件；只有函数仍 `> 8` 或测试 seam 明显过差时，才允许在同层目录内新建小模块。
- `/Users/billyq/Dev/Github/Lua/monopoly/src/` 下新增数值判断继续遵守 `NumberUtils` 规则，不引入 `tonumber` 或 `type == "number"`。
