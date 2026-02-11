# 载具总开关（默认关闭）全链路硬禁用

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 `.agents/PLANS.md`，实施与停顿时都要保持本文档自洽、可接续、可复现。

## 目的 / 全局视角

当前版本里，载具会影响黑市购买、机会卡奖励、掷骰数量、地雷/导弹免疫、移动动画与编辑器事件。为提升稳定性，本次改动引入统一开关 `vehicle_enabled`，默认关闭，并在关闭时硬禁用所有载具链路。改完后，用户新开局将看不到任何载具入口，也不会触发载具规则或表现，哪怕历史状态里残留 `seat_id` 也不会产生效果。

## 进度

- [x] (2026-02-11 09:20Z) 清空并重写 `.agents/PLAN_CURRENT.md`，建立本任务活文档
- [x] (2026-02-11 09:24Z) 新增 `src/game/vehicle/VehicleFeature.lua`，封装载具开关与判定函数
- [x] (2026-02-11 09:30Z) 修改规则层：`GameState` 与 `TurnMove`，关闭时忽略 `seat_id`
- [x] (2026-02-11 09:34Z) 修改入口层：`Market`、`Landing`、`ChanceRegistry`，关闭时屏蔽载具来源
- [x] (2026-02-11 09:38Z) 修改表现层：`MoveAnim`、`BoardView`、`RuntimeContext`，关闭时短路载具行为
- [x] (2026-02-11 09:45Z) 增补回归测试并兼容开启态旧行为
- [x] (2026-02-11 09:47Z) 运行 `lua .agents/tests/regression.lua`，输出 `All regression checks passed (111)`

## 意外与发现

- 观察：关闭态下，黑市若仍有道具可买，面板会继续正常展示；仅载具条目会被过滤，不影响黑市主流程。
  证据：新增用例 `_test_market_vehicle_hidden_when_feature_disabled` 与 `_test_buy_vehicle_rejected_when_feature_disabled` 通过。

- 观察：旧有载具相关回归在默认关闭后会失效，必须在测试内显式临时打开 `gameplay_rules.vehicle_enabled` 才能验证“开启态”兼容。
  证据：`.agents/tests/suites/gameplay.lua` 与 `.agents/tests/suites/ui.lua` 中载具用例已补丁开启并通过全量回归。

## 决策日志

- 决策：载具开关放在 `Config/GameplayRules.lua`，键名为 `vehicle_enabled`，默认 `false`。
  理由：项目已有通用玩法开关配置，复用成本最低，读取路径一致。
  日期/作者：2026-02-11 / Codex

- 决策：不改 `Config/Generated/*` 的静态表，全部采用运行时策略屏蔽。
  理由：减少配置回归风险，避免对策划表造成额外维护成本。
  日期/作者：2026-02-11 / Codex

- 决策：关闭态不做存档迁移，采用“残留 `seat_id` 统一按无载具处理”。
  理由：满足当前需求且实现最稳，避免引入迁移脚本复杂度。
  日期/作者：2026-02-11 / Codex

## 结果与复盘

本次已完成载具总开关的全链路硬禁用落地，且保持开启态兼容。核心结果如下：

1. 新增 `vehicle_enabled=false` 默认配置与统一策略模块 `VehicleFeature`，规则/入口/表现统一走该模块判定。
2. 关闭态下，载具获取来源（黑市、机会卡）已屏蔽，规则效果（掷骰、免疫、move_anim 载具字段）已失效，表现与运行时 ECA 载具事件已短路。
3. 回归验证通过：`lua .agents/tests/regression.lua` 输出 `All regression checks passed (111)`。

对照目标，本计划全部达成。当前剩余风险仅为“运行时热切换”未实现，这与需求锁定一致（仅开局读取）。

## 背景与导读

