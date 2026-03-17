# Plan: Arch View Cycle Dependency Fix

本计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `/Users/billyq/Dev/Github/Lua/monopoly/.agents/harness/PLANS.md` 维护，并补充 `swarm-planner` 需要的显式任务依赖，便于后续分工执行。

**Generated**: 2026-03-18

## 目的 / 全局视角

目标不是继续依赖 `scripts/quality/arch/filter.lua` 把问题隐藏掉，而是把 `arch_view` 原始扫描里已经存在的两个 projection cycle 真正拆掉，并把依赖方向恢复到 Clean Architecture 允许的方向。

2026-03-18 本地执行结果表明：`lua scripts/quality/arch.lua check` 会通过，但 `lua scripts/quality/arch.lua scan --out tmp/arch_cycle_scan.json` 产出的原始 JSON 中，`check.cycles = []`、`check.projection_cycles = 2`、`check.ok = false`。也就是说，现在没有模块级 `require` 真环，但仍有两个被过滤器掩盖的命名空间投影环，分别落在 `ui` 与 `ui.ctl` 视图。

用户可见的完成标准是：原始 `scan` 结果不再包含这两个 projection cycle；`filter.lua` 不再对 `ui` / `ui.ctl` 开特例；`arch_view` 契约测试从“验证过滤器忽略它们”改成“验证原始扫描已无此环”；并且新引入的 canonical path 不会削弱现有架构护栏。

## 进度

- [x] (2026-03-18 01:15 CST) 已读取架构与质量文档：`/Users/billyq/Dev/Github/Lua/monopoly/docs/architecture/arch_view.md`、`/Users/billyq/Dev/Github/Lua/monopoly/docs/architecture/boundaries.md`、`/Users/billyq/Dev/Github/Lua/monopoly/docs/architecture/layer-model.md`、`/Users/billyq/Dev/Github/Lua/monopoly/docs/architecture/quality_map.md`
- [x] (2026-03-18 01:15 CST) 已读取计划规范与 Clean Architecture 审视技能：`/Users/billyq/Dev/Github/Lua/monopoly/.agents/harness/PLANS.md`、`/Users/billyq/Dev/Github/Lua/monopoly/.agents/skills/clean-architecture-reviewer/SKILL.md`
- [x] (2026-03-18 01:16 CST) 已执行 `arch_view check/scan`，确认 0 个模块级 cycle、2 个 projection cycle
- [x] (2026-03-18 01:19 CST) 已定位主要错误依赖方向：`src.ui.pres` / `src.ui.stores` 反向依赖 `src.ui.ctl.ports.runtime_state_seam`；`src.ui.ctl.ports.*` 作为端口装配层反向依赖 `src.ui.ctl.*`
- [x] (2026-03-18 01:24 CST) 已创建计划文件 `/Users/billyq/Dev/Github/Lua/monopoly/arch-view-cycle-dependency-fix-plan.md`
- [x] (2026-03-18 01:33 CST) 已完成一次子代理计划审阅，并补入 `arch/config.json`、`dep_rules`、shim 顺序、直接测试消费者与文档同步等漏项
- [ ] 实施 T2-T7（已完成：T1 基线冻结与 canonical path 定案）

## 意外与发现

- 观察：`lua scripts/quality/arch.lua check` 输出通过，但原始 `scan` 的 `check.ok` 为 `false`
  证据：同一次采样中 `check.cycles = []`、`check.projection_cycles = 2`

- 观察：这不是模块级 `require` 环，而是 view projection 级别的错误依赖方向
  证据：`src.ui.pres.choice_slice -> src.ui.ctl.ports.runtime_state_seam`、`src.ui.stores.modal_state -> src.ui.ctl.ports.runtime_state_seam` 让 `ui` 视图出现 `pres/stores -> ctl`；`src.ui.ctl.ports.* -> src.ui.ctl.*` 让 `ui.ctl` 视图出现 `ports -> actor_context/modal_controller/ui_runtime/...`

- 观察：仓库已经把这两个环当成“可过滤的已知问题”写进了工具测试与文档
  证据：`/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/architecture/arch_view_contract.lua` 里有 `filtered_check_ignores_presentation_namespace_projection_cycles`；`/Users/billyq/Dev/Github/Lua/monopoly/docs/architecture/arch_view.md` 明写会过滤 `ui` / `ui.ctl` 投影环

