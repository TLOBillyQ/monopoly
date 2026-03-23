# CRAP 热点函数补测与减复杂度计划

本可执行计划是活文档。实施过程中必须持续更新“进度”“意外与发现”“决策日志”“结果与复盘”。本文件必须遵循 `.agents/harness/PLANS.md` 维护，并最终替换当前 `.agents/plan.md` 中与本任务无关的旧计划内容。

## 目的 / 全局视角

`.agents/research.md` 已经把本轮范围冻结为 14 个 CRAP 热点，集中在道具可用性、运行时角色解析、UI 反馈、棋盘寻路、AI 评分和测试 profile 工厂。用户可见目标不是“让分数好看”，而是让这些热点在不改变玩法和 UI 行为的前提下拥有更稳的测试护栏，并把一个函数里混写的多件事拆成可读、可验证的小步骤。完成后，运行 `lua tests/behavior.lua`、`lua tests/contract.lua`、`lua tests/guard.lua`、`lua tools/quality/arch.lua check` 和 `lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json`，应看到回归全绿，且 research 里点名的每个函数都相对基线出现“覆盖上升、CRAP 下降或直接退出热点列表”的可观察改进。

## 进度

- [x] (2026-03-23 21:31 CST) 已完成只读调研：读取 `.agents/research.md`、`.agents/harness/PLANS.md`、`.agents/harness/READING.md`、`.agents/harness/CODING.md`，并核对热点源码、相邻测试和质量命令。
- [x] (2026-03-23 21:50 CST) 已在 `.agents/plan.md` 落地活文档，并把 14 个冻结目标函数的基线 CRAP / coverage 写入“意外与发现”；同时完成两次 `mutate --scan` 和一次本地 `crap` 基线报告。
- [x] (2026-03-23 21:50 CST) 已完成 T0 基线冻结与命令脚本化；当前可按依赖图启动第二波 T1 / T3 / T4 / T5 / T6。
- [x] (2026-03-23 22:15 CST) 已完成 T1 道具可用性与 item phase 热点治理：补齐 `trigger_timing_allowed` / rent-response / `build_wait_choice_args` 的 characterization tests，并把 availability / phase helper 拆回单一职责。
- [x] (2026-03-23 22:15 CST) 已完成 T2 preconsume / validator / choice_handlers 热点治理：补齐 preconsume decorator、slot action validator 和 choice handler 串联验证，把 item choice 解析改成线性 helper 管道。
- [x] (2026-03-23 22:15 CST) 已完成 T3 runtime context 角色解析热点治理：补齐 provider/GameAPI fallback 与 `_safe_get_role` 边界测试，保持 `get_roles()` 不吞异常。
- [x] (2026-03-23 22:15 CST) 已完成 T4 UI 动画 / event handler / turn label 热点治理：补齐地雷反馈、tile index 解析与 turn label helper 测试，并把匿名闭包提名为 `_refresh_turn_label_for_runtime_role`。
- [x] (2026-03-23 22:15 CST) 已完成 T5 棋盘 backward / ring map 热点治理：补齐 backward 优先级和 ring map direction 行为覆盖，并把 backward 解析拆成来源明确的小 helper。
- [x] (2026-03-23 22:15 CST) 已完成 T6 AI 评分 / test profile 工厂热点治理：补齐 `_remote_priority` 六类 rank 和 `_profile` copy/bootstrap 行为证明，并把 AI 评分规则拆成轻量分发。
- [x] (2026-03-23 22:15 CST) 已完成 T7 全量回归、CRAP 对比和结果回写：`behavior / contract / guard / arch / crap` 全绿，14 个冻结热点全部相对基线改善。

## 意外与发现

- 观察：当前 `.agents/plan.md` 已经是另一项已完成工作的活文档，内容与 tip queue 拆分有关，本轮必须整体替换，不能在旧计划尾部追加。
  证据：现有 `.agents/plan.md` 标题为 `show_tips 去冗余与独立队列化`，且“结果与复盘”已经写到完成态。
- 观察：`src/host/eggy/context.lua` 的 `resolve_any_role` / `_safe_get_role` 已经在 `tests/suites/runtime/misc.lua` 有相邻测试入口，优先在这里补 characterization，比直接走 gameplay 集成更快也更精确。
  证据：`tests/suites/runtime/misc.lua` 380、410、430、460 行附近已经覆盖 `helper.resolve_any_role()`。
