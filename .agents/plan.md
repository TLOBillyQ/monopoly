# /simplify 并行执行计划

本计划是活文档。实施过程中必须持续更新“进度”“意外与发现”“决策日志”“结果与复盘”四个章节。
本文件遵循 `./.agents/harness/PLANS.md` 规范维护。

## 目的 / 全局视角

这次工作是在不改变玩家可见行为的前提下，收敛 dirty bucket、choice owner 解析、route 解析、intent 事件派发、action animation guard 的重复逻辑。

交付完成后，玩家侧应当“无感知”；开发侧应当得到更少的重复入口、更清晰的跨层责任、更稳定的验证路径。证明方式不是“代码看起来更干净”，而是行为 / 契约 / guard / arch 车道继续通过，并且 plan 中每个任务都记录了实际证据。

## 执行上下文

本仓库的单 suite 文件不是可靠的直接运行入口。测试与质量检查必须通过仓库车道入口执行：

    lua tests/behavior.lua
    lua tests/contract.lua
    cmd /c lua tests/guard.lua
    cmd /c lua tools/quality/arch.lua check

说明：
- `behavior` / `contract` 可直接从 PowerShell 运行。
- `guard` / `arch` 在当前 PowerShell 里直接调用会触发 `runtime_paths.lua` 的 repo_root 解析失败；在当前环境中确认可运行的方式是 `cmd /c lua ...`。
- 下面每个任务都必须优先跑本任务对应的定向验证，再进入最终全量车道。

## 进度

- [x] (2026-03-19 11:xx HKT) 完成 T0：重写并行计划格式，补齐任务依赖、状态字段、日志字段、文件字段，以及可运行验证上下文。
- [x] (2026-03-19 11:xx HKT) 记录当前基线：`lua tests/behavior.lua` 通过，输出 `All regression checks passed (999)`。
- [x] (2026-03-19 11:xx HKT) 记录当前基线：`cmd /c lua tests/guard.lua` 通过；`cmd /c lua tools/quality/arch.lua check` 通过。
- [x] (2026-03-19 12:xx HKT) 完成 Wave 2：T1 / T2 / T3 由并行 worker 落地，T4 由主执行者本地落地，并分别提交。
- [x] (2026-03-19 12:xx HKT) 完成 T5：收敛 intent event 发射路径，并修复一次真实回归后恢复行为全绿。
- [x] (2026-03-19 12:xx HKT) 完成 T6：补齐最终证据与复盘；按用户要求跳过 `contract`，不将其作为本轮阻塞项。

## 意外与发现

- 观察：原始 `/.agents/plan.md` 只适合人类阅读，不适合并行 agent 回写；缺少每个任务的状态、日志、修改文件字段。
  证据：旧文件只有 `depends_on / location / description / validation`。

- 观察：原始计划里的“直接跑 suite 文件”验证命令在本仓库不成立，因为 suite 依赖 `tests.bootstrap` 注入 package path。
  证据：直接运行 `lua tests/suites/runtime/misc.lua` 会报 `module 'support.runtime_support' not found`。

- 观察：`guard` / `arch` 在当前 PowerShell 里直接运行会触发 `runtime_paths.lua` 的 repo_root 解析失败，但通过 `cmd /c lua ...` 可正常通过。
  证据：

    lua tests/guard.lua
    -> failed to resolve repo_root from source path

    cmd /c lua tests/guard.lua
    -> dep_rules ok / gameplay_loop_no_ui ok / forbidden_globals ok / arch_view_guard ok

    cmd /c lua tools/quality/arch.lua check
    -> arch_view 检查通过 / arch_view check ok

- 观察：T5 初版把 intent 事件改成动态走 `monopoly_event.emit` 后，`landing.upgrade_land_prefers_direct_ui_notify_before_event_bridge` 回归失败。
  证据：

    lua tests/behavior.lua
    -> Regression failed (1/999)
    -> landing.upgrade_land_prefers_direct_ui_notify_before_event_bridge

  修复：保留 `emit_intent()` 统一入口，但改为走 `monopoly_events.lua` 内部 `_emit_event()`，不再动态回调可 patch 的 `monopoly_event.emit`。