- 观察：如果新增 `src/presentation/runtime/ports/*`，当前 `scripts/quality/arch/config.json` 不会自动把它们归类为 `presentation`
  证据：现有 `component_rules` 只显式匹配 4 个 `src.presentation.runtime.*` 文件；并没有 `^src%.presentation%.runtime%..+` 或 `ports` 的泛化规则

- 观察：`tests/guards/dep_rules.lua` 对 seam 的白名单绑定在旧路径上
  证据：当前 whitelist 仅包含 `src/ui/ctl/ports/runtime_state_seam.lua`、`src/ui/ctl/ports/landing_visual_hold_seam.lua`、`src/ui/ctl/ports/host_runtime_ports.lua`

- 观察：这项工作不依赖外部第三方 API 文档
  证据：问题完全落在仓库内部命名空间、Lua `require` 关系与本地 `arch_view` / `dep_rules` 配置；本轮无需额外 web/Context7 文档

## 决策日志

- 决策：把问题定义为“错误的依赖方向”而不是“arch_view 误报”
  理由：原始扫描明确给出具体反馈边，且这些边都能在真实源码 `require` 中找到；过滤器只是隐藏问题
  日期/作者：2026-03-18 / Codex

- 决策：共享 seam 的 canonical path 迁到中性 UI runtime 命名空间，推荐 `src/ui/runtime/*`
  理由：`runtime_state`、`landing_visual_hold`、`host_runtime` 是共享适配层，不应挂在 `src/ui/ctl` 下面让 `pres/stores/render/input` 反向穿过 controller 命名空间
  日期/作者：2026-03-18 / Codex

- 决策：gameplay loop port builder 的 canonical path 迁到外层装配命名空间，推荐 `src/presentation/runtime/ports/*`
  理由：这些模块本质是给 `turn.loop` 暴露的 adapter / assembly，应由外层 presentation runtime 拥有，而不是作为 `ui.ctl` 子命名空间反向拥有 controller 实现
  日期/作者：2026-03-18 / Codex

- 决策：迁移期间允许保留 compatibility shim，但 shim 必须是纯 alias：`return require("new.path")`
  理由：多个测试会 patch 模块 table 本身；纯 alias 才能保证新旧路径指向同一个 table 对象，不在迁移期引入新行为差异
  日期/作者：2026-03-18 / Codex

- 决策：先建 canonical module 与 guardrail，再迁消费者，最后删除 filter 特例
  理由：如果顺序相反，很容易在中途让 `arch_view`、`dep_rules` 或 patch-based 测试全部变红
  日期/作者：2026-03-18 / Codex

## 结果与复盘

当前只完成了调研与计划，未开始改码。

如果后续 T1-T7 全部完成，结果应当是：原始架构 JSON 的 `check.projection_cycles` 为空；`filter.lua` 不再豁免 `ui` / `ui.ctl`；`docs/architecture/arch_view.md`、`docs/architecture/boundaries.md`、`docs/architecture/layer-model.md` 与 `docs/architecture/subsystems.md` 的放置语义与实际代码一致；并且新路径已经被 `arch_view` 与 `dep_rules` 同步纳入护栏，而不是偷偷绕开旧约束。

## 背景与导读

这次问题集中在 presentation 组件内部两个层次的命名空间。

第一层是 `ui` 视图。这里预期的方向是 `ctl -> input/render`，以及 `pres/stores/render/input -> shared runtime seam`。但当前 `src/ui/pres/choice_slice.lua`、`src/ui/stores/modal_state.lua` 直接 `require("src.ui.ctl.ports.runtime_state_seam")`，把 controller 命名空间当成共享依赖入口，形成了 `pres/stores -> ctl` 的回边。

第二层是 `ui.ctl` 视图。这里 `actor_context`、`modal_controller`、`ui_runtime`、`event_handlers` 等属于 controller 实现；而 `modal_ports`、`ui_sync_ports`、`view_command_ports`、`anim_ports`、`debug_ports`、`state_ports`、`actor_context_ports`、`clock_ports` 本质上是外层 adapter / assembly。当前这些 port builder 物理位于 `src/ui/ctl/ports/*`，同时反向依赖 `src/ui/ctl/*` 实现，因此投影后出现 `ports -> implementation` 与 `implementation -> ports` 的往返。