- 观察：`ui_runtime.refresh_turn_label` 的现有调用验证挂在 `tests/suites/presentation/_presentation_action_status_status3d_and_panel_cases.lua`，不是 `presentation_ui_role_slots.lua`。
  证据：`_presentation_action_status_status3d_and_panel_cases.lua` 1263 行已经 patch `ui_view_service.refresh_turn_label`。
- 观察：仓库已经有专门承接 CRAP 清理的 characterization 桶，避免新建零散 suite 更符合现有组织方式。
  证据：`tests/suites/gameplay/gameplay_t2_characterization.lua`、`tests/suites/gameplay/gameplay_t4_characterization.lua`、`tests/suites/presentation/gameplay_t5_characterization.lua`、`tests/suites/presentation/gameplay_t6_characterization.lua` 已在 `tests/catalog.lua` 注册。
- 观察：`src/config/testing/test_profiles.lua:1` 的 `_profile` 是文件顶层 local helper；如果只跑高层 startup suite，coverage 可能不会稳定命中这个 factory，需要在测试里显式 `package.loaded[...] = nil` 后重载原模块。
  证据：review 子代理指出高层 `startup_profile` 断言不足以稳定覆盖 `_profile` 本体。
- 观察：2026-03-23 本地重新生成的 `tmp/crap_report.json` 结构以 `.functions` 为主，直接对比 14 个冻结目标时以 CLI 的 `top_hotspots` 摘要和手工过滤更可靠；同时排行榜第 10 名变成了 `runtime_install.M.install`，但冻结范围仍保持 research 的 14 个函数不变。
  证据：`lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json` 输出的 `top_hotspots` 中，`anonymous@42` 已退到第 15 名，而不是 research 中的第 14 名。
- 观察：T0 基线已冻结，后续所有任务都应对照以下 14 个函数，而不是只看榜单前 20 名。
  证据：
  - `_can_offer_rent_response` | `src/rules/items/availability.lua:103` | CRAP 56.00 | coverage 0.00% | 任务 T1 | 守护套件 `tests/suites/domain/item_availability_matrix.lua`
  - `availability.trigger_timing_allowed` | `src/rules/items/availability.lua:70` | CRAP 12.00 | coverage 0.00% | 任务 T1 | 守护套件 `tests/suites/domain/item_availability_matrix.lua`
  - `phase_module.build_wait_choice_args` | `src/rules/items/phase.lua:121` | CRAP 12.00 | coverage 0.00% | 任务 T1 | 守护套件 `tests/suites/domain/item.lua`
  - `item_preconsume_policy.decorate_followup_choice_spec` | `src/core/choice/item_preconsume_policy.lua:51` | CRAP 30.00 | coverage 0.00% | 任务 T2 | 守护套件 `tests/suites/gameplay/gameplay_t2_characterization.lua`
  - `validator.resolve_item_slot_action` | `src/turn/actions/validator.lua:137` | CRAP 16.94 | coverage 71.00% | 任务 T2 | 守护套件 `tests/suites/presentation/ui_runtime_state_contract.lua`
  - `_safe_get_role` | `src/host/eggy/context.lua:15` | CRAP 20.00 | coverage 0.00% | 任务 T3 | 守护套件 `tests/suites/runtime/misc.lua`
  - `resolve_any_role` | `src/host/eggy/context.lua:51` | CRAP 30.00 | coverage 0.00% | 任务 T3 | 守护套件 `tests/suites/runtime/misc.lua`
  - `units.play_mine_trigger` | `src/ui/render/anim_units.lua:66` | CRAP 42.00 | coverage 0.00% | 任务 T4 | 守护套件 `tests/suites/presentation/presentation_action_anim_effect_routes.lua`
  - `_resolve_tile_index` | `src/ui/ctl/event_handlers.lua:130` | CRAP 25.02 | coverage 7.00% | 任务 T4 | 守护套件 `tests/suites/presentation/presentation_ui_event_handlers.lua`
  - `anonymous@42` | `src/ui/ctl/ui_runtime.lua:42` | CRAP 12.00 | coverage 0.00% | 任务 T4 | 守护套件 `tests/suites/presentation/_presentation_action_status_status3d_and_panel_cases.lua`
  - `_resolve_backward_next_id` | `src/rules/board/init.lua:155` | CRAP 16.00 | coverage 50.00% | 任务 T5 | 守护套件 `tests/suites/domain/movement.lua`
  - `_direction` | `src/config/content/maps/ring_map_builder.lua:48` | CRAP 12.00 | coverage 0.00% | 任务 T5 | 守护套件 `tests/suites/gameplay/gameplay_t4_characterization.lua`
  - `_remote_priority` | `src/computer/policies/core_agent.lua:54` | CRAP 13.05 | coverage 42.00% | 任务 T6 | 守护套件 `tests/suites/domain/land.lua`
  - `_profile` | `src/config/testing/test_profiles.lua:1` | CRAP 12.00 | coverage 0.00% | 任务 T6 | 守护套件 `tests/suites/runtime/startup_profile.lua`
