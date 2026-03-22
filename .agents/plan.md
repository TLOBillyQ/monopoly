# 仓库级 Legacy 硬切清理计划

## Summary

- 目标是把业务层 legacy/compat 残留一次性硬切到单一 canonical 真相：主动道具窗口只看 `offer_in_phases`，gameplay/presentation contract 只保留 canonical 字段与 grouped ports，文档/测试/报告不再为旧模型背书。
- 宿主桥接白名单只保留 `/Users/billyq/Dev/Github/Lua/monopoly/src/infrastructure/runtime/global_aliases.lua` 与 `/Users/billyq/Dev/Github/Lua/monopoly/src/host/eggy/vehicle_runtime_legacy.lua`；这两处不改行为，只改边界标注、扫描口径与报告描述。
- `src.game.*` 这类旧概念只允许继续存在于开发者搜索辅助里；默认保留在 `/Users/billyq/Dev/Github/Lua/monopoly/tools/quality/scrap/config.lua` 与 `/Users/billyq/Dev/Github/Lua/monopoly/docs/architecture/scrap4lua.md`，但必须明确标成“历史查询 alias”，不能再被任何业务文档、contract、测试描述成当前仓库路径或兼容入口。
- 由于当前线程仍在 Plan Mode，本计划先以内联规格为准；实施时默认把同内容落到 `legacy-hard-cut-plan.md`。

## Public APIs / Interfaces

- `/Users/billyq/Dev/Github/Lua/monopoly/src/rules/items/availability.lua`
  - 主动窗口判定只走 `offer_in_phases`。
  - `timing` 只用于触发式/响应式卡的时机语义。
  - 现有含混 helper 默认重命名为显式双语义：内部窗口 helper 用 `_offer_phase_allowed`，触发时机 helper 用 `trigger_timing_allowed`；不再保留表达双重职责的 `timing_allowed` 语义。
- `/Users/billyq/Dev/Github/Lua/monopoly/src/turn/loop/ports.lua`
  - output grouped ports 只保留 canonical 名 `invalidate_ui_model`。
  - 删除 `invalidate_ui` 兼容 alias、alias 回填和相关 contract 断言。
  - grouped override 继续是唯一允许形态；legacy flat override 继续明确报错。
- `/Users/billyq/Dev/Github/Lua/monopoly/src/turn/output/state_adapter.lua`、`/Users/billyq/Dev/Github/Lua/monopoly/src/turn/actions/action_dispatcher.lua`、`/Users/billyq/Dev/Github/Lua/monopoly/src/turn/loop/init.lua`
  - 统一只读写 canonical output port 名称，不再 fallback 到 `invalidate_ui`。
- 文档接口口径
  - `/Users/billyq/Dev/Github/Lua/monopoly/docs/architecture/boundaries.md`、`/Users/billyq/Dev/Github/Lua/monopoly/docs/architecture/layer-model.md`、`/Users/billyq/Dev/Github/Lua/monopoly/docs/architecture/subsystems.md` 不再把 `src/game/*`、alias/shim、`pre_move` 主动窗口写成当前事实。
  - `/Users/billyq/Dev/Github/Lua/monopoly/docs/architecture/scrap4lua.md` 可保留 `src.game.*` 搜索 alias，但必须明确为历史查询辅助。

## Dependency Graph

```text
T1 ──┐
T2 ──┼── T4 ── T5 ── T6
T3 ──┘
```

## Tasks

### T1: 主动道具窗口语义硬切
- **depends_on**: []
- **location**: `/Users/billyq/Dev/Github/Lua/monopoly/src/rules/items/availability.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/rules/items/strategy.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/config/content/items.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/domain/item_availability_matrix.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/domain/item_effect_pipeline.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/domain/item.lua`
- **description**:
  - 给所有“主动可点击/主动可展示”的卡统一补齐或校正 `offer_in_phases`，让主动窗口完全由该字段驱动。
  - 保留纯触发/响应卡走 `timing`：`2001/免费卡`、`2007/偷窃卡`、`2009/强征卡`、`2010/免税卡` 继续是 timing-only；`2016/送神卡` 保留 `timing = "trigger_poor_god"` 作为触发语义，但其主动展示窗口仍只认 `offer_in_phases = { "post_action" }`。
  - 在 availability 中拆开“主动窗口判定”与“触发时机判定”；主动卡缺失 `offer_in_phases` 时不再 fallback 到 `timing`。
  - 同步更新 AI 使用路径，确保 `/Users/billyq/Dev/Github/Lua/monopoly/src/rules/items/strategy.lua` 不再通过 legacy timing fallback 判断主动卡是否可考虑。
  - 清掉测试名、断言文案、profile/characterization 文本里对 `pre_move` 主动窗口或 “offer_in_phases overrides legacy timing” 的旧表述。