另外还有两个容易漏掉的相邻模块：`src/ui/ctl/ports/runtime_event_ports.lua` 与 `src/ui/ctl/ports/state_callback_ports.lua`。它们虽然不在这次 `ui.ctl` 反馈边列表里，但语义上也属于 presentation runtime adapter；如果这次不顺手定好归属，后续很容易再次把 `ports` 命名空间做成杂糅区。

与本任务直接相关的关键文件如下：

- 原始扫描与过滤：
  - `/Users/billyq/Dev/Github/Lua/monopoly/scripts/quality/arch/filter.lua`
  - `/Users/billyq/Dev/Github/Lua/monopoly/scripts/quality/arch/config.json`
  - `/Users/billyq/Dev/Github/Lua/monopoly/tmp/arch_cycle_scan.json`
- 共享 seam 与错误回边：
  - `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/runtime_state_seam.lua`
  - `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/landing_visual_hold_seam.lua`
  - `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/host_runtime_ports.lua`
  - `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/pres/choice_slice.lua`
  - `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/stores/modal_state.lua`
  - `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/render/*.lua`
  - `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/input/*.lua`
  - `/Users/billyq/Dev/Github/Lua/monopoly/src/presentation/runtime/state_factory.lua`
  - `/Users/billyq/Dev/Github/Lua/monopoly/src/presentation/runtime/runtime_event_bridge.lua`
- gameplay loop 端口装配：
  - `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/init.lua`
  - `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/common.lua`
  - `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/modal_ports.lua`
  - `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/ui_sync_ports.lua`
  - `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/ui_sync/*.lua`
  - `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/view_command_ports.lua`
  - `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/anim_ports.lua`
  - `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/debug_ports.lua`
  - `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/state_ports.lua`
  - `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/actor_context_ports.lua`
  - `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/clock_ports.lua`
  - `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/runtime_event_ports.lua`
  - `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/state_callback_ports.lua`
  - `/Users/billyq/Dev/Github/Lua/monopoly/src/presentation/runtime/gameplay_runtime_bootstrap.lua`
- 契约、护栏与文档：
  - `/Users/billyq/Dev/Github/Lua/monopoly/tests/guards/dep_rules.lua`
  - `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/architecture/arch_view_contract.lua`
  - `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/runtime/runtime_ports_contract.lua`
  - `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/runtime/runtime_bootstrap.lua`
  - `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/gameplay/gameplay_cases.lua`
  - `/Users/billyq/Dev/Github/Lua/monopoly/tests/support/shared_support.lua`
  - `/Users/billyq/Dev/Github/Lua/monopoly/docs/architecture/arch_view.md`
  - `/Users/billyq/Dev/Github/Lua/monopoly/docs/architecture/boundaries.md`
  - `/Users/billyq/Dev/Github/Lua/monopoly/docs/architecture/layer-model.md`
  - `/Users/billyq/Dev/Github/Lua/monopoly/docs/architecture/subsystems.md`

## 概览

推荐的修复路线分三段。

第一段，先冻结 canonical path，并同步补上 `arch_view config` 与 `dep_rules` 对新路径的识别能力，不让后续重构在分类与白名单层面先天失血。

第二段，先抽离共享 seam，再迁 gameplay loop port builder。这里必须顺序执行，因为 `ui_sync/common/anim/runtime_event` 等 port 子模块本身也直接依赖旧 seam；如果 seam canonical path 没先稳定，后续 port builder 迁移会同时踩路径与命名空间两种变更。

第三段，再统一修 bootstrap、fixture、直接测试消费者、文档与 `arch_view` filter，最后跑整套验证并清理 shim。

## Dependency Graph

    T1 ── T2 ── T3 ── T4 ── T5 ── T6 ── T7

## Tasks

