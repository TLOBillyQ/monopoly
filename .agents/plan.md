# Plan: LuaLS 全仓告警整理与 `src/` 优先修复计划

## Summary

当前基线分两层：

- 全仓 `lua-language-server --check=. --checklevel=Warning`：`278` 个问题，`66` 个文件。
- `src` 专用验收口径 `lua-language-server --check=src --checklevel=Warning`：`127` 个 Warning，`45` 个文件。

按你的选择，本轮实施目标只清理 `src/`，并采用“先建基线再修代码”的方式。计划不会靠全局关闭诊断码来“消音” `src`；`vendor/tests/scripts` 只做现状整理，不纳入这一轮修复目标。第一波必须先补 LuaLS 基线配置和宿主类型面，否则 `undefined-global` / `undefined-field` 会持续污染 `src` 诊断面，后续文件修复无法稳定并行。

官方参考将以 LuaLS 的 [Diagnosis report](https://luals.github.io/wiki/diagnosis-report/)、[Settings](https://luals.github.io/wiki/settings/)、[Annotations](https://luals.github.io/wiki/annotations/) 为准。由于 LuaLS 官方设置文档的 `runtime.version` 支持集不含 `Lua 5.5`，本计划默认在 `.luarc.json` 里使用最接近且受支持的 `Lua 5.4` 作为静态分析 runtime。

## Important Changes

- 新增仓库根配置 `.luarc.json`，仅用于稳定 LuaLS 对 `src/` 的诊断基线。
- 新增 LuaLS 专用宿主声明文件 `meta/luals_host.lua`，承载 `GameAPI`、`GlobalAPI`、`UIManager`、`EVENT`、`RegisterTriggerEvent`、`SetFrameOut`、`traceback`、扩展 `math` 字段，以及 `Role` / `Creature` / `Vector3` / `Fixed` 等别名或最小类型面。
- 允许调整少量内部函数签名或调用方式以消除 `redundant-parameter`，例如 `src/ui/render`、`src/ui/pres`、`src/player/actions`、`src/state/state_access` 中已经确认的调用形态漂移。
- 允许修正 LuaLS 注解契约，使返回类型真实反映运行时行为，例如把实际可返回 `nil` 的 editor/export helper 改成可空返回，而不是保留错误的非空注解。
- 不修改 `vendor/third_party` 源码；如需要复用其注解，只通过 `.luarc.json` 的 `workspace.library` 暴露给 LuaLS。

## Diagnostic Inventory

`src` 当前主要告警类型：

- `47` 个 `undefined-global`
- `42` 个 `undefined-field`
- `10` 个 `need-check-nil`
- `10` 个 `return-type-mismatch`
- `8` 个 `redundant-parameter`
- `8` 个 `undefined-doc-name`
- `1` 个 `cast-local-type`
- `1` 个 `deprecated`

`src` 热点目录：

- `58` 个在 `src/ui/render`
- `19` 个在 `src/state/state_access`
- `11` 个在 `src/host/eggy`
- `5` 个在 `src/ui/ctl`
- `5` 个在 `src/ui/input`

热点文件：

- [runtime_editor_exports.lua](/Users/billyq/Dev/Github/Lua/monopoly/src/state/state_access/runtime_editor_exports.lua)
- [runtime_ui.lua](/Users/billyq/Dev/Github/Lua/monopoly/src/ui/render/runtime_ui.lua)
- [board_feedback_service.lua](/Users/billyq/Dev/Github/Lua/monopoly/src/ui/render/board_feedback_service.lua)
- [market.lua](/Users/billyq/Dev/Github/Lua/monopoly/src/ui/render/market.lua)
- [status3d/scene.lua](/Users/billyq/Dev/Github/Lua/monopoly/src/ui/render/status3d/scene.lua)

## Dependency Graph

```text
T1 ── T2 ── T3 ──┬── T4 ──┐
                 ├── T5 ──┼── T7
                 └── T6 ──┘
```

## Tasks

### T1: 建立 LuaLS 基线配置
- **depends_on**: []
- **location**: repo root, [`.luarc.json`](/Users/billyq/Dev/Github/Lua/monopoly/.luarc.json)
- **description**: 新增仓库根 `.luarc.json`，把 `src` 作为主分析目标，设置 `runtime.version = "Lua 5.4"`，补 `workspace.library` 指向 `vendor/third_party` 里可复用注解文件与 `meta/`，并通过 `diagnostics.globals` 声明当前 `src` 实际依赖的宿主全局。此任务不得全局禁用 `undefined-field`、`need-check-nil`、`return-type-mismatch` 等真实问题来源的诊断码。
- **validation**: `lua-language-server --check=src --checklevel=Warning` 能稳定跑完；配置未通过 ignore 规则把 `src` 诊断面整体藏掉。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T2: 建立共享宿主/扩展类型面
- **depends_on**: [T1]
- **location**: [`meta/luals_host.lua`](/Users/billyq/Dev/Github/Lua/monopoly/meta/luals_host.lua)
- **description**: 新增 LuaLS 专用 meta 文件，定义 `GameAPI` / `GlobalAPI` / `UIManager` / `EVENT` / `RegisterTriggerEvent` / `SetFrameOut` / `traceback` 的最小可用类型面，并补扩展 `math.Vector3`、`math.Quaternion`、`math.tofixed` 以及 `Role`、`Creature`、`Vector3`、`Fixed` 等别名。该文件只服务 LuaLS，不参与运行时加载。
- **validation**: 重新跑 `--check=src` 后，`undefined-global` 和 `undefined-field` 数量明显下降，且减少项主要集中在宿主 globals / 宿主字段相关告警。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T3: 重扫并冻结 `src` 修复清单
- **depends_on**: [T1, T2]
- **location**: `src/`
- **description**: 重新执行 `lua-language-server --check=src --check_format=json --checklevel=Warning`，以新的 `.luarc.json + meta` 为基线冻结剩余告警清单。按“文件 + 诊断码 + 行号”生成执行用清单，作为后续并行任务的唯一输入，不再使用当前这份旧统计。
- **validation**: 产出一份明确的剩余清单，按文件分派到 T4/T5/T6，且三个任务写集不重叠。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T4: 修复调用形态漂移与轻量 API 对齐
- **depends_on**: [T3]
- **location**: [market.lua](/Users/billyq/Dev/Github/Lua/monopoly/src/ui/render/market.lua), [market_controls.lua](/Users/billyq/Dev/Github/Lua/monopoly/src/ui/render/market_controls.lua), [panel_slice.lua](/Users/billyq/Dev/Github/Lua/monopoly/src/ui/pres/panel_slice.lua), [panel_builder.lua](/Users/billyq/Dev/Github/Lua/monopoly/src/ui/pres/panel_builder.lua), [inventory.lua](/Users/billyq/Dev/Github/Lua/monopoly/src/player/actions/inventory.lua), [landing_visual_hold.lua](/Users/billyq/Dev/Github/Lua/monopoly/src/state/state_access/landing_visual_hold.lua)
- **description**: 只处理 `redundant-parameter` 和明确的调用形态漂移。优先原则是让签名与真实调用方式一致，不改变行为语义。对可选尾参要保持兼容，对确属多传的调用点直接去掉多余参数；对本来就以方法形态使用的函数，改签名使 LuaLS 与运行时一致。
- **validation**: 这些文件的 `redundant-parameter` 清零；相关调用路径通过 `luac -p` 与回归测试。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T5: 修复 `src/ui/render` 与 `src/host/eggy` 的字段/宿主桥接告警
- **depends_on**: [T3]
- **location**: `src/ui/render/**`（排除 `market.lua`）、`src/host/eggy/**`、[runtime_constants.lua](/Users/billyq/Dev/Github/Lua/monopoly/src/config/gameplay/runtime_constants.lua)、[tick_clock.lua](/Users/billyq/Dev/Github/Lua/monopoly/src/turn/loop/tick_clock.lua)
- **description**: 清理 `undefined-field`、剩余 `undefined-global`、与宿主数学/运行时扩展有关的告警。优先通过更准确的局部注解、nil-guard、适配器返回类型和最小 shape 声明解决；不要把真实缺字段情况简单压成 `any`。本任务不得修改 T4/T6 负责的文件。
- **validation**: 该写集内 `undefined-field` / 宿主桥接类 `undefined-global` 清零，且不引入新的 `need-check-nil` 或行为回归。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T6: 修复状态导出、nilability 与文档注解契约
- **depends_on**: [T3]
- **location**: [runtime_editor_exports.lua](/Users/billyq/Dev/Github/Lua/monopoly/src/state/state_access/runtime_editor_exports.lua), `src/ui/ctl/**`, `src/ui/input/**`, `src/turn/timing/**`, `src/app/bootstrap/**` 中仍有剩余告警的文件
- **description**: 处理 `return-type-mismatch`、`undefined-doc-name`、`need-check-nil`、`cast-local-type` 和少量剩余的配置外 `undefined-global`。关键动作是让 Lua 注解真实反映运行时：实际可返回 `nil` 的导出函数改为可空返回；`Fixed` 等别名要与实际返回数值兼容；确实可能为空的对象访问补 guard。此任务不得接触 `src/ui/render/**` 或 `src/host/eggy/**`。
- **validation**: 该写集内类型与 nilability 告警清零，并人工复核 editor/export helper 的注解没有比运行时更严格。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T7: 最终重扫与回归验证
- **depends_on**: [T4, T5, T6]
- **location**: repo root, `src/`
- **description**: 以 `src` 为唯一验收口径重跑 LuaLS，并补结构与行为回归。若仍有 `src` Warning，按文件回退到对应任务处理，不在此任务里临时加 ignore。
- **validation**:
  - `lua-language-server --check=src --check_format=pretty --checklevel=Warning`
    预期 `no problems found`
  - `rg --files src -g '*.lua' | xargs -I{} luac -p "{}"`
    预期全部通过
  - `lua tests/guard.lua`
    预期通过
  - `lua scripts/quality/arch.lua check`
    预期通过
  - `lua tests/contract.lua`
    预期通过
  - `lua tests/behavior.lua`
    预期通过
- **status**: Not Completed
- **log**:
- **files edited/created**:

## Parallel Execution Groups

| Wave | Tasks | Can Start When |
|------|-------|----------------|
| 1 | T1 | Immediately |
| 2 | T2 | T1 complete |
| 3 | T3 | T2 complete |
| 4 | T4, T5, T6 | T3 complete |
| 5 | T7 | T4, T5, T6 complete |

## Testing Strategy

- 以 `lua-language-server --check=src --checklevel=Warning` 作为唯一静态验收口径，不使用“全仓再过滤 `src`”的二次脚本口径。
- 每个并行任务完成后先跑本任务涉及文件的 `luac -p`，避免把语法错误带到汇总阶段。
- T6 完成后必须人工复核导出注解是否真实反映运行时，特别是 `Role?` / `Creature?` / `Fixed` 这类契约变更。
- 最终统一跑 `guard + arch + contract + behavior`，防止因为 host/UI glue 调整引入结构或回归问题。

## Risks & Mitigations

- `.luarc.json` 可能通过过宽的 globals 或 ignore 规则隐藏真实 `src` 问题。
  处理：禁止在 `src` 范围关闭 `undefined-field`、`need-check-nil`、`return-type-mismatch` 等主诊断码；只声明已被仓库明确依赖的宿主全局。
- 宿主 meta 文件如果建得过宽，会把真实字段缺失压成 `any`。
  处理：`meta/luals_host.lua` 只声明当前 `src` 实际访问到的最小字段面，不做大而全模拟。
- 注解修复可能改变“文档契约”而非运行时行为。
  处理：T6 明确要求对 editor/export helper 做人工读回，确认可空返回与数值别名符合真实行为。
- 本轮只修 `src`，repo-root 配置仍会影响编辑器查看 `tests/scripts/vendor`。
  处理：计划默认保持这些目录的告警可见，不通过 ignoreDir 把它们整体藏掉；它们仅在当前轮次 out of scope。

## Assumptions

- 本轮实施目标是把 `src/` 的 LuaLS Warning 清到 `0`，不是把全仓 `278` 个问题一次清零。
- `vendor/third_party` 不直接改源码；若需要其注解参与分析，只通过 `.luarc.json` 的 `workspace.library` 接入。
- `tests/` 与 `scripts/` 本轮只保留现状统计，不进入修复任务。
- 当前回合处于 Plan Mode，这份计划以内联形式交付；若后续进入执行模式，再落地为 `lua-lsp-src-plan.md`。
