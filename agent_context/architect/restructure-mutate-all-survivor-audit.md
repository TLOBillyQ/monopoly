# 抽方法重构批次 —— --mutate-all 实证审计（21 manifest-bearing 文件）

来源：refactorer 路由、coder 落地的抽方法重构（commit `8430be74`，本支 cherry-pick 为 `f47b2796`，仅取本周期报告范围，排除 coder 未报告的 backlog-docs 提交 `2c99d2f4`）。

## 结论：重构 mutation-clean，无覆盖回归

对 21 个文件全部跑 `mutate.lua --mutate-all --max-workers 8`（loop-free，无挂起风险）。

- **10 个文件**：proven 清单存在、抽方法导致行漂 → `--mutate-all` 复证 **≥90%** 并刷新清单行元数据。已提交实证刷新：
  context 93.8 / facing_policy 100 / demolish 95.6 / target_query 90 / validator 99 / event_handlers 92.1 / item_slots 92.3 / choice_state 96 / item_atlas 100 / scene 90。
- **11 个文件**：`--mutate-all` 后清单 **byte-identical**，且全部 `last_mutation_status=0`（**bootstrap-only / 从未实证**）。这些 survivor 在重构**之前就未被证明覆盖**（重构未触清单尾块）→ 无法回归从未存在的覆盖。属**既有未覆盖债**，本次诚实显化，非重构引入。

判定依据：bootstrap-only 清单 = 仅结构、无 killed 记录；重构前后同为 bootstrap-only ⇒ 覆盖状态不变。

## 既有 survivor 债（bootstrap-only，按 kill 率）

| 文件 | kill 率 | survivor | 层 |
|---|---|---|---|
| ui/render/board/player_units.lua | 60.0% (36/60) | 24 | UI render |
| ui/input/dispatch/turn_action_port.lua | 66.7% (24/36) | 12 | UI dispatch |
| ui/render/board/visual_sync.lua | 72.8% (139/191) | 52 | UI render |
| ui/view/role_context.lua | 75.0% (24/32) | 8 | UI view |
| ui/render/assets.lua | 76.8% (43/56) | 13 | UI render |
| host/synthetic_actor_registry.lua | 78.2% (86/110) | 24 | host |
| ui/render/building_effects.lua | 78.7% (37/47) | 10 | UI render |
| ui/view/choice_builder.lua | 78.9% (30/38) | 8 | UI view |
| rules/choice_handlers/item.lua | 79.4% (150/189) | 39 | rules |
| app/profile_bootstrap.lua | 82.8% (111/134) | 23 | app |
| app/testing/test_profiles.lua | 87.2% (82/94) | 12 | app/test |

## 路由判断

- 主体在 UI render/view 层（`.luacov` 聚合排除该层，CRAP 另算覆盖，历史按 accepted residue 处理，见 reference_luacov_excludes_ui_crap_separate_coverage）。本属**多周期覆盖闭合 backlog**，不是本次「结构清理」handoff 的回归，不在本周期向 coder 派发整批。
- 值得后续按 src 层（rules/choice_handlers/item.lua 39、host/synthetic_actor_registry 24）优先 routing 给 coder 写 busted spec（survivor closure 必须 busted，见 feedback_mutation_survivor_routing）；UI render 层先判 accepted residue vs 真缺口再定。

## DRY（dry4lua，restructured files）

全部 benign，无 actionable：
- 1.00 visual_sync._resolve_board ↔ facing_policy._player_move_dir：跨层（ui/render↔rules/board）平凡 `x and x.y or nil` 访问器，合并会破坏层边界。
- 0.86/0.84 event_handlers：具名函数与其内嵌闭包行号重叠 = 嵌套伪报。
- 0.83 item.lua _decorate_repeatable_followup ↔ _decorate_passive_followup：refactorer 刚抽出的两个兄弟 helper，共享 3 行 meta-stamp 但故意分叉（passive 设 passive_origin）；边际，churn bootstrap-only 文件不值。

## 最终验证序列

mutation（本审计）→ DRY（benign）→ soft Gherkin（items.feature `--level soft`：0 survived/0 errors，与历史一致）。verify --smoke 6/6、acceptance 546 ok、property 70 ok。