- 观察：`lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json` 实际把报告写到系统临时目录的 `monopoly_crap/crap_report.json`，仓库里的 `tmp/crap_report.json` 可能是旧文件，不能直接用于 T7 对账。
  证据：最新有效报告位于 `/var/folders/qw/32_j34_d44zbrwgwp0_x487h0000gn/T/monopoly_crap/crap_report.json`，其 `generated_at` 为 `2026-03-23T14:12:27Z`；而仓库内 `tmp/crap_report.json` 的 `generated_at` 仍是 `2026-03-14T08:50:05Z`。
- 观察：`_test_ui_runtime_refresh_turn_label_toggles_countdown_nodes_and_label` 虽然断言正确，但初版没有被聚合到 behavior lane；只有把它加入 `tests/suites/presentation/_presentation_action_status_groups.lua` 的 `status3d_and_turn_effects` 组，`_refresh_turn_label_for_runtime_role` 才真正获得覆盖。
  证据：补齐聚合前，系统临时 CRAP report 中 `src/ui/ctl/ui_runtime.lua:_refresh_turn_label_for_runtime_role` 仍是 `crap=12`、`coverage=0`；补齐后降为 `crap=3`、`coverage=1`。

## 决策日志

- 决策：本轮范围固定为 `.agents/research.md` 已展开的 14 个热点，不扩到 top 20 其余函数。
  理由：research 对这 14 个函数已经给出拆解方向与测试建议，足够形成 decision-complete 计划；其余 6 个函数暂无同等细化，混入会抬高并行协调成本。
  日期/作者：2026-03-23 / Codex
- 决策：优先扩展现有 suite 和 characterization bucket，不新建额外测试车道。
  理由：现有 `behavior / contract / guard` 和 T2/T4/T5/T6 characterization 文件已经入 catalog，直接复用能减少注册改动和并行冲突。
  日期/作者：2026-03-23 / Codex
- 决策：对高风险函数先补 characterization tests，再做 helper 提炼；低复杂度但 0% coverage 的函数以补覆盖为主，不为降分强行拆文件。
  理由：这与 `.agents/research.md` 的顺序一致，也符合仓库“小步、保行为、不做过度设计”的规则。
  日期/作者：2026-03-23 / Codex
- 决策：T2 明确加入 `src/rules/items/choice_handlers.lua` 的集成验证，确保 phase decorator 与 preconsume decorator 的顺序不漂移。
  理由：单测两个 decorator 本身不足以发现真实 choice reopen / cancel 路径的回归。
  日期/作者：2026-03-23 / Codex
- 决策：T3 保持当前容错边界，不把 `get_roles()` 包进新的 `pcall`。
  理由：现状只有 GameAPI 调用是容错边界；如果顺手扩大异常吞噬范围，会改变 runtime helper 的错误语义。
  日期/作者：2026-03-23 / Codex
- 决策：T0 之后的第二波按写集并行执行 `T1 + T3 + T4 + T5 + T6`，但活文档 `.agents/plan.md` 只由主代理串行回写，避免多代理同时写计划文件产生冲突。
  理由：业务文件写集天然解耦，适合并行；而计划文件是共享热点，集中回写更稳。
  日期/作者：2026-03-23 / Codex
- 决策：T7 的 CRAP 对账以系统临时目录中的最新 report 为准，不读取仓库内陈旧的 `tmp/crap_report.json`。
  理由：质量工具会把 `tmp/...` 映射到系统临时目录；仓库内同名文件只是历史残留，若直接读取会把旧数据误当成本轮结果。
  日期/作者：2026-03-23 / Codex

## 结果与复盘

本轮已按依赖图完成 T1-T7，并把 14 个冻结热点全部拉出当前 `top_hotspots`。最终验收命令 `lua tests/behavior.lua`、`lua tests/contract.lua`、`lua tests/guard.lua`、`lua tools/quality/arch.lua check`、`lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json` 全部通过；其中行为车道为 `1139` 绿例，契约车道为 `83` 绿例，guard 输出 `dep_rules ok / gameplay_loop_no_ui ok / forbidden_globals ok / arch_view_guard ok / repo_hygiene ok`，架构检查输出 `arch_view 检查通过 / arch_view check ok`。