- **validation**:
  - 主动卡只在声明的 `offer_in_phases` 出现。
  - 触发/响应卡不会在主动窗口中露出。
  - `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/domain/item_availability_matrix.lua` 与相关 AI 测试只验证新术语与新语义。

### T2: gameplay/presentation contract alias 退休
- **depends_on**: []
- **location**: `/Users/billyq/Dev/Github/Lua/monopoly/src/turn/loop/ports.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/turn/output/state_adapter.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/turn/actions/action_dispatcher.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/turn/loop/init.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/runtime/runtime_ports_contract.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/architecture/usecase_boundary_contract.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/architecture/architecture_guard_contract.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/presentation/presentation_ui_model_dispatch.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/gameplay/gameplay_items_startup.lua`
- **description**:
  - 删除 output ports 中 `invalidate_ui` compatibility alias、alias 填充逻辑与 fallback 调用点。
  - 把 contract、fixture、spy、fake ports 全部改成只使用 `invalidate_ui_model`。
  - 保留 grouped ports-only 规则，但测试不再验证 alias 可兜底、不再把 legacy output 名称当作允许入口。
- **validation**:
  - `describe_contract()` 的 output group 不再暴露 `invalidate_ui`。
  - `action_dispatcher`、`turn.loop.init`、测试夹具都只调用 canonical output 名。
  - 旧 alias 行为相关断言从 contract/architecture/presentation/gameplay 测试中消失。
- **status**: completed (2026-03-22 11:42+0800)
- **work log**: removed the output alias from `state_adapter`, `turn.loop.ports`, `action_dispatcher`, and `turn.loop.init`; updated the runtime, architecture, presentation, and gameplay fixtures/tests to use `invalidate_ui_model` only.
- **files modified**: `.agents/plan.md`, `src/turn/output/state_adapter.lua`, `src/turn/loop/ports.lua`, `src/turn/actions/action_dispatcher.lua`, `src/turn/loop/init.lua`, `tests/suites/runtime/runtime_ports_contract.lua`, `tests/suites/architecture/usecase_boundary_contract.lua`, `tests/suites/architecture/architecture_guard_contract.lua`, `tests/suites/presentation/presentation_ui_model_dispatch.lua`, `tests/suites/gameplay/gameplay_items_startup.lua`
- **errors/gotchas**: the harness result uses `failed` instead of `ok`; validation passed on 78 targeted cases after checking `result.failed == false`.

### T3: 宿主桥接例外显式化
- **depends_on**: []
- **location**: `/Users/billyq/Dev/Github/Lua/monopoly/src/infrastructure/runtime/global_aliases.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/host/eggy/vehicle_runtime_legacy.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/state/state_access/vehicle_runtime_source.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/tools/quality/arch/config.json`
- **description**:
  - 在代码注释与命名说明里明确这两处是“宿主桥接例外 / 运行时接缝”，不是业务兼容层。
  - 在 vehicle runtime source 的模块选择逻辑附近说明：legacy 名称只表示宿主桥接实现来源，不代表业务层继续支持 legacy contract。
  - 在 `arch_view` 配置和后续报告口径中把 `global_aliases` 归类为显式 seam/bridge exception，而不是模糊的 runtime alias 常规实现。
- **validation**:
  - 运行时行为不变。
  - 架构扫描/报告能把两处白名单识别为例外桥接，而不是推广成通用 legacy 策略。

