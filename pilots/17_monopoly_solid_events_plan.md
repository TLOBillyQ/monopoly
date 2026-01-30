# 里程碑 2：领域服务事件化（子计划）


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 `.agent/PLANS.md` 的全部要求，并作为总计划 `pilots/15_monopoly_solid_refactor_plan.md` 的子计划。


## 目的 / 全局视角


本里程碑把领域服务中的日志与 UI 副作用迁移到统一的事件处理层，降低 `MovementService`、`LandActions`、`MarketService`、`Chance` 的耦合度。完成后，领域服务只负责计算和返回结果，并通过事件总线报告发生了什么；日志与 UI 弹窗在一个集中模块中完成。这样做可以让领域逻辑更可测试，也能更容易替换 UI 表现层。

可观察结果：
1) 关键日志仍能输出（移动、租金、黑市购买等）；
2) 领域服务里不再直接调用 `logger.event`；
3) 新增事件总线测试通过。


## 进度


- [ ] (2026-01-30 00:00Z) 新增事件总线与事件处理器
- [ ] (2026-01-30 00:00Z) 迁移 `MovementService`、`LandActions`、`MarketService`、`Chance` 的日志为事件
- [ ] (2026-01-30 00:00Z) 新增事件测试并完成回归验证


## 意外与发现


暂无。若发现事件无法覆盖现有日志信息或 UI 行为，则需要记录并给出替代方案。


## 决策日志


- 决策：事件总线作为 `game.events` 注入，由运行时或组合根创建。
  理由：领域逻辑可直接使用 `game.events`，避免全局单例。
  日期/作者：2026-01-30 / Codex

- 决策：日志与 UI 先集中在 `Manager/System/EventHandlers.lua`，后续再拆分细化。
  理由：迁移成本最低，可逐步演进。
  日期/作者：2026-01-30 / Codex


## 结果与复盘


尚未实施。


## 背景与导读


当前日志输出散布在多个领域服务内，例如：
`Manager/MovementManager/Movement/MovementService.lua` 使用 `logger.event` 记录移动、路障、经过黑市。
`Manager/LandManager/Land/LandActions.lua` 记录租金、税务、强征等。
`Manager/MarketManager/Market/MarketService.lua` 记录购买。
`Manager/GameManager/Chance.lua` 记录机会卡效果。

这导致领域逻辑与日志/UI 绑定紧密。此次改造引入统一事件总线 `Library/Monopoly/GameEvents.lua` 和处理器 `Manager/System/EventHandlers.lua`。


## 工作计划


先新增事件总线与处理器，再逐步迁移日志。事件命名保持直观，保证能覆盖当前日志的语义。领域服务在关键点调用 `game.events:emit(kind, payload)`。事件处理器订阅这些事件并调用 `logger.event` 或 `ui_port`。在迁移过程中，允许短期内“事件 + 旧日志”并存，但最终要删除旧日志调用，避免重复。

建议事件列表（可按实现调整，但需在文档内明确）：
- `movement.moved`：玩家移动结束（payload 包含 player、from、to、steps、landing_tile）。
- `movement.passed_start`：经过起点（payload 包含 player、count、bonus）。
- `movement.roadblock_hit`：触发路障（payload 包含 player、tile）。
- `movement.market_interrupt`：经过黑市中断（payload 包含 player、remaining_steps）。
- `land.rent_paid`：支付租金（payload 包含 payer、owner、amount、tile）。
- `land.tax_paid`：支付税款（payload 包含 player、amount）。
- `land.tile_reset`：地块被清空（payload 包含 tile、reason）。
- `market.bought`：购买物品/座驾（payload 包含 player、entry、price、currency）。
- `chance.applied`：机会卡效果执行（payload 包含 player、card、effect）。


## 具体步骤


1) 新增事件总线模块。
   - 新建 `Library/Monopoly/GameEvents.lua`，提供 `new/on/emit`。
   - 在 `Manager/GameManager/CompositionRoot.lua` 中创建 `game.events` 并注入。

2) 新增事件处理器。
   - 新建 `Manager/System/EventHandlers.lua`，提供 `install(game, logger, ui_port)`。
   - 在 `Manager/System/Runtime.lua` 或 `RuntimeInit` 中调用 `EventHandlers.install`，保证游戏启动时订阅。

3) 迁移日志调用为事件。
   - `MovementService`：把 `logger.event` 改为 `game.events:emit("movement.*", payload)`。
   - `LandActions`：把租金、税务、强征、破产相关日志迁移为事件。
   - `MarketService`：把购买成功与失败弹窗改为事件（弹窗可由处理器调用 UI）。
   - `Chance`：把各类效果日志改为事件。

4) 移除旧日志调用，确保仅由事件处理器输出。

5) 新增测试。
   - 新建 `tests/game_events_test.lua`，构造一个简单 `GameEvents` 实例，注册回调并验证 `emit` 可触发。


## 验证与验收


运行回归测试：
    lua tests/deps_check.lua
    lua tests/regression.lua

运行新增事件测试：
    lua tests/game_events_test.lua
    ok - game events

人工观察：运行游戏后仍能看到移动与租金日志，且输出内容与原先一致或语义等价。


## 可重复性与恢复


迁移过程以事件替换日志为主，可分阶段执行。若事件处理器无法覆盖日志，可临时保留旧日志，并在“意外与发现”记录。回退时恢复对应文件即可。


## 产物与备注


预期新增或改动文件：
`Library/Monopoly/GameEvents.lua`
`Manager/System/EventHandlers.lua`
`Manager/GameManager/CompositionRoot.lua`
`Manager/MovementManager/Movement/MovementService.lua`
`Manager/LandManager/Land/LandActions.lua`
`Manager/MarketManager/Market/MarketService.lua`
`Manager/GameManager/Chance.lua`
`tests/game_events_test.lua`

测试输出示例：
    lua tests/game_events_test.lua
    ok - game events


## 接口与依赖


在 `Library/Monopoly/GameEvents.lua` 中定义：
    local GameEvents = {}
    function GameEvents.new() end
    function GameEvents:on(kind, fn) end
    function GameEvents:emit(kind, payload) end

在 `Manager/System/EventHandlers.lua` 中定义：
    local EventHandlers = {}
    function EventHandlers.install(game, logger, ui_port) end

事件处理器必须能够访问 `logger`，并在 `ui_port` 为 nil 时安全降级。


改动记录：本计划为首次版本，尚未实施。
