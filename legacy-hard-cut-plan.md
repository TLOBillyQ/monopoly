# Plan: 仓库级 Legacy 普查与硬切清理

**Generated**: 2026-03-22

## Overview
本轮按“业务层硬切 + 宿主桥接例外保留”执行，目标是把 gameplay / flow / presentation contract / tests / docs 中仍残留的 legacy 兼容语义彻底收敛到当前 canonical 规则，只保留 `src/infrastructure/runtime/global_aliases.lua` 与 `src/host/eggy/vehicle_runtime_legacy.lua` 两个宿主桥接例外，并把它们从“业务兼容入口”语义里摘出来。

调研结论表明，本次工作不是单点删除，而是四类事实同步：
- 主动道具窗口语义仍有 `offer_in_phases` 与 `cfg.timing` 双轨并存，`src/rules/items/availability.lua` 仍保留 fallback，`src/rules/items/strategy.lua` 的 AI 判定也仍经由旧 timing 语义间接参与决策。
- `src/turn/loop/ports.lua` 已拒绝 legacy flat override，但仍保留 `output.invalidate_ui` / `invalidate_ui_model` 的双名兼容映射；`src/turn/output/state_adapter.lua` 与调用侧也仍在为 alias 兜底，相关 contract/test 继续背书。
- 文档存在明显过期描述：仍写 `pre_move` 道具阶段、`src/ui/ctl/ports` 兼容 alias、旧 `src/game/*` 目录语义，以及错误的 `runtime_global_aliases` 路径；且不止一份文档仍停留在旧时代目录模型。
- 护栏已有部分 legacy 禁令，但仍有过期根路径（如 `src/ui/ctl/ports`）与缺失项，尚不足以阻止“非白名单 legacy 语义回流”。

目标白名单只有 `src/infrastructure/runtime/global_aliases.lua` 与 `src/host/eggy/vehicle_runtime_legacy.lua` 两处；当前仓库事实尚未收敛到这两处，因此计划需要先完成业务层 alias 退休，再把“仅保留两处 host seam 例外”固化下来。

## Prerequisites
- 可编辑仓库源码、测试与文档
- 可运行 Lua 测试入口（至少 `lua tests/contract.lua`、`lua tests/behavior.lua`、`lua tests/guard.lua`）
- 允许按需追加/收紧 guard 规则

## Dependency Graph

```text
T1 ──┬── T3 ──┬── T6 ──┐
T2 ──┘        │        ├── T8
              ├── T7 ──┤
T4 ───────────┘        │
T5 ────────────────────┘
```

## Tasks