新增的稳定护栏主要集中在六个 owner suite 簇：`tests/suites/domain/item_availability_matrix.lua` 与 `tests/suites/domain/item.lua` 守住 item availability / phase；`tests/suites/gameplay/gameplay_t2_characterization.lua` 与 `tests/suites/presentation/ui_runtime_state_contract.lua` 守住 preconsume / validator；`tests/suites/runtime/misc.lua` 与 `tests/suites/gameplay/gameplay_runtime_context_and_camera_sync.lua` 守住 runtime context；`tests/suites/presentation/presentation_action_anim_effect_routes.lua`、`tests/suites/presentation/presentation_ui_event_handlers.lua`、`tests/suites/presentation/_presentation_action_status_status3d_and_panel_cases.lua` 守住 UI 反馈；`tests/suites/domain/movement.lua` 与 `tests/suites/gameplay/gameplay_t4_characterization.lua` 守住 backward / ring map；`tests/suites/domain/land.lua` 与 `tests/suites/runtime/startup_profile.lua` 守住 AI/profile。对应的局部重构都收敛为同文件 `local helper`，没有新增 shim、没有改公开模块名、没有新增 test lane。

按 T0 基线对比，本轮 14 个函数的结果如下，全部满足“coverage 提升或 CRAP 下降”：

- T1：`_can_offer_rent_response` 从 `CRAP 56.00 / coverage 0.00%` 降到 `CRAP 3.03 / coverage 86%`；`availability.trigger_timing_allowed` 从 `12.00 / 0.00%` 降到 `3.03 / 86%`；`phase_module.build_wait_choice_args` 从 `12.00 / 0.00%` 降到 `2.03 / 80%`。
- T2：`item_preconsume_policy.decorate_followup_choice_spec` 从 `30.00 / 0.00%` 降到 `1.00 / 86%`；`validator.resolve_item_slot_action` 从 `16.94 / 71%` 降到 `5.39 / 75%`。
- T3：`_safe_get_role` 从 `20.00 / 0.00%` 降到 `2.01 / 86%`；`resolve_any_role` 从 `30.00 / 0.00%` 降到 `1.00 / 100%`。
- T4：`units.play_mine_trigger` 从 `42.00 / 0.00%` 降到 `3.00 / 92%`；`_resolve_tile_index` 从 `25.02 / 7%` 降到 `1.04 / 67%`；`anonymous@42` 提名为 `_refresh_turn_label_for_runtime_role` 后，从 `12.00 / 0.00%` 降到 `3.00 / 100%`。
- T5：`_resolve_backward_next_id` 从 `16.00 / 50%` 降到 `3.02 / 88%`；`_direction` 从 `12.00 / 0.00%` 降到 `3.02 / 88%`。
- T6：`_remote_priority` 从 `13.05 / 42%` 降到 `2.01 / 86%`；`_profile` 从 `12.00 / 0.00%` 降到 `2.00 / 100%`。

五个高风险热点的守护证据也已经补齐：`_can_offer_rent_response` 由 `item_availability_matrix` 守住 rent-response 上下文和余额边界；`units.play_mine_trigger` 由 `presentation_action_anim_effect_routes` 守住 player cue / tile cue / 最小时序归一化；`validator.resolve_item_slot_action` 由 `ui_runtime_state_contract` 与 `gameplay_t2_characterization` 守住 option / availability / handler 串联；`_resolve_backward_next_id` 由 `movement.lua` 与 `gameplay_t4_characterization.lua` 守住 backward 来源优先级；`_remote_priority` 由 `domain/land.lua` 守住六类 tile rank 与敌方地块负租金 score。到本轮收尾时，没有剩余冻结热点维持基线风险；新的 `top_hotspots` 已换成本轮范围外的函数，说明本次目标已经完成。

## 背景与导读

本轮工作跨越六个子系统。`src/rules/items/availability.lua` 与 `src/rules/items/phase.lua` 负责道具出牌窗口和 item phase 的 choice 恢复；`src/core/choice/item_preconsume_policy.lua`、`src/turn/actions/validator.lua` 与 `src/rules/items/choice_handlers.lua` 负责 preconsume choice 的取消、恢复和 item slot 输入校验；`src/host/eggy/context.lua` 负责 runtime helper 装配与角色解析；`src/ui/render/anim_units.lua`、`src/ui/ctl/event_handlers.lua`、`src/ui/ctl/ui_runtime.lua` 负责地雷反馈、runtime event 到 UI 反馈的映射，以及 turn label 刷新；`src/rules/board/init.lua` 与 `src/config/content/maps/ring_map_builder.lua` 负责 backward 路径选择和 ring map 方向计算；`src/computer/policies/core_agent.lua` 与 `src/config/testing/test_profiles.lua` 则分别负责 remote dice 的 AI 排序与测试 profile 工厂。

