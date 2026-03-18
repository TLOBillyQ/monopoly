# Plan: src 兼容层命名收口

本计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `/Users/billyq/Dev/Github/Lua/monopoly/.agents/harness/PLANS.md` 维护，并补充 `swarm-planner` 需要的显式任务依赖，便于后续并行分工执行。

**Generated**: 2026-03-18

## 目的 / 全局视角

这次工作的目标不是改行为，而是清理 `src/` 里仍然带着兼容迁移痕迹的命名，让 Lua 文件名不再重复父目录已经表达过的信息，同时保留一条低风险的迁移路径。完成后，`src/ui/runtime/` 下不会再出现 `runtime_state_seam.lua`、`host_runtime_ports.lua` 这类重复目录语义的 canonical 文件；`src/ui/ctl/ports/` 里现有的 runtime adapter 会整体归位到 `src/presentation/runtime/ports/`，叶子文件名改成目录内短名，例如 `anim.lua`、`state.lua`、`ui_sync.lua`。

用户可见的完成标准有三类。第一，生产入口与测试入口都改为从新的 canonical 路径加载模块，但行为保持不变。第二，兼容层在迁移期只以纯 alias 存在，最终能整批删掉，而不是继续作为架构真源潜伏在 contract metadata 或测试白名单里。第三，文档、边界护栏和 checked-in `arch_view` viewer 快照都同步到新的命名规则，不再继续宣传旧的 `*_ports.lua` / `*_seam.lua` 真源。

## Prerequisites

- 工作目录固定为 `/Users/billyq/Dev/Github/Lua/monopoly`
- 本轮只涉及仓库内部 Lua 模块路径、测试、架构护栏与文档；不依赖外部第三方库的新 API，因此无需额外拉取外部文档
- 需要能运行以下本地命令：`lua scripts/quality/arch.lua check`、`lua tests/guard.lua`、`lua tests/contract.lua`、`lua tests/behavior.lua`

## 进度

- [x] (2026-03-18 10:12 CST) 已读取架构边界与层级文档：`docs/architecture/boundaries.md`、`docs/architecture/layer-model.md`、`docs/architecture/subsystems.md`
- [x] (2026-03-18 10:14 CST) 已读取计划规范与编码纪律：`.agents/harness/PLANS.md`、`.agents/harness/READING.md`、`.agents/harness/CODING.md`
- [x] (2026-03-18 10:18 CST) 已盘点当前兼容层热点：`src/ui/runtime/*.lua` 的三条 seam/host 路径，以及 `src/ui/ctl/ports/*.lua` 的 runtime adapter 组
- [x] (2026-03-18 10:20 CST) 已定位直接消费者与高风险测试：`src/presentation/runtime/gameplay_runtime_bootstrap.lua`、`src/presentation/runtime/state_factory.lua`、`src/presentation/runtime/runtime_event_bridge.lua`、`tests/suites/runtime/runtime_ports_contract.lua`、`tests/suites/runtime/runtime_bootstrap.lua`、若干直接 `require("src.ui.ctl.ports.*")` 的 presentation suites
- [x] (2026-03-18 10:23 CST) 已吸收审查意见，并确定新增约束：先切 package entry、原子迁移 `describe_boundary_contract()`、先改 guardrail 再重命名、补上 patch/reload 双 key 清理、最终移除 `legacy_alias_modules`
- [x] (2026-03-18 10:29 CST) 已完成计划重写，准备交给后续实现者执行
- [x] (2026-03-18 10:47 CST) 已完成 T1：冻结 canonical rename map、`host_bridge` 命名与 contract 不变量，并把 package entry cutover 设为后续所有迁移的前置条件
- [x] (2026-03-18 10:57 CST) 已完成 T2：为未来 `src.ui.runtime.state` / `landing_visual_hold` / `host_bridge` 路径补齐 whitelist，并把 contract 测试改成接受过渡态 canonical path
- [ ] 正在执行 T3 / T4：并行切 package entry 与 `ui/runtime` 三个真源

## 意外与发现