### T1: 冻结现状证据并拍板 canonical 命名空间
- **depends_on**: []
- **location**: `/Users/billyq/Dev/Github/Lua/monopoly/tmp/arch_cycle_scan.json`, `/Users/billyq/Dev/Github/Lua/monopoly/scripts/quality/arch/config.json`, `/Users/billyq/Dev/Github/Lua/monopoly/docs/architecture/arch_view.md`
- **description**: 记录两个 projection cycle 的完整反馈边，并正式拍板两类新路径：共享 seam 迁到 `src/ui/runtime/*`；presentation runtime adapter / gameplay loop port builder 迁到 `src/presentation/runtime/ports/*`。同时明确旧路径在迁移期间仅允许作为 compatibility shim 存在。
- **validation**: 文档或任务日志中必须明确列出 `ui` 与 `ui.ctl` 的反馈边、目标 canonical path、以及 shim 约束；后续任务不得再改动根命名策略。
- **status**: Completed
- **log**: 2026-03-18 01:50 CST 重新执行 raw `arch_view scan`，确认 `check.ok = false`、`check.cycles = 0`、`check.projection_cycles = 2`，视图稳定为 `ui` 与 `ui.ctl`。本任务正式冻结 canonical path：共享 seam 真源用 `src/ui/runtime/*`，presentation runtime 装配真源用 `src/presentation/runtime/ports/*`，旧 `src.ui.ctl.ports.*` 仅允许作为纯 alias shim。
- **files edited/created**: `.agents/plan.md`, `tmp/arch_cycle_scan.json`