### T4: Guard 与工具口径收紧
- **depends_on**: [T1, T2, T3]
- **location**: `/Users/billyq/Dev/Github/Lua/monopoly/tests/guards/dep_rules.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/tools/quality/scrap/config.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/docs/architecture/scrap4lua.md`, `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/architecture/scrap4lua_contract.lua`
- **description**:
  - 在 guard 中新增更聚焦的禁止项，拦截业务层重新引入 `invalidate_ui`、业务 alias/shim、兼容入口文案。
  - 为最终 residue scan 建立 allowlist：两处宿主桥接白名单可出现 `legacy/alias` 语义；`pre_move` 只允许继续出现在真实阶段机制和工具链的少量合法位置，不作为主动道具窗口术语扫描目标。
  - 保留 `scrap4lua` 的 `src.game.*` 查询 alias，但将其文档和 contract 明确改为“历史搜索词扩展”，不是 canonical 路径映射承诺。
- **validation**:
  - guard 能拦截新增业务层 alias/shim/compat 文案。
  - `scrap4lua` 查询扩展仍可工作，但输出/文档不会把旧路径表述成当前仓库真相。
- **status**: completed (2026-03-22 11:54+0800)
- **work log**: tightened `dep_rules` with retired business wording checks for `invalidate_ui`/alias/shim/compat and active-window `pre_move` phrasing, kept the two host-bridge seam snippets whitelisted, renamed the scrap query glossary to historical search-term aliases, and updated the scrap doc/contract to describe `src.game.*` as historical search expansion only.
- **files modified**: `.agents/plan.md`, `tests/guards/dep_rules.lua`, `tools/quality/scrap/config.lua`, `docs/architecture/scrap4lua.md`, `tests/suites/architecture/scrap4lua_contract.lua`
- **errors/gotchas**: none.

### T5: 文档与报告同步到真实实现
- **depends_on**: [T1, T2, T3, T4]
- **location**: `/Users/billyq/Dev/Github/Lua/monopoly/docs/architecture/boundaries.md`, `/Users/billyq/Dev/Github/Lua/monopoly/docs/architecture/layer-model.md`, `/Users/billyq/Dev/Github/Lua/monopoly/docs/architecture/subsystems.md`, `/Users/billyq/Dev/Github/Lua/monopoly/docs/reports/codebase-module-analysis.md`
- **description**:
  - 重写架构文档中把 `src/game/*` 当作当前目录、把 alias/shim 当作保留策略、把 `pre_move` 当作主动道具窗口、把旧 `runtime_global_aliases` 名称当作现状的段落。
  - 在确需保留历史/工具语境的地方显式加“历史查询”“语义投影已退休”标识，不留模糊表述。
  - `codebase-module-analysis` 若为生成产物，则在 T4 完成后按新工具/新口径重生成；若为手写报告，则直接按新事实修订。
- **validation**:
  - 除 `/Users/billyq/Dev/Github/Lua/monopoly/docs/architecture/scrap4lua.md` 这类明确历史查询文档外，其余文档不再把 `src/game/*`、业务 compat alias、`pre_move` 主动窗口写成当前事实。
  - 报告中 `global_aliases` 与 vehicle bridge 的描述与白名单口径一致。
- **status**: completed (2026-03-22 12:01+0800)
- **work log**: rewrote the architecture boundary/layer/subsystem docs to the current `src/turn`, `src/rules`, `src/computer`, `src/player`, and `src/state` layout; removed stale `src/game/*` projections and alias-retention wording; updated the module analysis report to use `global_aliases` seam-exception wording and to scope `pre_move` as a phase label, not an active-item window.
- **files modified**: `.agents/plan.md`, `docs/architecture/boundaries.md`, `docs/architecture/layer-model.md`, `docs/architecture/subsystems.md`, `docs/reports/codebase-module-analysis.md`
- **errors/gotchas**: the first pass left one duplicate block in `subsystems.md`; it was removed before validation.

### T6: 最终验证与残留清扫
- **depends_on**: [T5]
- **location**: 全仓
- **description**:
  - 运行完整验证：`lua tests/behavior.lua`、`lua tests/contract.lua`、`lua tests/guard.lua`。
  - 做定向 residue scan，而不是全仓无差别扫词：
    - 主动窗口旧术语扫描聚焦 `/Users/billyq/Dev/Github/Lua/monopoly/src/rules`, `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/domain`, `/Users/billyq/Dev/Github/Lua/monopoly/docs`。
    - `invalidate_ui` 扫描聚焦 `/Users/billyq/Dev/Github/Lua/monopoly/src/turn`, `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites`, `/Users/billyq/Dev/Github/Lua/monopoly/docs`。
    - `src/game/` 扫描只允许命中历史查询工具文档/配置，不允许命中架构事实文档、contract、业务测试。
    - `legacy|alias|shim` 扫描只允许命中两处宿主桥接白名单、`scrap4lua` 历史查询语境和明确历史说明。
