# Plan: 仓库级回归 / 告警 / 历史遗留清理（Swarm 版）

**Generated**: 2026-03-17 Asia/Shanghai

## Overview

本轮工作分成 3 类债务同时推进：付费购买告警路径、6 个被屏蔽的 T2 characterization 用例、4 组高 ROI CRAP 热点。实现原则是“小补测 + 小修正 + 小提取”，不做跨层重构，不恢复已退役 helper，不覆盖用户在 `/Users/billyq/Dev/Github/Lua/monopoly/src/host/eggy/paid_purchase_gateway.lua` 里的未提交修改。

本计划只依赖仓库内文档与代码：Lua 标准库、Eggy API 已由 `/Users/billyq/Dev/Github/Lua/monopoly/docs/eggy/api/07_unit_entities.md` 和架构文档覆盖；本轮不引入新外部依赖，因此无需额外外部文档查询。当前仍处于 Plan Mode，所以本计划先以内联形式交付，不落盘为 `*-plan.md`。

## Prerequisites

- 工作目录固定为 `/Users/billyq/Dev/Github/Lua/monopoly`
- 实施前先保留 `/Users/billyq/Dev/Github/Lua/monopoly/src/host/eggy/paid_purchase_gateway.lua` 当前 diff，不得回退用户 hunks
- 本轮 CRAP 基线按以下符号记录并逐个比较 before/after：
  - `pricing.total_invested`: `crap=30.00 coverage=0.00`
  - `_add_neighbor`: `crap=20.00 coverage=0.00`
  - `_handle_market_navigation`: `crap=20.00 coverage=0.00`
  - `_resolve_market_choice`: `crap=12.00 coverage=0.00`
  - `_build_move_anim_data`: `crap=17.01 coverage=0.07`
  - `_build_move_args`: `crap=9.56 coverage=0.10`

## Dependency Graph

```text
T0A ──┬── T1 ──┐
      ├── T3 ──┤
      ├── T4A ─┤
      └── T4B ─┤
T0B ───── T2 ── T5 ──┘
                    │
                    v
                   T6 ── T7 ── T8
```

## Tasks

### T0A: 记录工作树保护点与 CRAP 基线
- **depends_on**: []
- **location**: `/Users/billyq/Dev/Github/Lua/monopoly/src/host/eggy/paid_purchase_gateway.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/tmp/crap_report.json`
- **description**: 记录付费网关当前 diff，确认后续修改只能叠加；重新生成一次 CRAP 报告并单独摘出 6 个目标符号的 before 值，供 T1/T3/T4A/T4B 各自比较。这里不改代码，只产出基线证据。
- **validation**: `git diff -- /Users/billyq/Dev/Github/Lua/monopoly/src/host/eggy/paid_purchase_gateway.lua` 与 `lua scripts/quality/crap.lua report --lane behavior --out tmp/crap_report.json` 都成功，且已记录 6 个符号的 before 值。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T0B: 盘点 6 个 T2 disabled case 的真实失败模式
- **depends_on**: []
- **location**: `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/gameplay/gameplay_t2_characterization.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/tests/catalog.lua`
- **description**: 不先删 catalog 屏蔽；先用 ad-hoc `TestHarness.run_all` 只跑 `gameplay_t2_characterization` 里这 6 个 case，并在内存里临时清掉对应 `disabled_in`。记录每个 case 失败是因为断言过时、依赖已迁移、还是引用了退役 API。允许把旧断言替换成“当前真实行为”断言，但不允许恢复 legacy helper。
- **validation**: 六个 case 都有单独失败归因，且归因结果能直接指导 T2 改写。
- **status**: Completed
- **log**: 2026-03-17: 用 ad-hoc harness 仅在内存里清掉 6 个 target case 的 `disabled_in` 后重跑；6/6 全部通过，没有实际失败。结论：当前 `tests/catalog.lua` 的这 6 条屏蔽已过期，T2 应直接以“移除陈旧屏蔽 + 保持用例稳定通过”为主，而不是先修失败逻辑。逐项结果：`_test_apply_dice_multiplier_with_multiplier` 通过；`_test_resolve_wait_state_prefers_anim` 通过；`_test_resolve_wait_state_landing_visual` 通过；`_test_fill_ui_sync_defaults_preserves_custom` 通过；`_test_update_countdown_nil_turn` 通过；`_test_build_ui_gate_all_true` 通过。
- **files edited/created**: `/Users/billyq/Dev/Github/Lua/monopoly/.agents/plan.md`