### T2: 先补齐 guardrail，让新 canonical path 被正确识别
- **depends_on**: [T1]
- **location**: `/Users/billyq/Dev/Github/Lua/monopoly/scripts/quality/arch/config.json`, `/Users/billyq/Dev/Github/Lua/monopoly/tests/guards/dep_rules.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/runtime/runtime_ports_contract.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/init.lua`
- **description**: 在真正迁移代码前，先让 `arch_view` 与 `dep_rules` 认识新路径。具体包括：为 `src/presentation/runtime/ports/*` 与 `src/ui/runtime/*` 增加 component rule；扩展 forbidden-dependency rule，使 `src.presentation.*` 不会因为新路径而逃逸出 presentation 约束；把 seam whitelist 与 `describe_boundary_contract()` 设计成能同时容纳 canonical path 与临时 shim 的状态。
- **validation**: 修改后，新增的 canonical module path 不会被 `arch_view` 判成 unclassified；`dep_rules` 对新 canonical seam 的白名单已到位；`runtime_ports_contract` 不再只硬编码旧 seam 路径。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T3: 抽离共享 seam，并重写所有 seam 消费者到 canonical path
- **depends_on**: [T2]
- **location**: `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/runtime/*`, `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/runtime_state_seam.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/landing_visual_hold_seam.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/host_runtime_ports.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/pres/*.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/stores/*.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/render/**/*.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/input/**/*.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/**/*.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/presentation/runtime/state_factory.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/presentation/runtime/runtime_event_bridge.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/tests/support/shared_support.lua`
- **description**: 创建 `src/ui/runtime/*` canonical seam，并把所有真实消费者全部切过去，包括 `src/ui/ctl/ports/common.lua`、`src/ui/ctl/ports/anim_ports.lua`、`src/ui/ctl/ports/ui_sync_ports.lua`、`src/ui/ctl/ports/ui_sync/*.lua`、`src/ui/ctl/ports/runtime_event_ports.lua` 等容易漏掉的 port 子模块。旧 `src/ui/ctl/ports/*_seam.lua` / `host_runtime_ports.lua` 若暂时保留，只能是纯 alias。
- **validation**: 运行 `rg 'src\.ui\.ctl\.ports\.(runtime_state_seam|landing_visual_hold_seam|host_runtime_ports)' src tests`，只允许命中 compatibility shim 或明确保留点；重新做 raw `scan` 时，`ui` 视图不再出现 `pres -> ctl` / `stores -> ctl` 反馈边。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T4: 迁移 presentation runtime adapter / gameplay loop port builder 到外层装配层
- **depends_on**: [T3]
- **location**: `/Users/billyq/Dev/Github/Lua/monopoly/src/presentation/runtime/ports/*`, `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/init.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/common.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/modal_ports.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/ui_sync_ports.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/ui_sync/*.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/view_command_ports.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/anim_ports.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/debug_ports.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/state_ports.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/actor_context_ports.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/clock_ports.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/runtime_event_ports.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/ui/ctl/ports/state_callback_ports.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/presentation/runtime/gameplay_runtime_bootstrap.lua`
- **description**: 在 `src/presentation/runtime/ports/*` 建立新的装配真源，把 `modal/anim/ui_sync/debug/clock/state/view_command/actor_context` 以及 `runtime_event/state_callback` 这些 adapter 归位到外层命名空间。顺序必须是：先创建新 canonical module，再让旧 `src.ui.ctl.ports.*` 变成纯 alias，最后再逐步切换 bootstrap 与测试消费者，避免中途 patch-based 测试失效。
- **validation**: raw `scan` 中 `ui.ctl` 视图不再出现 `ports -> actor_context/modal_controller/target_choice_effects/ui_runtime/...` 反馈边；旧 `src.ui.ctl.ports.*` 若还存在，必须全部是 `return require("new.path")` 形式，不得再包含装配逻辑。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T5: 统一 bootstrap、fixture、直接测试消费者与边界契约
- **depends_on**: [T4]
- **location**: `/Users/billyq/Dev/Github/Lua/monopoly/src/presentation/runtime/gameplay_runtime_bootstrap.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/tests/support/shared_support.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/runtime/runtime_ports_contract.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/runtime/runtime_bootstrap.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/gameplay/gameplay_cases.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/presentation/*.lua`
- **description**: 批量切换生产 bootstrap、shared fixture 与直接依赖旧路径的测试。这里必须覆盖 patch-based 测试和直接 `require("src.ui.ctl.ports.*")` 的 suite，而不只是笼统地改共享 support。若保留 shim，则在此阶段确认所有测试都能通过 shim 访问到同一个 canonical table 对象。
- **validation**: `rg 'src\.ui\.ctl\.ports' tests src/presentation/runtime` 仅剩 compatibility shim、明确保留的兼容断言或待删除注释；`lua tests/contract.lua` 通过；`runtime_bootstrap`、`runtime_ports_contract`、`gameplay_cases` 与高风险 presentation suites 可在本地单独或整组通过。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T6: 去掉 `arch_view` 特例，补齐文档并刷新 viewer 快照
- **depends_on**: [T5]
- **location**: `/Users/billyq/Dev/Github/Lua/monopoly/scripts/quality/arch/filter.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/architecture/arch_view_contract.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/docs/architecture/arch_view.md`, `/Users/billyq/Dev/Github/Lua/monopoly/docs/architecture/boundaries.md`, `/Users/billyq/Dev/Github/Lua/monopoly/docs/architecture/layer-model.md`, `/Users/billyq/Dev/Github/Lua/monopoly/docs/architecture/subsystems.md`, `/Users/billyq/Dev/Github/Lua/monopoly/scripts/quality/arch/viewer/`
- **description**: 删除 `filter.lua` 中针对 `ui` / `ui.ctl` 的特例过滤；把 `arch_view_contract` 从“过滤后忽略这两个环”改成“原始 scan 已无此环”；并同步更新架构文档，解释新的 `src/ui/runtime/*` 与 `src/presentation/runtime/ports/*` 归属。最后刷新提交态 viewer 快照。
- **validation**: `lua scripts/quality/arch.lua check` 在不依赖这两个特例的情况下直接通过；`arch_view_contract` 断言原始 scan 无 `ui` / `ui.ctl` projection cycle；viewer 快照与实际 JSON 一致。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T7: 最终验收、清理 shim 与旧白名单
- **depends_on**: [T6]
- **location**: `/Users/billyq/Dev/Github/Lua/monopoly/src/`, `/Users/billyq/Dev/Github/Lua/monopoly/tests/`, `/Users/billyq/Dev/Github/Lua/monopoly/scripts/quality/arch/`
- **description**: 做最后一次全仓审计：删除不再需要的 shim、删除旧 whitelist 条目、检查是否还残留旧 canonical import、以及 `describe_boundary_contract()` 是否只发布新真源。若某些 shim 因测试兼容必须保留，也要在契约和注释里明确它只是兼容层，不是架构真源。
- **validation**: 在仓库根目录依次运行：
  - `lua scripts/quality/arch.lua scan --out tmp/arch_cycle_scan.json`
  - `lua scripts/quality/arch.lua check`
  - `lua tests/guard.lua`
  - `lua tests/contract.lua`
  - `lua tests/behavior.lua`
  另外运行：
  - `rg 'src\.ui\.ctl\.ports|src\.ui\.ctl\.ports\.(runtime_state_seam|landing_visual_hold_seam|host_runtime_ports)' src tests`
  - `rg 'src\.state\.state_access\.(runtime_state|landing_visual_hold)|src\.host\.eggy' src/ui src/presentation/runtime`
  预期 raw `scan` 的 `check.projection_cycles` 为空，测试全通过，旧白名单与旧 canonical import 已清理或被明确标记为兼容层。