- 观察：根入口消费者不只依赖叶子模块，还直接依赖 `src.ui.ctl.ports` 包入口。
  证据：`src/presentation/runtime/gameplay_runtime_bootstrap.lua`、`tests/support/shared_support.lua`、`tests/suites/runtime/runtime_bootstrap.lua`、`tests/suites/runtime/runtime_ports_contract.lua` 都直接 `require("src.ui.ctl.ports")`。

- 观察：`describe_boundary_contract()` 已经是公开接口，不是内部实现细节。
  证据：`tests/suites/runtime/runtime_ports_contract.lua` 直接断言 `state_seam_modules`、`import_allowlists`、`state_field_allowlists` 的具体值。

- 观察：当前 patch/reload 型测试只清单个 `package.loaded` key，若直接引入 alias 双路径，容易读到旧缓存。
  证据：`tests/suites/presentation/gameplay_t5_characterization.lua` 的 `_load_fresh()` 只执行 `package.loaded[module_path] = nil`。

- 观察：架构文档还把 `*_ports.lua` 写成当前命名规则，会与新计划冲突。
  证据：`docs/architecture/boundaries.md` 的 “Port 命名规则” 明确写了 `*_ports.lua`。

- 观察：checked-in `arch_view` viewer 快照会直接携带这些模块路径，若只改源码不刷新快照，提交态文档会过期。
  证据：`scripts/quality/arch/viewer/architecture.json` 与 `architecture_data.js` 当前都包含 `src.ui.ctl.ports.*` 和 `src.ui.runtime.*_seam` 路径。

## 决策日志

- 决策：本轮范围采用“兼容层全收口”，同时处理 `src/ui/runtime/*` 和 `src/ui/ctl/ports/*`。
  理由：如果只改 seam 三个文件，`src/ui/ctl/ports/*` 仍会继续把“兼容迁移后遗症”留在 canonical 命名空间里，目标无法闭环。
  日期/作者：2026-03-18 / Codex

- 决策：迁移策略采用“两阶段 alias”，不是一次性硬切。
  理由：仓库里存在直接 patch module table 与 fresh-load 的测试；先建新真源、旧路径降成纯 alias，才能保证新旧路径指向同一个 table 对象。
  日期/作者：2026-03-18 / Codex

- 决策：`src.ui.runtime.host_runtime_ports` 的新 canonical 名称采用 `src.ui.runtime.host_bridge`，不使用 `host`。
  理由：`host.lua` 与现有 `src/host/` 命名空间过近，语义含混；`host_bridge` 既满足“去掉父目录重复信息”，又保留桥接语义。
  日期/作者：2026-03-18 / Codex

- 决策：`boundary_contract` 的 key 语义保持不变，只更新 module path。
  理由：这次要解决的是路径与文件名问题，不要顺手把 contract shape 也改掉，避免一次迁移承担两种风险。
  日期/作者：2026-03-18 / Codex

- 决策：必须先做 package entry cutover，再迁 leaf module consumer。
  理由：包入口 `src.ui.ctl.ports` 目前既是生产依赖入口，又承载 `describe_boundary_contract()`；若跳过这一步，后续叶子迁移会把 contract 真源和实现真源分叉。
  日期/作者：2026-03-18 / Codex

- 决策：最终阶段必须同时删除 alias 文件和 `legacy_alias_modules` 等兼容 metadata。
  理由：若只删文件不删 metadata，compat layer 会继续在 contract 中“存活”，计划目标并未真正完成。
  日期/作者：2026-03-18 / Codex

## 结果与复盘

当前只完成调研与计划重写，尚未改动任何生产代码、测试代码或文档。

这版计划已经吸收了审查意见里最容易漏掉的四类风险：包入口先后顺序、公共 contract 原子迁移、patch/reload 缓存污染、以及文档与 viewer 快照的同步。后续实现若严格按任务依赖推进，应该可以把这次改动控制在“纯路径重命名 + 兼容层退役”的范围内，而不是扩散成行为重构。

## 背景与导读

当前仓库里有两块与“父目录信息重复”直接相关的 canonical 模块。

第一块是 `src/ui/runtime/`。这里目前的三个真源分别是 `runtime_state_seam.lua`、`landing_visual_hold_seam.lua`、`host_runtime_ports.lua`。目录名已经表达了 “runtime 下的 UI seam / bridge”，文件名再次重复 `runtime`、`seam`、`ports`，属于本轮最直接的清理对象。直接消费者分布在 `src/ui/ctl/*`、`src/ui/render/*`、`src/ui/input/*`、`src/presentation/runtime/*` 和 `tests/support/shared_support.lua`。