- 观察：`tests/contract.lua` 在当前 shell 里直接运行会因为 `tools/shared/lib/loc_scan.lua` 触发 repo_root 解析失败；本轮用户明确要求先跳过 contract。
  证据：

    lua tests/contract.lua
    -> failed to resolve repo_root from source path: .../tools/shared/lib/loc_scan.lua

## 决策日志

- 决策：T0 由主执行者串行完成，不交给并行 worker。
  理由：T0 是所有后续任务的阻塞前置，而且它负责同一份计划文件的结构性改写，适合在主线程先锁定格式与执行约束。
  日期/作者：2026-03-19 / Codex

- 决策：`.agents/plan.md` 的结构性改写只允许 T0 执行，T6 只允许追加结果证据，不再重排章节。
  理由：避免多个 worker 并发编辑同一份计划导致冲突。
  日期/作者：2026-03-19 / Codex

- 决策：`choice_contract` 只收敛纯字段解析，不吸收 `game` / current-player fallback。
  理由：保持 core 纯度，避免把外层运行时上下文倒灌进共享核心模块。
  日期/作者：2026-03-19 / Codex

- 决策：`T2` 与 `T3` 虽然都涉及 choice 语义，但在并行执行时拆成不重叠写集；`target_choice_effects.lua` 归 T3。
  理由：缩短关键路径，同时避免并行冲突。
  日期/作者：2026-03-19 / Codex

- 决策：保留 `intent` 事件的统一发射入口，但不让它通过可 patch 的 `monopoly_event.emit` 动态分发。
  理由：这样既能消除 `intent_dispatcher` 内部的重复样板，又能保持既有测试对 direct UI notify / event bridge fallback 的观察边界。
  日期/作者：2026-03-19 / Codex

- 决策：本轮按用户要求跳过 `contract`，最终验收以 `behavior + guard + arch` 为准，并把 `contract` 留作后续补验。
  理由：用户明确要求先跳过，且当前 `behavior`、`guard`、`arch` 已能证明本轮重构没有破坏可见行为和静态边界。
  日期/作者：2026-03-19 / Codex

## 结果与复盘

本轮已经完成 T0-T6。结果如下：

- T1：把 dirty bucket 的构造、merge、reset 真正收口到 `dirty_tracker`，并保持 `consume()` 与 landing hold release/reset 的旧语义。
- T2：把 owner / target picker 的纯字段解析收口到 `choice_contract`，保留外层 current-player fallback，不污染 core。
- T3：把 explicit route / requires_confirm 读取收口到 `route_policy`，UI 边界 alias 继续保留，target route 检查不再分叉。
- T4：简化 `action_anim_port` 的布尔 guard，不改断言与返回值契约。
- T5：收敛 `intent_dispatcher` 的 choice entry 组装和 intent event 发射路径；期间发现并修复一次 direct UI notify 回归。
- T6：把证据、决策和遗留项完整写回计划。

最终状态：
- `behavior` 通过；
- `guard` 通过；
- `arch` 通过；
- `contract` 按用户要求跳过，未作为本轮阻塞项。

本轮保留的刻意边界：
- `choice_contract` 仍然不接触 `game` / runtime；
- `choice_route_policy.lua` 仍然保留为 UI alias；
- `intent` 事件统一入口存在，但仍与可 patch 的 `emit` 观察边界解耦，以兼容既有测试语义。

## 背景与导读

这次收敛涉及四层：

- `src/core/`：共享纯工具与契约，如 `dirty_tracker`、`choice_contract`、`route_policy`、`monopoly_events`、`action_anim_port`
- `src/state/`：运行态状态访问层，本次重点是 `landing_visual_hold`
- `src/turn/`：玩法输出与校验，本次重点是 `intent_dispatcher` 和 `validator`
- `src/presentation/` / `src/ui/`：展示路由与 target picker，本次重点是 `choice_state`、`choice_route_policy`、`target_choice_effects`

关键边界约束：