冻结的 14 个目标函数分别是：`_can_offer_rent_response`、`availability.trigger_timing_allowed`、`phase_module.build_wait_choice_args`、`item_preconsume_policy.decorate_followup_choice_spec`、`validator.resolve_item_slot_action`、`_safe_get_role`、`resolve_any_role`、`units.play_mine_trigger`、`_resolve_tile_index`、`anonymous@42`（也就是 `ui_runtime.refresh_turn_label` 中的匿名闭包）、`_resolve_backward_next_id`、`_direction`、`_remote_priority`、`_profile`。它们的共同问题不是同一种实现错误，而是“测试缺口 + 多职责混写”叠加后，让小改动很难证明没有破坏行为。

本计划的执行方式是先在 T0 记录每个函数的基线，再按写集切成 7 个任务。T1 与 T2 串行，因为它们同属 item flow 且共享 item/choice 语义；T3、T4、T5、T6 在 T0 之后可以并行；T7 只做总验收和结果回写。每个任务都必须只改自己声明的文件，避免跨波次互相踩写。

## 依赖图

    T0 ──┬── T1 ── T2 ──┐
         ├── T3 ────────┤
         ├── T4 ────────┤
         ├── T5 ────────┤── T7
         └── T6 ────────┘

第一波只做 T0。第二波同时推进 T1、T3、T4、T5、T6。第三波在 T1 收口后推进 T2。第四波执行 T7，并把验证结果回写到“进度”“意外与发现”“决策日志”“结果与复盘”。

## 任务编排

### T0 基线冻结与活文档落地

T0 不改业务代码，只负责把实施支点钉住。它依赖空数组，独占 `.agents/plan.md`。先把本计划完整写入 `.agents/plan.md`，保留本文件所有章节；再在工作目录 `/Users/billyq/Dev/Github/Lua/monopoly` 运行 `lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json`，把 `.agents/research.md` 里的 14 个函数与新生成报告逐一对齐，记录函数名、文件、基线 CRAP、基线 coverage、目标验证套件和所属任务。这里还要补两次便宜的风险探针：`lua tools/quality/mutate.lua src/rules/items/availability.lua --scan` 与 `lua tools/quality/mutate.lua src/ui/render/anim_units.lua --scan`，只做扫描，不做完整 mutation 回合。T0 完成的标志是：`.agents/plan.md` 已经成为完整自足的活文档，且后续每个任务都能拿着这里记录的基线做一对一比较，而不是只看榜单名次。

### T1 道具可用性与 item phase 热点

T1 依赖 T0，独占 `src/rules/items/availability.lua`、`src/rules/items/phase.lua`、`tests/suites/domain/item_availability_matrix.lua`、`tests/suites/domain/item.lua` 和 `tests/suites/gameplay/gameplay_items_startup.lua`。先补 characterization tests，再提炼 helper。`availability.trigger_timing_allowed` 必须覆盖 `phase=nil` 且 `allow_missing_phase=true/false`、unknown phase、`timing=nil`、unknown timing、known mapping。`_can_offer_rent_response` 必须覆盖无 board 或无 tile、非 land、owner 是自己、owner 是他人时 `free_rent` 可用、`strong` 在余额恰好等于租金时可用、余额不足时不可用。`phase_module.build_wait_choice_args` 必须覆盖 `meta=nil` 的 assert、`resume_next_args=nil` 的透传，以及正常恢复路径。测试稳定后再把 `availability.lua` 拆成“上下文解析 + 资格判断 + strong 特例余额判定”三段，把 `phase.lua` 保持为小 helper 提炼，不引入新模块，不改变导出函数签名。T1 完成后先跑 `lua tests/behavior.lua` 和 `lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json`，确认这三处基线已经改善，再进入 T2。

### T2 preconsume / validator / choice_handlers 热点