第二块是 `src/ui/ctl/ports/`。这个目录下的 `anim_ports.lua`、`clock_ports.lua`、`debug_ports.lua`、`modal_ports.lua`、`runtime_event_ports.lua`、`state_callback_ports.lua`、`state_ports.lua`、`ui_sync_ports.lua`、`view_command_ports.lua`、`actor_context_ports.lua` 本质上是给 `turn.loop` 和 presentation runtime 提供的 adapter / assembly。目录名 `ports` 已经说明用途，叶子文件再以 `_ports` 结尾属于重复表达；更重要的是，它们的语义位置更接近 `src/presentation/runtime/`，而不是 controller 内部命名空间。

本轮计划把 `src.ui.ctl.ports` 的真正包入口迁到 `src.presentation.runtime.ports`，同时保留旧路径作为纯 alias 兼容层。新的 canonical 路径约定如下：

    src.ui.runtime.runtime_state_seam      -> src.ui.runtime.state
    src.ui.runtime.landing_visual_hold_seam -> src.ui.runtime.landing_visual_hold
    src.ui.runtime.host_runtime_ports     -> src.ui.runtime.host_bridge
    src.ui.ctl.ports                      -> src.presentation.runtime.ports
    src.ui.ctl.ports.actor_context_ports  -> src.presentation.runtime.ports.actor_context
    src.ui.ctl.ports.anim_ports           -> src.presentation.runtime.ports.anim
    src.ui.ctl.ports.clock_ports          -> src.presentation.runtime.ports.clock
    src.ui.ctl.ports.debug_ports          -> src.presentation.runtime.ports.debug
    src.ui.ctl.ports.modal_ports          -> src.presentation.runtime.ports.modal
    src.ui.ctl.ports.runtime_event_ports  -> src.presentation.runtime.ports.events
    src.ui.ctl.ports.state_callback_ports -> src.presentation.runtime.ports.callbacks
    src.ui.ctl.ports.state_ports          -> src.presentation.runtime.ports.state
    src.ui.ctl.ports.ui_sync_ports        -> src.presentation.runtime.ports.ui_sync
    src.ui.ctl.ports.view_command_ports   -> src.presentation.runtime.ports.view_command

这次计划不改业务行为，不改 port 方法名，不改 state 字段语义。实现者要做的只是稳定地迁移 canonical path、兼容层和相关护栏。

## 概览

推荐顺序分为五段。

第一段，先冻结路径映射与 contract 不变量，再补齐 guardrail。这里的重点不是“开始改名”，而是先让 `dep_rules`、`runtime_ports_contract` 和 package entry 都认识新路径，避免第一步重命名就把护栏打红。

第二段，先迁包入口和公共 contract。`src.ui.ctl.ports` 不能简单粗暴地被删掉，因为 `describe_boundary_contract()` 目前就挂在这个入口上。应先在 `src/presentation/runtime/ports/init.lua` 中建立新的真源，再把旧入口改成纯 alias。

第三段，再分两路并行迁移：一路处理 `src/ui/runtime/*` 三个 seam/bridge 真源；一路处理 `src/presentation/runtime/ports/*` 里的 leaf module。只有在新真源建立后，旧 `*_seam.lua` / `*_ports.lua` 才能安全退化为纯 alias。

第四段，统一切消费者和测试辅助函数，尤其是 patch/reload 型测试。这一步必须覆盖 `_load_fresh()`、直接 `require("src.ui.ctl.ports.*")` 的 suite，以及 patch 包入口 `presentation_ports.build` 的 runtime bootstrap 测试。

第五段，最后再删 alias、删 contract 中的 `legacy_alias_modules`、刷新文档和 `arch_view` viewer 快照，并用专项 `rg` 检查证明“文件名不再重复父目录信息”的目标确实达成。

## Dependency Graph

    T1 ── T2 ──┬── T3 ──┬── T5 ──┐
               │        │        ├── T7 ── T8
               │        └── T6 ──┘
               └── T4 ───────────┘

