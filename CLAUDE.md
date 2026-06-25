# 导读

**蛋仔派对大富翁** — Lua 5.4，清洁架构七层 + foundation，Eggy 宿主。

Agent 路由：`.agents/README.md` | 人类索引：`docs/README.md`

## 常驻规则

- 命名 `snake_case`，类名 `CamelCase`。
- `src/` 禁用 `tonumber` / `type == "number"`，用 `NumberUtils`（`src.foundation.number`）。
- Eggy `Fixed` 参数用浮点（`30.0`），详见 `docs/reference/eggy/eggy-types.md`。
- Eggy 沙盒 `math` 无 `maxinteger`/`mininteger`/`huge`，用 `math.maxval`/`math.minval`。
- 新 swarmforge worktree 第一次进入要确认 `swarmforge/tools.lock` 存在；质量工具由 wrapper 按需 bootstrap 到 `.swarmforge/tools/`。

## 仓库结构

- `src/`：运行时代码，按七层 + foundation 边界维护。
- `spec/` / `features/`：busted 与 Gherkin 验收测试。
- `tools/quality/`：质量车道与分析工具；改这里必须跑完整验证。
- `.agents/` / `docs/`：agent 路由与工程文档索引。

## 边界

- `tools/acceptance/generated/*` 是 gitignored 生成物（ADR 0015）；不手改、不提交，跑 `make acceptance` 从 feature 重生成。新 feature 入验收套件要在 `tools/acceptance/acceptance_features.lua` 加一行。
- `EggyAPI.lua` 是宿主 API 参考面，按第三方边界处理。
- 大型规则 spec 由对应 `src/rules` 行为覆盖；改规则先补或调整 behavior spec。

## 热点边界

- 热点 `EggyAPI.lua`：宿主 API 参考面；验证 `make verify`。
- 热点 `tools/acceptance/generated/skin_shop_acceptance_spec.lua`：生成物；验证 `make verify`。
- 热点 `tools/acceptance/generated/item_atlas_acceptance_spec.lua`：生成物；验证 `make verify`。
- 热点 `tools/acceptance/generated/items_acceptance_spec.lua`：生成物；验证 `make verify`。
- 热点 `spec/behavior/rules/item_spec.lua`：规则行为规约；验证 `make test` 或 `busted --run behavior`。
- 热点 `docs/reference/eggy/api/09_events.md`：第三方参考；验证 `make verify`。
- 热点 `tools/acceptance/generated/chance_acceptance_spec.lua`：生成物；验证 `make verify`。
- 热点 `tools/acceptance/generated/turn_flow_acceptance_spec.lua`：生成物；验证 `make verify`。
- 热点 `spec/behavior/ui/gameplay_t6_hotspot_spec.lua`：UI 行为规约；验证 `make test` 或 `busted --run behavior`。
- 热点 `tools/ops/update_api.lua`：文档同步工具；验证 `busted --run tooling`（contract 在 `script_tools_contract.lua`）。
- 热点 `meta/luals_host.lua`：LuaLS 宿主声明；验证 `make verify`。
- 热点 `tools/acceptance/generated/economy_acceptance_spec.lua`：生成物；验证 `make verify`。
- 热点 `spec/behavior/ui/interaction_spec.lua`：UI 行为规约；验证 `make test` 或 `busted --run behavior`。
- 热点 `tools/acceptance/generated/movement_acceptance_spec.lua`：生成物；验证 `make verify`。
- 热点 `tools/shared/lib/common.lua`：工具共享库；验证 `busted --run tooling`。
- 热点 `spec/behavior/ui/action_status/status3d_spec.lua`：UI 行为规约；验证 `make test` 或 `busted --run behavior`。
- 热点 `spec/support/tooling_suites/architecture/script_tools_contract.lua`：工具契约；验证 `busted --run tooling`。
- 热点 `spec/behavior/ui/action_status/item_slots_spec.lua`：UI 行为规约；验证 `make test` 或 `busted --run behavior`。
- 热点 `spec/behavior/ui/model_dispatch_spec.lua`：UI 行为规约；验证 `make test` 或 `busted --run behavior`。
- 热点 `tools/acceptance/steps/items.lua`：验收 step 源；验证 `lua tools/acceptance/run_acceptance.lua`。
- 热点 `spec/behavior/ui/action_anim_effect_routes_spec.lua`：UI 行为规约；验证 `make test` 或 `busted --run behavior`。
- 热点 `spec/support/scenario_suites/turn_flow/cases.lua`：场景数据；验证 `make test` 或 `busted --run behavior`。
- 热点 `spec/behavior/rules/movement_spec.lua`：规则行为规约；验证 `make test` 或 `busted --run behavior`。
- 热点 `tools/acceptance/generated/chinese_gherkin_acceptance_spec.lua`：生成物；验证 `make verify`。
- 热点 `spec/behavior/ui/view_command_mutation_pin_spec.lua`：UI mutation pin；验证 `make test` 或 `busted --run behavior`。
- 热点 `tools/acceptance/generated/endgame_acceptance_spec.lua`：生成物；验证 `make verify`。
- 热点 `spec/behavior/ui/board_sync_spec.lua`：UI 行为规约；验证 `make test` 或 `busted --run behavior`。
- 热点 `spec/behavior/ui/skin_panel_spec.lua`：UI 行为规约；验证 `make test` 或 `busted --run behavior`。
- 热点 `spec/support/scenario_suites/turn_flow/loop_policies.lua`：场景策略；验证 `make test` 或 `busted --run behavior`。
- 热点 `tools/acceptance/steps/chance.lua`：验收 step 源；验证 `lua tools/acceptance/run_acceptance.lua`。
- 热点 `spec/behavior/ui/action_anim_overlay_units_spec.lua`：UI 行为规约；验证 `make test` 或 `busted --run behavior`。

## 验证

迭代默认 `verify --smoke`（~8s，覆盖 src 全部七层 + foundation 行为 spec）；handoff / PR / commit 前跑 `verify`（~30s，含 crap + coverage）。`tools/{quality,acceptance,shared,ops}/**` 改动另外跑 `busted --run tooling` 单测工具模块（不在 verify 管线内）。profile 见 `.agents/skills/verify/SKILL.md`。

验收套件用 `make acceptance`（先从 feature 重生成 gitignored 生成物再跑），**不要**裸跑 `busted --run acceptance`——fresh checkout 生成物为空会假绿（ADR 0015）。