T2 依赖 T1，独占 `src/core/choice/item_preconsume_policy.lua`、`src/turn/actions/validator.lua`、`src/rules/items/choice_handlers.lua`、`tests/suites/presentation/ui_runtime_state_contract.lua` 和 `tests/suites/gameplay/gameplay_t2_characterization.lua`。这里不要再往 `tests/suites/domain/item.lua` 塞新断言，避免和 T1 反复交叉。`decorate_followup_choice_spec` 要覆盖空 `choice_spec` 原样返回、`item_preconsumed=true` 标记、已有 `meta.item_id/player_id` 不被覆盖、无上下文时只打 preconsume 标记。`validator.resolve_item_slot_action` 要覆盖 wrong pending choice kind、缺失 `resolve_slot_action`、缺失 `choice.options` 的 assert 行为、blank `choice.meta.phase` 时跳过 availability 复核、找不到 actor 但 option 合法时仍能继续、option 不存在时返回 `{ ok = false }`。然后补一条真实集成断言，直接通过 `choice_handlers.lua` 走一遍 phase decorator 与 preconsume decorator 的串联，锁住 cancel/meta 的组合顺序。代码重构时把 validator 改成“resolve choice → resolve slot → validate option → validate availability → build action”的线性管道，每一步都由小 helper 返回明确结果；`item_preconsume_policy` 只保留 nil guard 与编排。T2 结束后跑 `lua tests/behavior.lua`、`lua tests/contract.lua` 和 `lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json`。

### T3 runtime context 角色解析热点

T3 依赖 T0，独占 `src/host/eggy/context.lua`、`tests/suites/runtime/misc.lua` 和 `tests/suites/gameplay/gameplay_runtime_context_and_camera_sync.lua`。主验证放在 `tests/suites/runtime/misc.lua`，因为这里已经有 `resolve_any_role` 的相邻断言；`gameplay_runtime_context_and_camera_sync.lua` 只补一条装配层集成检查，确保 helper 仍通过 install 流程可用。先锁住当前语义：`get_roles()` 不是 `pcall` 边界，只有 `get_all_valid_roles` 与 `get_role` 等 GameAPI 调用需要容错。测试应覆盖 provider roles 优先、provider 空且 GameAPI 返回有效列表、GameAPI 抛错、GameAPI 为空、`_safe_get_role` 的 nil role_id / 缺失 `get_role` / `pcall` 失败 / 成功返回。然后参考 `src/state/state_access/vehicle_runtime_source.lua` 的分层方式，提炼 provider roles、GameAPI valid roles、首个可用 role 与 `pcall` 包装，但不要扩大异常吞噬范围。T3 完成后跑 `lua tests/behavior.lua`、`lua tests/contract.lua`、`lua tools/quality/arch.lua check` 和一次新的 CRAP report。

### T4 UI 动画、event handler 与 turn label 热点

T4 依赖 T0，独占 `src/ui/render/anim_units.lua`、`src/ui/ctl/event_handlers.lua`、`src/ui/ctl/ui_runtime.lua`、`tests/suites/presentation/presentation_action_anim_effect_routes.lua`、`tests/suites/presentation/presentation_ui_event_handlers.lua` 和 `tests/suites/presentation/_presentation_action_status_status3d_and_panel_cases.lua`。`units.play_mine_trigger` 先补三种现状分支：单位坐标存在时走 player cue；单位坐标缺失但 tile 坐标存在时仍走 player cue，只是位置回退到 tile；两者都没有时才走 tile cue；另外补 `duration` / `snap_delay` 的最小值归一化。`_resolve_tile_index` 要覆盖显式 `payload.tile_index`、`payload.tile.id`、`payload.tile_id`、无 `context.state`、board 缺失 `index_of_tile_id`。`ui_runtime.refresh_turn_label` 的匿名闭包要在 `_presentation_action_status_status3d_and_panel_cases.lua` 里补直接断言，确认 `countdown` 与 `countdown_line` 的显隐和 label 更新，再把这个闭包提名为本地 helper，但不改变 `service.refresh_turn_label` 的公开签名。`event_handlers.lua` 只拆 payload 解析与 board/context 查询，不改变注册行为。T4 完成后跑 `lua tests/behavior.lua`、`lua tests/contract.lua`、`lua tools/quality/arch.lua check` 和新的 CRAP report。

### T5 backward 寻路与 ring map 方向热点

T5 依赖 T0，独占 `src/rules/board/init.lua`、`src/config/content/maps/ring_map_builder.lua`、`tests/suites/domain/movement.lua` 和 `tests/suites/gameplay/gameplay_t4_characterization.lua`。`_resolve_backward_next_id` 的测试要覆盖 facing 反向命中、`outer_prev` 命中、`backward_fallback` 命中、唯一方向回退、任意方向最终回退，保证优先级不变。`ring_map_builder._direction` 不能只靠 default map 侧面覆盖，必须在 builder 层直接覆盖 next、prev、wraparound、缺失 `from_id`、缺失 `to_id`、非法非相邻跳跃。重构时把 backward 解析拆成“按 facing 反推”“outer_prev/backward_fallback map 来源”“neighbors 回退来源”三层 helper；`_direction` 只做最小提炼或甚至只补测，不为这个短函数额外拆文件。T5 完成后跑 `lua tests/behavior.lua` 和新的 CRAP report。