- **validation**:
  - 三条测试 lane 通过。
  - residue scan 只剩已批准白名单与历史查询说明。
  - 不再出现“代码已硬切、文档/contract 还在讲兼容”的分裂状态。
- **status**: completed (2026-03-22 12:33+0800)
- **work log**: reran `behavior` / `contract` / `guard` lanes, restored the roll helper used by characterization coverage, aligned gameplay characterization/startup tests with the hard-cut `offer_in_phases` semantics, renamed remaining local `runtime_global_aliases` references to `global_aliases`, and tightened `arch_view.md` so old naming is described only as historical context.
- **files modified**: `.agents/plan.md`, `src/turn/phases/roll.lua`, `tests/suites/gameplay/gameplay_t4_characterization.lua`, `tests/suites/gameplay/gameplay_items_startup.lua`, `tests/suites/gameplay/gameplay_cases.lua`, `src/app/bootstrap/runtime_install.lua`, `docs/architecture/arch_view.md`
- **errors/gotchas**: the first full `behavior` run exposed stale characterization/startup expectations after the hard cut; after updating those expectations and restoring the private roll helper used by those characterizations, all three lanes passed.

## Parallel Execution Groups

| Wave | Tasks | Can Start When |
|------|-------|----------------|
| 1 | T1, T2, T3 | Immediately |
| 2 | T4 | T1, T2, T3 complete |
| 3 | T5 | T4 complete |
| 4 | T6 | T5 complete |

## Test Plan

- **道具/AI**
  - 主动卡在 `pre_action` / `post_action` 的暴露完全由 `offer_in_phases` 决定。
  - `free_rent`、`steal`、`strong`、`tax_free` 这类触发/响应卡不会因为 timing fallback 混入主动窗口。
  - AI 的 `_ai_can_use_item` 与相关 probe 逻辑对主动卡不再依赖 legacy timing fallback。
- **contract/runtime**
  - grouped ports 仍是唯一可接受 override 形态。
  - output contract 仅有 `invalidate_ui_model`，测试/fixture/spy 都不再使用 `invalidate_ui`。
  - legacy flat override 继续报错，但报错只表达 grouped-only 约束，不再伴随 alias 兼容行为。
- **docs/tooling**
  - 架构文档与报告不再宣称 `src/game/*` 是当前目录事实。
  - `scrap4lua` 仍能把 `src.game.systems` 扩展到 `src.rules`，但文档与 contract 会明确它只是历史查询词。
  - `arch_view` / 报告中两处宿主桥接白名单被描述为 seam exception，而不是业务 legacy 入口。

## Assumptions

- 白名单例外严格限定为 `/Users/billyq/Dev/Github/Lua/monopoly/src/infrastructure/runtime/global_aliases.lua` 与 `/Users/billyq/Dev/Github/Lua/monopoly/src/host/eggy/vehicle_runtime_legacy.lua`；其余 `legacy/alias/shim` 语义默认一律退休。
- `pre_move` 作为回合/移动阶段词本身没有被全仓禁用；本轮只移除它在“主动道具窗口”语义里的残留背书。
- `src.game.*` 旧概念仅在开发者搜索辅助中历史保留，不再允许出现在架构事实、业务 contract、运行时接口或回归测试期望里。

## Progress Log

- [x] T1 完成：主动道具窗口改为只看 `offer_in_phases`，AI 侧也只按显式 offer 窗口筛选；`送神卡` 增加了 `post_action` 回归测试，`free_rent/strong/steal/tax_free` 这类反应卡从主动窗口中退出。
  - Files: `src/rules/items/availability.lua`, `src/rules/items/strategy.lua`, `tests/suites/domain/item_availability_matrix.lua`, `tests/suites/domain/item_effect_pipeline.lua`, `tests/suites/domain/item.lua`, `.agents/plan.md`
  - Gotchas: `送神卡` 测试需要先给玩家挂上 `poor` deity 才会进入可选列表。