- `choice_contract` 只能做纯字段解析，不读取 `game` / UI / runtime。
- `route_policy` 负责 route 与 confirm 元数据的统一读取；`src/ui/input/choice_route_policy.lua` 保持为 UI 边界别名，不删除。
- `dirty_tracker.consume()` 的快照与 reset 语义不可被“安全化”重写；尤其不能把 `inventory_ids` 改成深拷贝语义。
- `intent_dispatcher.open_choice()` 的副作用顺序必须保持：`choice_seq` 递增 -> `pending_choice` 赋值 -> dirty 标记 -> 日志 -> 事件派发。

## 任务图

### T0: 锁定验证上下文与计划格式
- **depends_on**: `[]`
- **location**: `./.agents/plan.md`, `tests/behavior.lua`, `tests/contract.lua`, `tests/guard.lua`, `tools/quality/arch.lua`
- **description**: 把计划改成可并行执行格式；把验证命令改成 lane 入口；记录 `guard` / `arch` 在当前 shell 下必须经 `cmd /c` 执行；记录当前基线证据。
- **validation**:
  - `lua tests/behavior.lua`
  - `cmd /c lua tests/guard.lua`
  - `cmd /c lua tools/quality/arch.lua check`
- **status**: Completed
- **log**:
  - 已重写计划为可并行执行格式。
  - 已确认 raw suite 文件不是合法验证入口。
  - 已确认 `guard` / `arch` 的当前可运行上下文。
- **files edited/created**:
  - `.agents/plan.md`

### T1: 统一 dirty bucket 构造、merge 与 reset
- **depends_on**: `[T0]`
- **location**: `src/core/utils/dirty_tracker.lua`, `src/state/state_access/landing_visual_hold.lua`
- **description**: 把 `landing_visual_hold` 里重复的 dirty bucket shape、merge helper、reset helper 收敛到 `dirty_tracker`；覆盖 `_new_dirty_bucket`、merge 辅助函数、`release` / `reset_state` 等 reset 点；保持 deferred dirty、release replay、consume snapshot 行为不变。
- **validation**:
  - `lua tests/behavior.lua`
  - 定向关注 `runtime.misc` 里的 `landing_visual_hold_*` 与 `number_utils_*` case 输出
- **status**: Completed
- **log**:
  - 新增 `dirty_tracker.ensure_inventory_ids()`、`dirty_tracker.merge_into()`、`dirty_tracker.reset()`。
  - `landing_visual_hold` 不再自带重复 dirty bucket shape / merge / reset 实现。
  - 保留 `consume()` 的 snapshot / reset 语义和 deferred replay 行为。
- **files edited/created**:
  - `src/core/utils/dirty_tracker.lua`
  - `src/state/state_access/landing_visual_hold.lua`

### T2: 统一纯 choice owner / target picker 解析
- **depends_on**: `[T0]`
- **location**: `src/core/choice/contract.lua`, `src/presentation/runtime/ports/ui_sync/choice_state.lua`, `src/ui/ctl/target_choice_effects.lua`, `src/turn/actions/validator.lua`
- **description**: 在 `choice_contract` 中集中处理 `owner_role_id` 与 `target_picker_owner_role_id` 的纯字段解析；展示层与 turn 层继续自己做 current-player fallback；删除重复的数值解析逻辑，同时保留 target pick 在 `actor_role_id` 缺失时的宽松语义。
- **validation**:
  - `lua tests/behavior.lua`
  - 定向关注 `presentation_ui_model_dispatch`、`presentation_ui_interaction`、`presentation_target_pick`
- **status**: Completed
- **log**:
  - 在 `choice_contract` 中新增 `resolve_meta_player_role_id()` 与 `resolve_owner_or_meta_role_id()`。
  - `choice_state` 与 `validator` 改为复用共享纯解析 helper。
  - 保留 current-player fallback 在外层调用方，不把 runtime 上下文引入 core。
- **files edited/created**:
  - `src/core/choice/contract.lua`
  - `src/presentation/runtime/ports/ui_sync/choice_state.lua`
  - `src/turn/actions/validator.lua`