## Tasks

### T1: 冻结 canonical rename map 与 contract 不变量
- **id**: T1
- **depends_on**: []
- **location**: `.agents/plan.md`, `src/ui/runtime/`, `src/ui/ctl/ports/`, `src/presentation/runtime/`
- **description**: 把本计划里的 canonical 路径映射正式定稿，并明确三条不变量：一，旧路径在迁移期只能是纯 alias；二，`describe_boundary_contract()` 的 key 语义不改，只改路径；三，`host_bridge` 是 `host_runtime_ports` 的唯一新名，不再讨论其他候选名。
- **validation**: 后续任务与提交记录都使用同一套 rename map，不再临时追加或改名。
- **status**: Completed
- **log**: 2026-03-18 10:47 CST 已以本计划正文冻结 canonical rename map，并明确三条不变量：旧路径在迁移期只能是纯 alias；`describe_boundary_contract()` 保持 key 语义稳定；`host_bridge` 是 `host_runtime_ports` 的唯一新名。后续任务必须以 package entry cutover 为前置，不允许再改命名策略。
- **files edited/created**: `.agents/plan.md`

### T2: 先补齐 guardrail 与 contract 过渡态
- **id**: T2
- **depends_on**: [T1]
- **location**: `tests/guards/dep_rules.lua`, `tests/suites/runtime/runtime_ports_contract.lua`, `src/ui/ctl/ports/init.lua`
- **description**: 在真正重命名前先调整护栏。为新 `src.ui.runtime.state`、`src.ui.runtime.landing_visual_hold`、`src.ui.runtime.host_bridge` 路径补 whitelist；让 contract 测试允许新 package entry 与新 seam path；把 `boundary_contract` 设计成能同时容纳 canonical path 与临时 alias 的中间态，并提前为后续 `anim` / `state` 等 leaf rename 预留 allowlist 更新入口，避免迁移第一批叶子模块时再次打红。
- **validation**: 第一次建立新文件后，`lua tests/guard.lua` 与 `lua tests/contract.lua` 不会因为“新路径还未入白名单”而失败。
- **status**: Completed
- **log**: 2026-03-18 10:57 CST 已在 `tests/guards/dep_rules.lua` 中为 `src/ui/runtime/state.lua`、`landing_visual_hold.lua`、`host_bridge.lua` 补齐未来 whitelist；`src/ui/ctl/ports/init.lua` 已预留新 canonical path 的 allowlist；`tests/suites/runtime/runtime_ports_contract.lua` 改为接受旧路径与过渡态新路径并存。验证：`lua tests/guard.lua`、`lua tests/contract.lua` 通过。
- **files edited/created**: `.agents/plan.md`, `tests/guards/dep_rules.lua`, `src/ui/ctl/ports/init.lua`, `tests/suites/runtime/runtime_ports_contract.lua`