### T6 AI remote priority 与 test profile 工厂热点

T6 依赖 T0，独占 `src/computer/policies/core_agent.lua`、`src/config/testing/test_profiles.lua`、`tests/suites/domain/land.lua`、`tests/suites/runtime/startup_profile.lua` 和必要时的 `tests/suites/presentation/gameplay_t6_characterization.lua`。`_remote_priority` 要直接验证 item、chance、unowned land、self-owned land、enemy-owned land、market 六类 rank，以及 enemy land 的 score 为负租金而不是正值。`_profile` 要做两层证明：第一层在 `tests/suites/runtime/startup_profile.lua` 里清空 `package.loaded["src.config.testing.test_profiles"]` 后重载原模块，直接命中 `_profile` 的 copy 逻辑；第二层通过高层 resolver 证明 meta 不共享引用、bootstrap 缺省为空表。代码重构时把 `_remote_priority` 改成轻量规则分发，保留现有 rank 顺序和 tie-break 语义，不改 `pick_remote_dice_value` 对外行为；`_profile` 以补测为主，最多提炼一个 `_copy_meta`，不要为了低复杂度热点引入更多样板。T6 完成后跑 `lua tests/behavior.lua` 和新的 CRAP report。

### T7 全量验收、逐函数对比与文档回写

T7 依赖 T2、T3、T4、T5、T6。它不再改设计，只做证明与回写。先运行 `lua tests/behavior.lua`、`lua tests/contract.lua`、`lua tests/guard.lua`、`lua tools/quality/arch.lua check`、`lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json`。然后把 T0 冻结的 14 个函数逐条拿出来对比最新报告，只接受三种结果之一：该函数不再出现在热点结果里；coverage 高于基线；CRAP 低于基线。对 `_can_offer_rent_response`、`units.play_mine_trigger`、`resolve_item_slot_action`、`_resolve_backward_next_id`、`_remote_priority` 这五个高风险热点，还要在“结果与复盘”里说明是哪一种改善，以及是哪组测试在守护它。最后把所有命令结果、关键 diff 摘要和剩余风险写回 `.agents/plan.md` 的四个活文档章节。

## 工作计划

实施顺序固定为“先基线，再分治，再总验收”。先把 `.agents/research.md` 的静态分析结果转成可比较的本地基线，因为研究文件里的报告路径指向临时目录，不是仓库事实源。之后按写集切任务：item flow 先做 T1，再在稳定的 offer/phase 语义上做 T2；runtime context、presentation、board、AI/profile 各自独立推进；最后统一回归。所有 `src/` 下的数值判断继续遵守项目规则，不能引入 `tonumber` 或 `type(x) == "number"`，需要沿用 `NumberUtils`。所有新 helper 都保持 `snake_case`，且只做一件事；不新增 shim/alias 文件，不把旧名兼容层留在 `src/`。

测试组织也要保持最小扰动。能放进现有 owner suite 的，直接放进去；只有当没有自然归属时，才落到现有的 characterization bucket。这里已经拍板：T1 用 `item_availability_matrix`、`item.lua` 与 `gameplay_items_startup.lua`； T2 用 `ui_runtime_state_contract.lua` 与 `gameplay_t2_characterization.lua`；T3 用 `runtime/misc.lua` 加一条 gameplay 集成；T4 用 `presentation_action_anim_effect_routes.lua`、`presentation_ui_event_handlers.lua` 与 `_presentation_action_status_status3d_and_panel_cases.lua`；T5 用 `movement.lua` 与 `gameplay_t4_characterization.lua`；T6 用 `domain/land.lua` 与 `runtime/startup_profile.lua`，必要时才把纯 coverage 用例补到 `presentation/gameplay_t6_characterization.lua`。不要新增新的 test lane，不要修改 `tests/catalog.lua`。

## 具体步骤

在 `/Users/billyq/Dev/Github/Lua/monopoly` 下先执行以下命令，把本地事实冻结下来。

    lua tools/quality/mutate.lua src/rules/items/availability.lua --scan
    lua tools/quality/mutate.lua src/ui/render/anim_units.lua --scan
    lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json