### T3: 统一 route / requires_confirm 读取
- **depends_on**: `[T0]`
- **location**: `src/core/choice/route_policy.lua`, `src/ui/input/choice_route_policy.lua`, `src/ui/ctl/target_choice_effects.lua`
- **description**: 让 `route_policy` 成为 route 与 confirm 元数据的唯一读取入口；`choice_route_policy` 保持 UI 别名；检查 `target_choice_effects` 的 target route 识别，避免仍然硬编码 `choice.route_key == "target"`。
- **validation**:
  - `lua tests/behavior.lua`
  - 定向关注 `presentation_choice_routes`、`presentation_ui_model_dispatch`、`presentation_ui_interaction`
- **status**: Completed
- **log**:
  - `route_policy` 新增 explicit route / explicit requires_confirm 读取 helper。
  - `choice_route_policy` 继续只做 UI alias 转发。
  - `target_choice_effects` 的 target route 检查改为复用共享 route helper。
- **files edited/created**:
  - `src/core/choice/route_policy.lua`
  - `src/ui/input/choice_route_policy.lua`
  - `src/ui/ctl/target_choice_effects.lua`

### T4: 微清理 action_anim_port
- **depends_on**: `[T0]`
- **location**: `src/core/ports/action_anim_port.lua`
- **description**: 只清理 `is_enabled()` / `queue()` 中的布尔和 guard 冗余；不改变 assert 行为、nil 处理、返回值契约、实际 queue 时机。
- **validation**:
  - `lua tests/contract.lua`
  - `lua tests/behavior.lua`
  - 定向关注 `narrow_runtime_ports_contract` 与 action animation 相关 presentation case
- **status**: Completed
- **log**:
  - 简化 `is_enabled()` 和 `queue()` 的布尔判断。
  - 保持 `missing anim_gate_port` 断言、disabled/no-queue 的 `false` 返回值、成功 queue 的 `true` 返回值。
- **files edited/created**:
  - `src/core/ports/action_anim_port.lua`

### T5: 收敛 intent dispatch 的共享 route / event 路径
- **depends_on**: `[T2, T3]`
- **location**: `src/core/events/monopoly_events.lua`, `src/turn/output/intent_dispatcher.lua`
- **description**: 把 gameplay intent dispatch 改成共享 route helper + 单一 intent event emission 路径；保留 `required_meta` 校验 / normalize 行为、market/item/landing 的 owner backfill、副作用顺序、日志文本、payload key。
- **validation**:
  - `lua tests/behavior.lua`
  - 定向关注 `gameplay_intent_dispatch_and_event_feed`
- **status**: Completed
- **log**:
  - 抽出 `_build_choice_entry()` 与 `_mark_turn_dirty()`，减少 `open_choice()` 的重复样板。
  - 在 `monopoly_events` 中新增 `emit_intent()`。
  - 首版实现引入了 direct UI notify 回归，随后改成内部 `_emit_event()` 以恢复旧观察边界。
- **files edited/created**:
  - `src/core/events/monopoly_events.lua`
  - `src/turn/output/intent_dispatcher.lua`

### T6: 串行补齐证据与复盘
- **depends_on**: `[T1, T2, T3, T4, T5]`
- **location**: `./.agents/plan.md`
- **description**: 在所有代码任务落地后，只追加更新“进度 / 意外与发现 / 决策日志 / 结果与复盘”，并记录最终验证输出。T6 不重排计划结构。
- **validation**:
  - `lua tests/behavior.lua`
  - `lua tests/contract.lua`
  - `cmd /c lua tests/guard.lua`
  - `cmd /c lua tools/quality/arch.lua check`
- **status**: Completed
- **log**:
  - 已补写进度、发现、决策、结果章节。
  - 已记录 `behavior` / `guard` / `arch` 结果。
  - 已记录 `contract` 因用户要求而跳过。
- **files edited/created**:
  - `.agents/plan.md`

## 并行波次

| Wave | Tasks | Can Start When |
|------|-------|----------------|
| 1 | T0 | 立即 |
| 2 | T1, T2, T3, T4 | T0 完成 |
| 3 | T5 | T2, T3 完成 |
| 4 | T6 | T1, T2, T3, T4, T5 完成 |