### T1: 收敛主动道具窗口真源到 `offer_in_phases`
- **depends_on**: []
- **location**: `src/rules/items/availability.lua`, `src/rules/items/strategy.lua`, `src/config/content/items.lua`, `src/rules/items/handlers.lua`, `src/rules/items/roadblock.lua`
- **description**: 把主动道具窗口判定完全收敛到 `offer_in_phases`。移除或隔离 `cfg.timing` 对主动窗口的 fallback 语义，只保留它服务触发式/响应式卡。若 `availability.timing_allowed` / 相关帮助函数仍承载双重语义，重命名为“主动窗口判定”和“触发时机判定”两套显式接口，避免继续把 active window 与 trigger timing 混在同一个词上。
- **validation**: 主动道具在 `pre_action` / `post_action` 的暴露只由 `offer_in_phases` 决定；`pre_move` 不再是任何主动窗口输入；相关调用点不再依赖 `cfg.timing` 兜底主动窗口。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T2: 列出并固定宿主桥接例外白名单
- **depends_on**: []
- **location**: `src/infrastructure/runtime/global_aliases.lua`, `src/host/eggy/vehicle_runtime_legacy.lua`, 相关边界文档/注释位置
- **description**: 明确本轮唯一白名单例外就是 `global_aliases` 与 `vehicle_runtime_legacy`。不改其运行时行为，但要定义其身份：宿主桥接例外 / 运行时接缝，而不是业务兼容入口。若缺少就近注释或边界说明，补齐最少必要说明，供文档与 guard 共用同一口径。
- **validation**: 白名单例外在代码或文档中被清楚标注为 host/runtime seam；计划内其他 legacy/alias 语义都不再以“这也是例外”为理由保留。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T3: 退休 loop/presentation contract 中的业务 alias
- **depends_on**: [T1]
- **location**: `src/turn/loop/ports.lua`, `src/turn/actions/action_dispatcher.lua`, `src/turn/loop/init.lua`, `src/turn/output/state_adapter.lua`, `src/presentation/runtime/ports/init.lua`
- **description**: 在业务层 contract 中只保留 canonical 名称与 grouped 形态。重点检查并移除 `output.invalidate_ui` 与 `invalidate_ui_model` 的双名兼容映射，以及其他仍允许 legacy override / alias 输出的逻辑；同步更新调用方到唯一 canonical 名称。保留宿主桥接例外，但不能继续把业务 contract alias 当成兼容层。
- **validation**: `gameplay_loop_ports` 只接受 grouped canonical ports；输出端口只暴露并消费 canonical 名称；不再通过 alias 补齐 override；presentation boundary contract 与实现一致。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T4: 清理回归测试与命名中的旧时机模型
- **depends_on**: [T1]
- **location**: `tests/suites/domain/item_availability_matrix.lua`, `tests/suites/domain/item_effect_pipeline.lua`, `tests/suites/gameplay/gameplay_t4_characterization.lua`, `src/config/testing/test_profiles.lua`, 其他命中 `pre_move` / `legacy timing` / `manual` 旧语义的测试文件
- **description**: 把测试名、断言文案、profile goal/covers 从“legacy timing / pre_move / manual timing”迁到当前术语。保留必要的反向断言（例如 `pre_move` 不存在）时，改为“旧窗口已退休”的负向契约，而不是“legacy timing 仍可覆盖”的正向契约。
- **validation**: 测试名称与断言不再暗示业务层仍支持旧时机模型；profile 中不再出现 `roadblock_manual_target_setup` 等与旧模型耦合的命名残留（如确属本轮范围内）。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T5: 收紧 legacy/shim guard 与白名单边界
- **depends_on**: [T2]
- **location**: `tests/guards/dep_rules.lua`, 可能新增的 guard 脚本 / 文档扫描脚本
- **description**: 更新 guard，使其面向当前仓库事实而非过期目录。修正 `src/ui/ctl/ports` 等已不存在根路径；新增对业务层 alias/shim/legacy 入口、主动道具 `pre_move` 术语、非白名单 legacy 文案的拦截；同时允许白名单宿主桥接例外继续存在但不向业务层扩散。
- **validation**: 新增业务层 alias/shim/legacy 入口会被 guard 拦截；对白名单例外不过度误伤；guard 根路径与现有目录一致。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T6: 同步 runtime/contract 测试到 canonical 端口语义
- **depends_on**: [T3]
- **location**: `tests/suites/runtime/runtime_ports_contract.lua`, `tests/suites/architecture/usecase_boundary_contract.lua`, `tests/suites/gameplay/gameplay_cases.lua`
- **description**: 将 contract/runtime 测试更新为只验证 canonical grouped ports 与 canonical output 名称，移除对 `invalidate_ui` 等 alias 兼容行为的背书；保留 legacy flat override 被拒绝的断言，但让消息与 contract 描述仅表达 canonical 规则。
- **validation**: contract/runtime/gameplay 相关套件只验证 canonical grouped ports；alias fallback 不再是通过条件；旧 override 入口要么被删除，要么明确报错。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T7: 重写架构文档与报告中的过期 legacy 叙述
- **depends_on**: [T2]
- **location**: `docs/architecture/layer-model.md`, `docs/architecture/arch_view.md`, `docs/architecture/boundaries.md`, `docs/reports/codebase-module-analysis.md`, 其他命中 `pre_move` / `alias` / `compat` / `src/game/*` 的文档
- **description**: 按当前实现重写过期文档。删除或改写仍声称存在 `pre_move` 道具阶段、`src/ui/ctl/ports` 兼容 alias、旧 `src/game/*` canonical 目录、`runtime_global_aliases` 旧路径、以及“alias 仍保留”的叙述。对宿主桥接白名单例外用单独边界说明，不再与业务兼容语义混写。
- **validation**: 文档不再描述不存在的阶段/目录/兼容入口；白名单例外被单独标识为 host seam；实现、测试、文档三者术语一致。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T8: 统一回归验证并清理计划外残留
- **depends_on**: [T4, T5, T6, T7]
- **location**: `tests/behavior.lua`, `tests/contract.lua`, `tests/guard.lua`, 以及必要时的 targeted grep 检查
- **description**: 运行行为、契约、护栏回归，并对 `pre_move`、业务层 `legacy/alias/compat/shim`、旧 output alias、过期目录名进行仓库级复查。若只剩白名单宿主桥接例外，则记录并结束；若发现新残留，回补到对应任务文件。
- **validation**: 关键测试通过；搜索结果中业务层 legacy 语义显著收敛，仅剩白名单宿主桥接例外与确有必要的第三方/工具语义；文档扫描不再出现过期口径。
- **status**: Not Completed
- **log**:
- **files edited/created**:

## Parallel Execution Groups

| Wave | Tasks | Can Start When |
|------|-------|----------------|
| 1 | T1, T2 | Immediately |
| 2 | T3, T4, T5, T7 | T1/T2 satisfy each task dependency |
| 3 | T6 | T3 complete |
| 4 | T8 | T4, T5, T6, T7 complete |

## Testing Strategy
- 先做 targeted 契约验证：主动道具窗口矩阵、loop ports contract、runtime ports contract。
- 再跑三条主回归：`lua tests/behavior.lua`、`lua tests/contract.lua`、`lua tests/guard.lua`。
- 用仓库级搜索复核关键残留词：`pre_move`、`offer_in_phases`、`legacy`、`alias`、`compat`、`shim`、`invalidate_ui`。
- 对宿主桥接例外单独确认行为未变，避免误把 host seam 也硬切掉。

## Risks & Mitigations
- 文档与代码演进不同步：先以当前代码真相为准，再统一改文档与测试，避免“先修文档后发现实现仍双轨”。
- `timing` 同时承载触发式卡语义：T1 必须区分主动窗口与触发时机，避免误伤 `post_action` / `tax_prompt` / `pass_player` 等触发式卡。
- output alias 清理影响面分散：T3 后立刻执行 T6，防止 contract/test 继续隐藏旧兼容路径。
- guard 误伤白名单例外：T2 先定义白名单，再由 T5 收紧规则，避免把宿主桥接误判成业务兼容残留。
- 旧文档跨多个时代：T7 以“删除过期承诺优先于保留历史叙述”为原则，不为不存在实现保留说明文字。