- [x] T4 完成：guard 新增 retired wording 扫描，限制业务层重新引入 `invalidate_ui` / alias / shim / compat 与主动窗口 `pre_move` 表述；`scrap4lua` 文档和 contract 改为“历史搜索词扩展”口径。
  - Files: `tests/guards/dep_rules.lua`, `tools/quality/scrap/config.lua`, `docs/architecture/scrap4lua.md`, `tests/suites/architecture/scrap4lua_contract.lua`, `.agents/plan.md`
  - Validation: `lua tests/guard.lua` 通过；`suites.architecture.scrap4lua_contract` 定向回归 6/6 通过。
- [x] T5 完成：将架构边界、分层模型、子系统索引与模块分析报告同步到当前目录语义，移除 `src/game/*` 的现态投影并把 `global_aliases`/`pre_move` 相关措辞收敛到 seam exception 与阶段名语境。
  - Files: `docs/architecture/boundaries.md`, `docs/architecture/layer-model.md`, `docs/architecture/subsystems.md`, `docs/reports/codebase-module-analysis.md`, `.agents/plan.md`
  - Validation: 定向 `rg` residue scan 只剩边界文件里对旧文件命名的说明，以及报告里对 `pre_move` 作为阶段名的显式说明。
- [x] T6 完成：三条测试 lane 全部通过；定向 residue scan 中 `invalidate_ui` 已清零，`src.game.*` 只剩 `scrap4lua` 历史搜索词与 contract，`pre_move` 只剩 domain 负向断言和报告中的阶段名说明。
  - Files: `src/turn/phases/roll.lua`, `tests/suites/gameplay/gameplay_t4_characterization.lua`, `tests/suites/gameplay/gameplay_items_startup.lua`, `tests/suites/gameplay/gameplay_cases.lua`, `src/app/bootstrap/runtime_install.lua`, `docs/architecture/arch_view.md`, `.agents/plan.md`
  - Validation: `lua tests/behavior.lua`, `lua tests/contract.lua`, `lua tests/guard.lua`, plus targeted `rg` scans for `pre_move`, `invalidate_ui`, `src.game`, and `legacy|alias|shim`.

## Progress

- [x] (2026-03-22 11:41+0800) T3 completed: reworded the host bridge seam comments in `src/infrastructure/runtime/global_aliases.lua` and `src/host/eggy/vehicle_runtime_legacy.lua`, clarified the legacy module name in `src/state/state_access/vehicle_runtime_source.lua`, and renamed the `arch_view` label for `global_aliases` to `infrastructure_runtime_bridge_exception`. Files modified: `src/infrastructure/runtime/global_aliases.lua`, `src/host/eggy/vehicle_runtime_legacy.lua`, `src/state/state_access/vehicle_runtime_source.lua`, `tools/quality/arch/config.json`, `.agents/plan.md`. Gotchas: none; runtime behavior unchanged.
- [x] (2026-03-22 11:54+0800) T4 completed: added the retired business wording guard in `tests/guards/dep_rules.lua`, renamed the scrap glossary alias table to `historical_search_term_aliases`, and updated `docs/architecture/scrap4lua.md` plus `tests/suites/architecture/scrap4lua_contract.lua` to describe `src.game.*` as historical search-term expansion instead of a canonical path promise. Validation: default `dep_rules.run()` passed, a synthetic bad-file probe tripped on `compatibility%s+alias`, and the targeted `architecture.scrap4lua_contract` suite passed 6/6.
- [x] (2026-03-22 12:33+0800) T6 completed: reran the full behavior/contract/guard lanes after fixing stale startup and characterization expectations, restored `roll._resolve_phase_wait_result` for the retained characterization coverage, renamed remaining local `runtime_global_aliases` variable names, and tightened `docs/architecture/arch_view.md` so old naming is documented only as history. Residue scans now leave only approved historical contexts (`scrap4lua`, guard/contracts, the host bridge whitelist files, and the explicit `pre_move` phase note in `docs/reports/codebase-module-analysis.md`).