### T1: 锁定付费购买告警路径
- **depends_on**: [T0A]
- **location**: `/Users/billyq/Dev/Github/Lua/monopoly/src/host/eggy/paid_purchase_gateway.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/domain/paid_currency.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/runtime/misc.lua`
- **description**: 在保留现有 dirty diff 的前提下，只补足必要行为：`setup_for_game` 只做映射预热，不为隐藏/禁用商品告警；`start` 遇到真实缺映射才 warn，并保持每个 `product_id` 只 warn 一次；角色缺少 `show_goods_purchase_panel` 时返回 `purchase_api_missing` 且不触发面板。优先通过测试驱动，只有测试暴露缺口时才改源文件。
- **validation**: 至少覆盖 5 个断言：隐藏/禁用项 setup 不告警、真实缺映射 start 告警、重复 start 同一商品只告警一次、正常 paid purchase 仍打开面板、缺失 purchase API 返回 `purchase_api_missing`；本任务结束后跑 `lua tests/behavior.lua`。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T2: 修复并本地重启用 6 个 T2 case
- **depends_on**: [T0B]
- **location**: `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/gameplay/gameplay_t2_characterization.lua`
- **description**: 只改 suite 文件，不动 catalog。修复这 6 个 case：`_test_apply_dice_multiplier_with_multiplier`、`_test_resolve_wait_state_prefers_anim`、`_test_resolve_wait_state_landing_visual`、`_test_fill_ui_sync_defaults_preserves_custom`、`_test_update_countdown_nil_turn`、`_test_build_ui_gate_all_true`。实现策略是面向当前真实入口：`landing_visual_hold`、`land._resolve_wait_state`、`ui_sync_defaults.resolve_ui_gate`、`tick_ui_sync.update_countdown`、当前 move phase 行为。可复用 `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/gameplay/gameplay_t2_enabled_cases.lua` 的现态脚手架模式，但不要把它并入 catalog。
- **validation**: 先通过 ad-hoc harness 让这 6 个 case 在本地“解除屏蔽”后全部通过；此阶段不得修改 `/Users/billyq/Dev/Github/Lua/monopoly/tests/catalog.lua`。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T3: 处理低风险 CRAP 热点（pricing + default_map）
- **depends_on**: [T0A]
- **location**: `/Users/billyq/Dev/Github/Lua/monopoly/src/rules/land/pricing.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/src/config/content/maps/default_map.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/presentation/read_model_contract.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/domain/movement.lua`
- **description**: `pricing.total_invested` 一律扩展现有 `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/presentation/read_model_contract.lua`，不要新增重复断言到别的 suite；目标是补齐负 level、空 price、稀疏/超长 level 等分支。`_add_neighbor` 放到 map/movement 相关 suite 中，验证双向邻接、方向推导、非法非正交边拒绝。除非测试无法命中，不改源实现。
- **validation**: 跑 `lua tests/contract.lua`，然后重新跑 CRAP 报告；`pricing.total_invested` 与 `_add_neighbor` 的 coverage 必须大于 0，且 score 低于 T0A 记录值。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T4A: 处理 move phase 热点
- **depends_on**: [T0A]
- **location**: `/Users/billyq/Dev/Github/Lua/monopoly/src/turn/phases/move.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/gameplay/gameplay_cases.lua`
- **description**: 只处理 `_build_move_args` 与 `_build_move_anim_data`。优先在 `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/gameplay/gameplay_cases.lua` 增加行为测试，覆盖 `extra` 合并、`continue_from_market/steal` 相关字段透传、动画数据里的 `visited/steps/vehicle_id/interrupt flags`。除非测试达不到目标覆盖，不做额外重构。
- **validation**: 跑 `lua tests/behavior.lua`，然后重新跑 CRAP 报告；`_build_move_args` 与 `_build_move_anim_data` 的 coverage 必须高于当前基线，且 score 下降。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T4B: 处理 action dispatcher 热点
- **depends_on**: [T0A]
- **location**: `/Users/billyq/Dev/Github/Lua/monopoly/src/turn/actions/action_dispatcher.lua`, `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/presentation/presentation_ui_model_dispatch.lua`
- **description**: 覆盖 `_resolve_market_choice` 与 `_handle_market_navigation`，但测试必须经 `dispatch_action` 入口驱动，并 stub `validator`、`market_service.choice.apply_navigation`、`output_ports.sync_pending_choice`，不要直接白盒调用 local function。场景至少包括：turn pending choice 优先、fallback 到 state pending choice、非 `market_buy` 拒绝、validator 拒绝、apply_navigation 拒绝、成功同步 pending choice。
- **validation**: 跑 `lua tests/behavior.lua`，必要时补跑 `lua tests/contract.lua`；然后重新跑 CRAP 报告，两个目标符号 coverage > 0 且 score 低于 T0A 基线。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T5: 移除 catalog 屏蔽并做第一次整体验证
- **depends_on**: [T2]
- **location**: `/Users/billyq/Dev/Github/Lua/monopoly/tests/catalog.lua`
- **description**: 只有在 T2 本地重启用通过后，才删除对应 `disabled_cases` 的 6 条屏蔽项。不要顺手动其他注释掉的旧测试草稿。删除后立即跑 behavior lane，确保噪音来源只来自本轮修改。
- **validation**: `lua tests/behavior.lua` 通过，且 `/Users/billyq/Dev/Github/Lua/monopoly/tests/catalog.lua` 中不再存在这 6 个 case 的 `disabled_cases` 项。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T6: 合流验证 behavior / contract
- **depends_on**: [T1, T3, T4A, T4B, T5]
- **location**: 仅验证，不新增实现位置
- **description**: 所有并行任务落地后，先跑高频车道收敛冲突，只修本轮引入的回归，不扩大范围。
- **validation**: `lua tests/behavior.lua` 和 `lua tests/contract.lua` 都通过。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T7: 结构与护栏验证
- **depends_on**: [T6]
- **location**: 仅验证，不新增实现位置
- **description**: 在重型回归前先做结构护栏，避免 CRAP/tooling 跑完才发现跨层漂移。
- **validation**: `lua tests/guard.lua` 与 `lua scripts/quality/arch.lua check` 都通过。
- **status**: Not Completed
- **log**:
- **files edited/created**:

### T8: 最终仓库级验收
- **depends_on**: [T7]
- **location**: `/Users/billyq/Dev/Github/Lua/monopoly/tmp/crap_report.json`
- **description**: 跑最终全量门禁，并对 6 个目标符号逐个比较 before/after。验收标准不是“整体热点列表看起来变好”，而是每个目标符号都有可量化改进。
- **validation**: 依次通过：
  - `lua tests/regression.lua`
  - `lua scripts/quality/crap.lua report --lane behavior --out tmp/crap_report.json`
  - `lua tests/tooling.lua --workers 1`
  并满足：
  - 6 个 T2 case 已从 catalog 解禁
  - 目标 6 个符号全部 `coverage > before`
  - 目标 6 个符号全部 `crap < before`
  - 不新增 0% coverage 的高位热点
- **status**: Not Completed
- **log**:
- **files edited/created**:

## Parallel Execution Groups

| Wave | Tasks | Can Start When |
|------|-------|----------------|
| 1 | T0A, T0B | Immediately |
| 2 | T1, T2, T3, T4A, T4B | After respective preflight task completes |
| 3 | T5 | T2 complete |
| 4 | T6 | T1, T3, T4A, T4B, T5 complete |
| 5 | T7 | T6 complete |
| 6 | T8 | T7 complete |

## Testing Strategy

- 局部任务必须先做本地验证，再进入共享车道；不要把首次反馈推迟到 T6。
- T2 的局部验证必须分两段：
  1. 仅改 `/Users/billyq/Dev/Github/Lua/monopoly/tests/suites/gameplay/gameplay_t2_characterization.lua`，用 ad-hoc harness 临时解除这 6 个 case 的屏蔽并跑通。
  2. 再改 `/Users/billyq/Dev/Github/Lua/monopoly/tests/catalog.lua`，最后跑 `lua tests/behavior.lua`。
- T3/T4A/T4B 每次结束都要单独重跑 CRAP 报告，对自己负责的目标符号做 before/after 比较，避免多个 agent 相互污染结论。
- T4B 的 market navigation 一律通过 `dispatch_action` 入口测，不做 local function 直测。

## Risks & Mitigations

- `/Users/billyq/Dev/Github/Lua/monopoly/src/host/eggy/paid_purchase_gateway.lua` 已有用户未提交改动；T1 必须先看当前 diff，再叠加最小修复，绝不回退。
- T2 的历史问题很可能是“断言过时”而不是“产品行为坏了”；因此允许把断言改写为现态行为检查，但不允许恢复退役 API。
- T3 与 T4 的目标都是降 CRAP，不是重写模块；如果补测已经能把 coverage 拉起来，就不继续重构。
- 若 T4A/T4B 为了可测性必须提取 helper，提取范围必须留在原层内，且 T7 作为强制边界检查，防止引入跨层依赖。

## Assumptions

- “追告警测试”解释为：把 warn 路径做成稳定断言，而不是接受日志噪音。
- “清理历史遗留”以这 3 组债务为边界，不顺手扩展到其他 legacy shim、其他 disabled 草稿或装配层重构。
- 当前 Plan Mode 下不落盘；若后续切出 Plan Mode，再把本块原样写入一个 `*-plan.md` 文件即可。