### T3: 迁移 package entry，并原子转移 `describe_boundary_contract()`
- **id**: T3
- **depends_on**: [T2]
- **location**: `src/presentation/runtime/ports/init.lua`, `src/presentation/runtime/ports/common.lua`, `src/ui/ctl/ports/init.lua`
- **description**: 创建新的包入口 `src.presentation.runtime.ports`，把现有 `build()`、`describe_boundary_contract()` 与 `boundary_contract` 真源迁过去。旧 `src/ui.ctl.ports` 在此任务结束时改成纯 alias：`return require("src.presentation.runtime.ports")`。若 `common.lua` 仍需共享，也一并迁到新目录并让旧路径 alias 到新文件。
- **validation**: `src/presentation/runtime/gameplay_runtime_bootstrap.lua`、`tests/support/shared_support.lua`、`tests/suites/runtime/runtime_bootstrap.lua`、`tests/suites/runtime/runtime_ports_contract.lua` 可以切到新包入口；旧包入口仍返回同一个 module table。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T4: 重命名 `src/ui/runtime/*` 三个 canonical seam / bridge
- **id**: T4
- **depends_on**: [T2]
- **location**: `src/ui/runtime/`, `src/presentation/runtime/`, `src/ui/`, `tests/support/shared_support.lua`
- **description**: 新建 `src/ui/runtime/state.lua`、`src/ui/runtime/landing_visual_hold.lua`、`src/ui/runtime/host_bridge.lua` 作为真源，把现有实现迁过去，然后让旧 `runtime_state_seam.lua`、`landing_visual_hold_seam.lua`、`host_runtime_ports.lua` 退化为纯 alias。同步切所有直接消费者到新路径。
- **validation**: `rg 'src\.ui\.runtime\.(runtime_state_seam|landing_visual_hold_seam|host_runtime_ports)' src tests` 只命中 alias shim 或兼容断言；新路径消费者能通过 `guard` 与 `contract`。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T5: 迁移 seam-sensitive adapter 到 `src/presentation/runtime/ports/`
- **id**: T5
- **depends_on**: [T3, T4]
- **location**: `src/presentation/runtime/ports/`, `src/ui/ctl/ports/`, `src/presentation/runtime/state_factory.lua`, `src/presentation/runtime/runtime_event_bridge.lua`
- **description**: 先迁最容易受 seam 重命名影响的 adapter：`anim`、`state`、`ui_sync`、`events`、`callbacks`。迁移顺序固定为“创建新 canonical 文件 -> 更新新消费者 -> 旧路径降为纯 alias”。`state_factory.lua` 与 `runtime_event_bridge.lua` 这两个直接依赖旧 leaf module 的文件必须在这一波一起切走；`boundary_contract` 里仍指向 `src.ui.ctl.ports.anim_ports`、`src.ui.ctl.ports.state_ports` 等旧叶子路径的 allowlist 也必须在同一波同步切到新 canonical path。
- **validation**: 旧 `anim_ports.lua`、`state_ports.lua`、`ui_sync_ports.lua`、`runtime_event_ports.lua`、`state_callback_ports.lua` 只剩 `return require("new.path")`；相关 suite 通过。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T6: 迁移其余 adapter 与根入口消费者，并修 reload helper
- **id**: T6
- **depends_on**: [T3]
- **location**: `src/presentation/runtime/ports/`, `src/presentation/runtime/gameplay_runtime_bootstrap.lua`, `src/app/bootstrap/init.lua`, `tests/support/shared_support.lua`, `tests/suites/presentation/`, `tests/suites/runtime/`, `tests/suites/gameplay/`
- **description**: 迁移 `actor_context`、`clock`、`debug`、`modal`、`view_command` 等剩余 adapter，并把所有根入口消费者统一切到 `src.presentation.runtime.ports`。同时修补 patch/reload 辅助逻辑：凡是依赖 `_load_fresh()` 或直接清 `package.loaded` 的测试，都要在 alias 阶段同时清旧 key 和新 key，避免读取陈旧缓存。
- **validation**: 直接 `require("src.ui.ctl.ports")` 与直接 `require("src.ui.ctl.ports.*")` 的消费者已切到新路径；`runtime_bootstrap` 一类 patch `presentation_ports.build` 的测试继续命中同一个 table 对象。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T7: 同步文档、viewer 快照与命名规则
- **id**: T7
- **depends_on**: [T5, T6]
- **location**: `docs/architecture/boundaries.md`, `docs/architecture/layer-model.md`, `docs/architecture/subsystems.md`, `docs/architecture/arch_view.md`, `scripts/quality/arch/viewer/`
- **description**: 把文档中仍把 `*_ports.lua` 当成当前规则的部分改成新说法：单文件 bundle 可以继续叫 `ports.lua`，但 `ports/` 目录下的 canonical leaf 文件统一使用短名。同步更新层级与子系统文档，说明 `src/presentation/runtime/ports/` 现在是 runtime adapter 的真源。最后刷新 checked-in `arch_view` viewer 快照。
- **validation**: 文档与 viewer 中不再把 `src.ui.ctl.ports.*` 或 `src.ui.runtime.*_seam` 当 canonical source；viewer 快照中的模块路径与源码一致。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T8: 删除 alias 与兼容 metadata，并做最终专项验收
- **id**: T8
- **depends_on**: [T7]
- **location**: `src/ui/ctl/ports/`, `src/ui/runtime/`, `tests/guards/dep_rules.lua`, `tests/suites/runtime/runtime_ports_contract.lua`
- **description**: 在所有消费者都切完且文档已同步后，删除旧 alias 文件，移除 `legacy_alias_modules`、过时 allowlist 与所有仅为兼容层保留的 metadata。最终执行行为、护栏与命名专项验收，证明 canonical 文件已经不再重复父目录信息。
- **validation**: `lua scripts/quality/arch.lua check`、`lua tests/guard.lua`、`lua tests/contract.lua`、`lua tests/behavior.lua` 全通过；`find src/presentation/runtime/ports -name '*_ports.lua'` 为空；`rg 'src\.ui\.runtime\.(runtime_state_seam|landing_visual_hold_seam|host_runtime_ports)|src\.ui\.ctl\.ports' src tests` 为空或仅剩注释性文档样例。
- **status**: Not Completed
- **log**:
- **files edited/created**:

