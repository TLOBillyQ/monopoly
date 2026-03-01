# M16 重复语义盘点基线（2026-03-01）

## 目录体量基线

- `src/presentation`: 97 文件 / 6009 行
- `src/game/systems`: 52 文件 / 4507 行
- 合计：149 文件 / 10516 行（约占当前代码库主要体量）

## 高频重复语义观察

- UI 同步骨架重复：
  - `PresentationPorts` 与 `TickUISync` 均包含 `is_only_turn_countdown` 与 `build_ui_env` 语义实现。
- 动画门控重复：
  - `systems` 层多文件重复 `ui_port.wait_action_anim` 判定后再 `queue_action_anim`。
- 业务流程骨架重复：
  - `items`、`land`、`chance` 内多处“构建 payload + 判断是否可播动画 + 写回 result”的样板逻辑。

## Top 体量文件（候选优先级）

- `src/presentation/state/UIModel.lua`（341）
- `src/presentation/interaction/UIIntentDispatcher.lua`（319）
- `src/presentation/api/PresentationPorts.lua`（314）
- `src/game/systems/items/ItemPostEffects.lua`（251）
- `src/game/systems/land/LandRules.lua`（238）
- `src/game/systems/items/ItemHandlers.lua`（223）
- `src/game/systems/land/landing_effects/BaseLandEffects.lua`（159）
- `src/game/systems/items/ItemDemolish.lua`（155）
- `src/game/systems/items/ItemRoadblock.lua`（144）

## 里程碑输入结论

- M17 输入：优先收敛 UI 同步骨架重复（`PresentationPorts`/`TickUISync`）。
- M18 输入：优先收敛 `systems` 层动画门控重复（统一端口访问与守护规则）。