- **status**: Not Completed
- **log**:
- **files edited/created**:

## Parallel Execution Groups

| Wave | Tasks | Can Start When |
|------|-------|----------------|
| 1 | T1 | Immediately |
| 2 | T2 | T1 complete |
| 3 | T3 | T2 complete |
| 4 | T4 | T3 complete |
| 5 | T5 | T4 complete |
| 6 | T6 | T5 complete |
| 7 | T7 | T6 complete |

## 工作计划

先把命名真源和 guardrail 补齐，再迁代码。这一步看起来“慢”，但它能避免后面一边迁目录、一边让 `arch_view` 把新模块判成未分类，或者让 `dep_rules` 因旧白名单失效而整仓爆红。

然后优先处理共享 seam。`runtime_state`、`landing_visual_hold`、`host_runtime` 之所以必须先动，是因为它们不仅被 `pres/stores/render/input` 用，也被 `ui/ctl/ports/common.lua`、`ui_sync/*.lua`、`anim_ports.lua`、`runtime_event_ports.lua` 这些后续要迁的模块用。只有 seam canonical path 稳定后，adapter 层迁移才不会同时夹带第二次路径切换。

等共享 seam 全部切到 canonical path 后，再把 gameplay loop port builder 与 presentation runtime adapter 整体搬到 `src/presentation/runtime/ports/*`。迁移时不改行为，只改物理归属与依赖方向。旧路径如需暂存，必须是纯 alias。最后再统一更新 bootstrap、tests、contract、文档与 `filter.lua`。

## 具体步骤

所有命令都在 `/Users/billyq/Dev/Github/Lua/monopoly` 执行。

1. 记录当前原始扫描结果，确认修复目标：

       lua scripts/quality/arch.lua scan --out tmp/arch_cycle_scan.json

   预期能在 JSON 中看到：

       check.ok = false
       check.cycles = []
       check.projection_cycles = [ui, ui.ctl]

2. 完成 T2 后，先验证新 canonical path 已被 guardrail 接纳：

       lua scripts/quality/arch.lua scan --out tmp/arch_cycle_scan.json
       lua tests/guard.lua

   此时重点不是“已经无环”，而是“新路径不再被判未分类，也不会因旧 whitelist 缺失而误报”。

3. 完成 T3 后，再扫描一次，确认 `ui` 视图里的 `pres/stores -> ctl` 回边已经消失。

4. 完成 T4 后，再扫描一次，确认 `ui.ctl` 视图里的 `ports -> implementation` 回边已经消失。

5. 完成 T5-T6 后运行：

       lua scripts/quality/arch.lua check
       lua tests/contract.lua
       lua tests/guard.lua

   预期 `arch_view` 直接通过，且 `arch_view_contract` 不再依赖过滤器忽略 `ui` / `ui.ctl` 环。

6. 最终跑行为回归：

       lua tests/behavior.lua

## 验证与验收

必须同时满足以下六条，才算任务真正完成。

第一，原始 `scan` JSON 中 `check.projection_cycles` 为空，而不是“先有环、再被 filter 吃掉”。

第二，`/Users/billyq/Dev/Github/Lua/monopoly/scripts/quality/arch/config.json` 已把新 canonical path 归类到 `presentation`，且对应 forbidden-dependency 规则没有因为新目录而变松。

第三，`/Users/billyq/Dev/Github/Lua/monopoly/tests/guards/dep_rules.lua` 的 seam whitelist 与禁令已经切到新真源，旧路径白名单要么删除，要么被明确标注为过渡用途。

第四，`/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/architecture/arch_view_contract.lua` 不再验证“过滤器忽略这两个环”，而是验证“原始扫描已无此环”。

