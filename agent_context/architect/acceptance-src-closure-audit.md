# 验收 step handler → src 闭环审计（2026-05-31，HEAD 62d80ac6）

审计 `tools/acceptance/steps/*.lua` 是否真把 Gherkin feature 闭环到 `src/`，还是对 handler 内自建 fixture 假绿。

## 闭环分层

### Tier A — 经 `game_driver` 真闭环到 src 规则
`tools/acceptance/game_driver.lua` 启 `src.app.compose_game` + `src.app.game_factory` + 真 `src.rules.movement` / `src.rules.effects.mine` / `src.turn.phases.roll` / `dice_multiplier` / `event_feed`。断言打真实 game state：

`chance` · `deities` · `dice` · `economy` · `endgame` · `items` · `market` · `market_cash` · `movement` · `paid_currency`（10）

### Tier B — 真闭环到 UI/host src（渲染宿主合法打桩）
驱动真 `src.ui.coord.*` / `src.app.host_integrations.*`，仅 stub 渲染层（host = 环境不适边界）：

- `panel_interrupt`（9 src.ui，8 真调用，最强）
- `base_screen`（presenter / ui_runtime / panel_slice）
- `skin_shop` / `item_atlas`（真 `src.ui.coord.skin_panel`/`atlas` + `ui_mock` 捕获）
- `canvas_events`（截真 `ui_events.send_to_role/send_to_all` 发射）
- `leaderboard`（真 `host_integrations.leaderboard`）
- `sign_in`（真 `host_integrations.sign_in.grant/claim`，薄）

### Tier C — 假绿：handler 内平行重实现，不碰 src ⚠️（违反 ADR 0012 D4）
- **`turn_flow.lua`**（758 行，仅 require `number_utils`）：自建 `world.turn`，handler 内重实现 `_next_active_player`（轮转/淘汰）、`turn_count`，并硬编码 `AI_ITEM_PRIORITY` / `AI_TRIGGER_KNOWN` / `_ai_priority_rank`。断言打自身 fixture。真实逻辑在 `src/turn/*`、`src/rules/items/handlers.lua`、`src/config/content/items.lua`，**从不被调用**（仅 2 处 `world.driver` 蹭淘汰标记）。
- **`bankruptcy.lua`**（仅 `number_utils` + `shared`）：handler 自判破产（`if world.player.cash < 500 ... world.player.bankrupt = true`，L108–118）再断言自身判定（L57）。`src.rules` 破产逻辑未 import，不可能执行。

### Tier D — 孤儿，不跑
- **`features/game/setup.feature`**：4 场景，不在 `acceptance_features.lua` registry，无 `setup.lua`，无任何 harness 引用。

### 工具/契约类（独立类别，正常）
`quality.lua`（quality/* 4 feature）· `mutator_status.lua` · `chinese_gherkin` —— 模拟工具链契约 feature，本就不走 world-state 闭环（[[project_contract_features_gherkin_mutation_resistant]]）。

## 结构性使能者
`shared.lua` 的 `ensure_player`/`ensure_target` 只造裸 `{cash=0,...}` 表，是 Tier C 假绿的地基——fixture 本应只作种子，不得承载规则判定。

## 裁决
落 ADR 0017：收敛 turn_flow（最高优先）+ bankruptcy 到真实 driver；shared fixture 不得承载规则结论；turn_flow AI 表去重到 src 单源；setup.feature 处置。路由 specifier。

参考：[[acceptance_failure_three_layer_framing]]、[[acceptance_make_entrypoint_adr0015]]、ADR 0012 D1/D4。