核心链路分三层。规则层主要在 `src/game/game/GameState.lua` 与 `src/game/turn/TurnMove.lua`，决定 `seat_id` 如何影响骰子、免疫和移动动画数据。入口层主要在 `src/game/market/Market.lua`、`src/game/land/Landing.lua`、`src/game/chance/ChanceRegistry.lua`，负责载具的购买和抽取来源。表现层主要在 `src/ui/MoveAnim.lua`、`src/ui/BoardView.lua`、`src/core/RuntimeContext.lua`，负责载具动画、位置同步与编辑器 ECA 事件桥接。

本计划新增统一策略模块 `src/game/vehicle/VehicleFeature.lua`，让以上各层都通过同一接口读取载具开关，避免散落的布尔判断失控。

## 工作计划

先新增 `VehicleFeature` 提供 `is_enabled`、`resolve_seat_id`、`is_vehicle_market_entry`、`is_vehicle_chance_card`。随后改规则层，让 `GameState` 与 `TurnMove` 在关闭态不再把 `seat_id` 当作有效载具输入。再改入口层，确保黑市与机会卡不再生成载具来源，同时给 `set_vehicle` 处理器加兜底。最后改表现层，把载具动画和编辑器载具事件统一短路。

测试分两组：一组新增“关闭态”用例，证明硬禁用生效；另一组修补已有载具测试，在测试内临时打开开关，保证开启态行为不回退。全部完成后跑全量回归。

## 具体步骤

在仓库根目录按顺序执行：

1. 改配置与新增模块。
2. 改规则层、入口层、表现层。
3. 修改 `.agents/tests/suites/{market,chance,gameplay,ui}.lua`。
4. 运行：

    lua .agents/tests/regression.lua

预期输出末尾包含：

    All regression checks passed (...)

## 验证与验收

验收分关闭态与开启态。

关闭态（默认）下，黑市不出现载具商品，机会卡不会产出载具效果，掷骰与免疫不再受载具影响，移动与位置同步不再走载具 helper，运行时桥接不再转发载具 ECA 事件。

开启态（测试补丁打开）下，已有载具相关回归继续通过，证明兼容旧行为。

最终必须以 `lua .agents/tests/regression.lua` 全量通过作为交付门槛。

## 可重复性与恢复

本次变更不涉及数据迁移。若需要回滚，可按模块逆序撤销：先撤测试变更，再撤表现层、入口层、规则层，最后移除 `VehicleFeature` 与 `vehicle_enabled` 配置。每一步都可单独执行并重新跑回归确认。

## 产物与备注

实际产物：

- `Config/GameplayRules.lua`
- `src/game/vehicle/VehicleFeature.lua`
- `src/game/game/GameState.lua`
- `src/game/turn/TurnMove.lua`
- `src/game/market/Market.lua`
- `src/game/land/Landing.lua`
- `src/game/chance/ChanceRegistry.lua`
- `src/ui/MoveAnim.lua`
- `src/ui/BoardView.lua`
- `src/core/RuntimeContext.lua`
- `.agents/tests/suites/market.lua`
- `.agents/tests/suites/chance.lua`
- `.agents/tests/suites/gameplay.lua`
- `.agents/tests/suites/ui.lua`

## 接口与依赖

新增模块接口：

- `vehicle_feature.is_enabled() -> boolean`
- `vehicle_feature.resolve_seat_id(seat_id) -> number|nil`
- `vehicle_feature.is_vehicle_market_entry(entry) -> boolean`
- `vehicle_feature.is_vehicle_chance_card(card) -> boolean`

新增配置：

- `Config.GameplayRules.vehicle_enabled`（默认 `false`）

改动依赖：

- 黑市/机会卡/移动动画/运行时桥接必须统一使用 `vehicle_feature`，不直接散写 `gameplay_rules.vehicle_enabled`。

(2026-02-11) 更新说明：初始化计划文档并锁定实现范围、默认值与验收口径。
(2026-02-11) 更新说明：完成全链路实现与回归验证，补全进度、发现与复盘，确保可追溯交接。