第五，`/Users/billyq/Dev/Github/Lua/monopoly/docs/architecture/arch_view.md`、`/Users/billyq/Dev/Github/Lua/monopoly/docs/architecture/boundaries.md`、`/Users/billyq/Dev/Github/Lua/monopoly/docs/architecture/layer-model.md`、`/Users/billyq/Dev/Github/Lua/monopoly/docs/architecture/subsystems.md` 对新目录归属的叙述与代码一致。

第六，`turn.loop`、presentation runtime bootstrap、shared fixture 与 patch-based 测试仍通过，说明这次改的是依赖方向，不是运行语义。

## 可重复性与恢复

`arch_view scan/check` 与测试命令都可重复执行，不会修改源代码；唯一会写回仓库的是 viewer 快照刷新步骤。刷新快照前必须先确认代码、测试与文档都已稳定，否则不要覆盖 `/Users/billyq/Dev/Github/Lua/monopoly/scripts/quality/arch/viewer/`。

如果迁移中途出现“新旧路径混用”导致测试大面积失败，优先保留旧路径 alias shim，确保主流程先恢复可跑，再在 T7 统一删 shim；不要在一个提交里同时删除旧路径、改 bootstrap、改 patch 测试和删 filter 特例。

## 风险与缓解

- **风险**：新 `src/presentation/runtime/ports/*` 或 `src/ui/runtime/*` 文件刚创建就被 `arch_view` 判成未分类，或绕开旧 presentation 边界。
  **缓解**：T2 先改 `scripts/quality/arch/config.json`，把 component rule 和 forbidden rule 一起补上。

- **风险**：共享 seam 与 port builder 同时迁移，导致 `ui_sync/common/anim/runtime_event` 这些中间模块反复改路径。
  **缓解**：严格按 T3 先稳定 seam，再做 T4；不要把两步并行执行。

- **风险**：compatibility shim 不是纯 alias，导致 patch-based 测试打到不同 table 对象上。
  **缓解**：所有 shim 都统一采用 `return require("new.path")`；禁止在 shim 内重新 `build()` 或复制函数表。

- **风险**：删除过滤器后仍有残留反馈边，导致 `arch_view` / `guard` 直接红灯。
  **缓解**：T6 前必须先看 raw `scan`，确认 `ui` 和 `ui.ctl` 的反馈边都已清空。

- **风险**：文档不更新，后续贡献者继续把模块放回旧命名空间。
  **缓解**：T6 明确要求同步 `arch_view.md`、`boundaries.md`、`layer-model.md`、`subsystems.md`。

- **风险**：新 `state_ports` canonical module 复制旧的无用 `require("src.host.eggy")`，平白触发 `dep_rules`。
  **缓解**：迁移时顺手删除无用宿主导入；只保留实际需要的 host seam 调用。

## 接口与依赖

最终应维持的接口语义如下：

- `runtime_state` seam 仍提供 `ensure_*`、`get_ui_model`、`set_ui_model`、`set_pending_choice`、`set_ui_dirty` 等现有窄接口，但 canonical module path 不再位于 `src.ui.ctl.ports.*`
- `landing_visual_hold` seam 与 `host_runtime` seam 仍负责 presentation 对 runtime / host 的窄桥接，但 canonical path 不再挂在 `src.ui.ctl` 下
- gameplay loop 端口组仍保持 `modal/anim/ui_sync/debug/clock/state/view_command/actor_context` 这一组契约与现有导出函数名，避免 `turn.loop` 被迫感知本次重构
- `runtime_event_ports` 与 `state_callback_ports` 的归属也要在本次完成后明确下来；即使继续保留旧 alias，也不能再作为真正的装配真源
- `presentation_ports.describe_boundary_contract()` 最终只能发布新的 canonical seam / assembly path；旧路径最多作为兼容层存在，不能继续被 contract 当作真源

## 产物与备注

本计划基于以下已验证的当前证据生成：

    lua scripts/quality/arch.lua check
    -> arch_view 检查通过 / arch_view check ok

    lua scripts/quality/arch.lua scan --out tmp/arch_cycle_scan.json
    -> check.cycles = []
    -> check.projection_cycles = 2
    -> views: ui, ui.ctl

后续每次修改本计划时，都要在文档底部追加一条变更说明，记录“改了什么、为什么改”。


变更说明（2026-03-18 01:50 CST）：完成 T1，重新冻结 raw arch_view 基线，并把 canonical path 决策落入计划执行日志。