## Parallel Execution Groups

| Wave | Tasks | Can Start When |
|------|-------|----------------|
| 1 | T1 | Immediately |
| 2 | T2 | T1 complete |
| 3 | T3, T4 | T2 complete |
| 4 | T5, T6 | T5 needs T3+T4; T6 needs T3 |
| 5 | T7 | T5, T6 complete |
| 6 | T8 | T7 complete |

## 工作计划

先做不会改变行为、但会影响后续所有 rename 成败的部分。也就是先锁 rename map、先迁 package entry、先让 guardrail 认识新路径。这一步做完后，后续每个文件迁移都只是“把真源搬到新地方，再让旧路径 alias 到新地方”，而不会再出现“新旧两套 contract 同时存在”的分叉状态。

随后把 `src/ui/runtime/` 三个真源与 `src/presentation/runtime/ports/` 的 leaf adapter 分开处理。这样做的原因是它们的风险性质不同：前者主要风险在 seam canonical path 改名；后者主要风险在包入口与 patch-based 测试。把两块拆开，能让实现者在遇到局部失败时更容易回滚到“新真源已存在、旧路径仍 alias 可用”的安全状态。

等新真源全部建立后，再统一处理消费者与测试。这里不要偷懒只改 shared support，因为仓库里已经存在直接 `require` leaf module、直接 patch 包入口、直接 fresh-load 旧路径的测试。如果这些点没补齐，就会在 alias 阶段留下缓存污染或 table 对象分叉。

最后才做看起来“最轻”的文档与快照同步，并在最后一波删掉 alias 与兼容 metadata。删 alias 之前必须确保 viewer、contract、guardrail 都已经以新路径为真源，否则删完很容易出现“运行没问题，但仓库知识面还是旧状态”的残留问题。

## 具体步骤

所有命令都在 `/Users/billyq/Dev/Github/Lua/monopoly` 执行。

1. 先做现状采样，确保实现前后的对照基线一致：

       rg 'src\.ui\.runtime\.(runtime_state_seam|landing_visual_hold_seam|host_runtime_ports)|src\.ui\.ctl\.ports' src tests
       lua tests/guard.lua
       lua tests/contract.lua

   预期当前会命中旧 seam / old ports 路径，但 `guard` 与 `contract` 应通过。

2. 完成 T2 后，先验证护栏允许新路径存在：

       lua tests/guard.lua
       lua tests/contract.lua

   预期新 canonical path 加入后测试仍通过，不会因为 whitelist 缺失而失败。

3. 完成 T3 与 T4 后，验证新真源已可单独被 require：

       lua -e 'package.path = package.path .. ";./?.lua;./?/init.lua"; assert(require("src.presentation.runtime.ports")); assert(require("src.ui.runtime.state")); assert(require("src.ui.runtime.landing_visual_hold")); assert(require("src.ui.runtime.host_bridge"))'

   预期命令正常退出。

4. 完成 T5 与 T6 后，重点回归高风险测试：

       lua tests/contract.lua
       lua tests/behavior.lua

   如需定位 patch/reload 问题，优先单跑：

       lua -e 'package.path = package.path .. ";./tests/?.lua"; require("TestHarness").run({"suites.runtime.runtime_bootstrap","suites.presentation.gameplay_t5_characterization"})'