## 工作顺序

先由主执行者完成 T0，然后把 Wave 2 的四个任务按不重叠写集分配给并行 worker。`T2` 与 `T3` 都会碰 `src/ui/ctl/target_choice_effects.lua`，因此二者不能同时写这个文件：推荐把 `target_choice_effects.lua` 归 T3 所有，T2 只改 `choice_contract`、`choice_state`、`validator`。如果 T2 需要 target owner helper 结果，则由 T3 在完成 route 审计时一并落地，或者主执行者在合并时补最后一刀。

`T5` 必须等 T2 / T3 都稳定后再做，因为它依赖 choice owner 与 route helper 的最终接口。`T6` 只在所有代码任务完成并验证后执行。

## 验证与验收

阶段性要求：

1. 每个任务先跑自己的定向验证，再跑至少一个 lane；
2. 如果某任务会影响 gameplay + presentation 两侧，优先看 `behavior`；
3. `action_anim_port` 这类窄契约变化必须补 `contract`；
4. 默认最终验收必须同时满足：

    lua tests/behavior.lua
    lua tests/contract.lua
    cmd /c lua tests/guard.lua
    cmd /c lua tools/quality/arch.lua check

通过标准：

- 行为回归继续通过；
- 合同与静态边界继续通过；
- choice route、confirm、owner、target picker 语义不变；
- `landing_visual_hold` release / deferred dirty 行为不变；
- `intent_dispatcher` 事件名、payload、日志文本、副作用顺序不变；
- `action_anim_port` 的 assert / return contract 不变。

本轮实际验收（按用户指令调整）：

    lua tests/behavior.lua
    cmd /c lua tests/guard.lua
    cmd /c lua tools/quality/arch.lua check

## 可重复性与恢复

每个任务都应保持小步、可回滚、可单独验证。失败时优先回退到该任务开始前的提交，再拆成更小修改重试。不要使用破坏性 git 命令；只撤回当前任务自己的提交或补新提交修正。

并行执行时，worker 只能提交自己负责的写集，不能顺手整理别人的文件。若任务边界判断错误导致写集冲突，应暂停后重新分配，而不是互相覆盖。

## 产物与备注

当前基线证据：

    lua tests/behavior.lua
    -> All regression checks passed (999)

    cmd /c lua tests/guard.lua
    -> dep_rules ok
    -> gameplay_loop_no_ui ok
    -> forbidden_globals ok
    -> arch_view_guard ok

    cmd /c lua tools/quality/arch.lua check
    -> arch_view 检查通过 / arch_view check ok

本轮最终证据：

    lua tests/behavior.lua
    -> All regression checks passed (999)

    cmd /c lua tests/guard.lua
    -> dep_rules ok
    -> gameplay_loop_no_ui ok
    -> forbidden_globals ok
    -> arch_view_guard ok

    cmd /c lua tools/quality/arch.lua check
    -> arch_view 检查通过 / arch_view check ok

    lua tests/contract.lua
    -> skipped by user instruction

## 接口与依赖

这轮收敛只允许复用和加强既有入口，不新增平行抽象：

- Dirty 真源：`src/core/utils/dirty_tracker.lua`
- Choice owner 纯解析真源：`src/core/choice/contract.lua`
- Route 真源：`src/core/choice/route_policy.lua`
- UI route 边界别名：`src/ui/input/choice_route_policy.lua`
- Gameplay intent 事件真源：`src/core/events/monopoly_events.lua`
- Action animation 窄端口：`src/core/ports/action_anim_port.lua`

若实现过程中确实需要新增 helper，必须满足两点：

1. 它减少了明确重复；
2. 它不把外层运行时 / UI / gameplay 上下文倒灌进 `src/core/` 纯模块。

---

改动说明（2026-03-19）：先将原始 swarm 计划重写为可并行执行版本；随后按该计划完成 T1-T5 的代码收敛，并在本文件补齐任务完成状态、真实回归、修复记录、最终验收结果，以及“按用户要求跳过 contract”的说明。