预期会得到可读取的扫描输出和新的 `tmp/crap_report.json`。把 14 个目标函数的当前 CRAP 与 coverage 抄回计划文档，再开始改代码。

每完成一个任务后，都在同一目录执行该波次的最小验证。T1、T5、T6 完成后至少运行：

    lua tests/behavior.lua
    lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json

T2 完成后运行：

    lua tests/behavior.lua
    lua tests/contract.lua
    lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json

T3 与 T4 完成后运行：

    lua tests/behavior.lua
    lua tests/contract.lua
    lua tools/quality/arch.lua check
    lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json

最后在 T7 运行完整验收：

    lua tests/behavior.lua
    lua tests/contract.lua
    lua tests/guard.lua
    lua tools/quality/arch.lua check
    lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json

预期行为是行为、契约、护栏与架构检查全部通过，新的 CRAP report 能对上 T0 记录的 14 个函数，并显示逐条改善。若某一波次验证失败，不要继续推进下一波；先把失败命令、报错片段和当前判断写回“意外与发现”，再修复本波次。

## 验证与验收

验收不是“代码更短”，而是“行为稳定、风险下降、证据完整”。行为侧的验收标准是：`lua tests/behavior.lua` 全绿，`lua tests/contract.lua` 与 `lua tests/guard.lua` 全绿，`lua tools/quality/arch.lua check` 不新增边界违例。风险侧的验收标准是：T0 记录的 14 个函数逐条都比基线更好，具体表现为退出报告、coverage 提升或 CRAP 下降。对于 0% coverage 的短函数，例如 `_direction`、`_profile`、`trigger_timing_allowed`、`build_wait_choice_args` 和匿名闭包，最低验收线是必须不再维持“0% coverage + 原始 CRAP”；对于高复杂度函数，例如 `_can_offer_rent_response`、`play_mine_trigger`、`resolve_item_slot_action`、`_resolve_backward_next_id`、`_remote_priority`，最低验收线是既有行为测试继续通过，且 report 相比基线有数值改善。

## 可重复性与恢复

所有命令都应可重复执行。`tmp/crap_report.json` 是临时产物，可以反复覆盖，不应提交到仓库。若某个任务重构到一半导致回归失败，先保留测试，再回退刚提炼的 helper 拆分，而不是删除新测试；测试是这轮工作的护栏，不是可选附属物。若需要缩小排查面，只回退当前任务声明的文件，不跨任务回滚。完成后确保 `.agents/plan.md` 中的“进度”“意外与发现”“决策日志”“结果与复盘”与当前工作树一致，避免下一位执行者从错误状态继续。

## 产物与备注

这里应持续放入短证据，而不是大段日志。建议保留三类片段：一段 baseline 与 final CRAP 对比；一段最关键测试通过的输出；一段能证明 helper 拆分后行为未变的断言摘要。示例应控制在几行内，只保留能证明“热点已经被测住、而且行为没漂”的最小证据。

## 接口与依赖

本计划不引入新依赖，不新增新测试车道，不改变任何公开模块名。以下公开函数必须保持签名与调用方式不变：`availability.can_offer_in_phase`、`availability.trigger_timing_allowed`、`phase_module.build_wait_choice_args`、`item_preconsume_policy.decorate_followup_choice_spec`、`validator.resolve_item_slot_action`、`runtime_context.install_runtime_helpers`、`units.play_mine_trigger`、`service.refresh_turn_label`、`agent.pick_remote_dice_value`。所有变更都限于这些公开接口背后的局部 helper 提炼与测试补强。若需要新增 helper，只能作为同文件 `local function`，并保持依赖方向不跨层：rules 不能直连 UI，UI helper 不能把宿主细节拉回 core/rules，runtime context 不能新增对 gameplay 规则层的依赖。

2026-03-23 21:31 CST：本次更新将 `.agents/research.md` 的 14 个 CRAP 热点整理成 7 个带依赖的执行任务，补充了现有 suite 落点、波次验证命令和逐函数验收标准，原因是让下一位实现者无需外部上下文即可直接执行，并且能在每一波后证明风险确实下降。
2026-03-23 22:15 CST：本次更新回写了 T1-T7 的完成态，补充了系统临时 CRAP report 路径与 T4 behavior lane 聚合入口这两条关键发现，并把最终 `behavior / contract / guard / arch / crap` 验证结果及 14 个冻结热点的基线→现状对账写入“结果与复盘”，原因是让后续执行者直接看到本轮已经闭环且验收通过。