5. 完成 T7 与 T8 后，执行最终专项验收：

       lua scripts/quality/arch.lua check
       lua scripts/quality/arch.lua viewer --out-dir scripts/quality/arch/viewer
       lua tests/guard.lua
       lua tests/contract.lua
       lua tests/behavior.lua
       find src/presentation/runtime/ports -name '*_ports.lua'
       rg 'src\.ui\.runtime\.(runtime_state_seam|landing_visual_hold_seam|host_runtime_ports)|src\.ui\.ctl\.ports' src tests

   预期所有测试通过，`find` 无输出，`rg` 无输出或仅剩不影响运行的文档样例。

## 验证与验收

验收不是“文件名看起来短了”，而是以下行为同时成立：

- 运行时入口仍能正常建立 `gameplay_loop_ports`、`presentation_runtime` 与 event bridge
- 所有 contract 与 guardrail 都接受新 canonical path，并拒绝把旧兼容路径继续当真源
- patch-based 与 reload-based 测试在 alias 阶段不会命中不同的 module table
- 文档、viewer、contract metadata 与源码中的 canonical path 完全一致

最低验收命令如下：

- `lua scripts/quality/arch.lua check`
- `lua scripts/quality/arch.lua viewer --out-dir scripts/quality/arch/viewer`
- `lua tests/guard.lua`
- `lua tests/contract.lua`
- `lua tests/behavior.lua`
- `find src/presentation/runtime/ports -name '*_ports.lua'`
- `rg 'src\.ui\.runtime\.(runtime_state_seam|landing_visual_hold_seam|host_runtime_ports)|src\.ui\.ctl\.ports' src tests`

## 可重复性与恢复

本计划故意采用“先建新真源、旧路径暂时 alias”的策略，使每一步都可重复执行，并允许中途失败后回到稳定状态。

如果某一波迁移导致大批测试失败，优先回到“新文件保留、旧文件继续 alias”的中间态，不要立刻删旧路径。只要旧路径还是纯 alias，回滚成本就很低。相反，如果在消费者与文档还没切完时就提前删除 alias，恢复会变成跨多个目录的散点修复。

`_load_fresh()` 一类测试辅助函数修改后同样应保持可重复。双 key 清缓存逻辑必须以“新旧 key 任一不存在也不报错”为原则，避免为测试恢复路径再制造新故障。

## 产物与备注

实现完成后，仓库中应出现如下最终形态：

    src/presentation/runtime/ports/init.lua
    src/presentation/runtime/ports/common.lua
    src/presentation/runtime/ports/anim.lua
    src/presentation/runtime/ports/state.lua
    src/presentation/runtime/ports/ui_sync.lua
    src/presentation/runtime/ports/events.lua
    src/presentation/runtime/ports/callbacks.lua
    src/presentation/runtime/ports/actor_context.lua
    src/presentation/runtime/ports/clock.lua
    src/presentation/runtime/ports/debug.lua
    src/presentation/runtime/ports/modal.lua
    src/presentation/runtime/ports/view_command.lua
    src/ui/runtime/state.lua
    src/ui/runtime/landing_visual_hold.lua
    src/ui/runtime/host_bridge.lua

旧 `src/ui/ctl/ports/*.lua` 与旧 `src/ui/runtime/*_seam.lua` / `*ports.lua` 最终不再作为 canonical source 存在。

## 接口与依赖

`src.presentation.runtime.ports` 是新的 package entry，必须继续提供两个稳定入口：

    function presentation_ports.build()
    function presentation_ports.describe_boundary_contract()

`describe_boundary_contract()` 里的 key 保持当前语义名称，例如 `runtime_state`、`landing_visual_hold`、`host_runtime`、`presentation_runtime`、`gameplay_loop_ports`。允许变化的只有其对应的 module path 值，以及最后一波对过时 `legacy_alias_modules` 的删除。

`src.ui.runtime.state`、`src.ui.runtime.landing_visual_hold`、`src.ui.runtime.host_bridge` 仍然只是窄桥接层，不新增业务逻辑，不直写 UI controller 细节。`src.presentation.runtime.ports/*` 仍然只是 adapter / assembly 层，不改变 `turn.loop` 当前依赖的 grouped ports 形状。

当你修改这份计划时，必须同步更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”，并在这些章节里明确写出新增的审查意见或实施发现为什么改变了执行顺序。
