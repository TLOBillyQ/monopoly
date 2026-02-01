# 里程碑 2：使用 Eggy 事件/触发器替代自建事件（子计划）


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 `.agent/PLANS.md` 的全部要求，并作为总计划 `pilots/15_monopoly_solid_refactor_plan.md` 的子计划，同时遵循 `.github/docs/eggy/eggy_lua_agent_memory.md` 的 Eggy 规则。


## 目的 / 全局视角


本里程碑将领域服务中的日志与 UI 副作用迁移到 Eggy 的自定义事件与触发器系统，删除自建事件总线与处理器实现。完成后，领域服务只负责计算并调用 `LuaAPI.global_send_custom_event` 报告发生了什么；日志与 UI 弹窗通过 `LuaAPI.global_register_custom_event` 注册的回调处理。这样做避免引擎运行时坑，并符合 Eggy 的 API 使用规范。

可观察结果：
1) 关键日志仍能输出（移动、租金、黑市购买等）；
2) 领域服务里不再直接调用 `logger.event`；
3) 代码库中不再存在自建事件总线实现（如 `GameEvents`）。


## 进度


- [x] (2026-01-30 17:35Z) 定义事件名称与注册入口（使用 LuaAPI 事件系统）
- [x] (2026-01-30 17:35Z) 迁移 `MovementService`、`LandActions`、`MarketService`、`Chance` 为 Eggy 事件派发
- [x] (2026-01-30 17:35Z) 删除自建事件实现并完成回归验证


## 意外与发现


暂无。若发现 Eggy 事件回调的 `data` 需要使用字符串索引（如 `data["1"]`），必须记录并在处理器里做兼容。


## 决策日志


- 决策：完全删除自建事件总线与处理器，改用 `LuaAPI.global_register_custom_event` / `LuaAPI.global_send_custom_event`。
  理由：Eggy 运行时规定事件通信首选该机制，避免隐藏兼容风险。
  日期/作者：2026-01-30 / Codex

- 决策：事件名称集中定义在 `Globals/MonopolyEvents.lua` 或 `Globals/Macro.lua`。
  理由：避免散落硬编码，且不引入新的抽象层目录。
  日期/作者：2026-01-30 / Codex

- 决策：事件名称统一加 `monopoly.` 前缀，常量表落在 `Globals/MonopolyEvents.lua`。
  理由：降低跨玩法事件命名冲突，并保持集中管理。
  日期/作者：2026-01-30 / Codex


## 结果与复盘


已完成事件迁移与自建事件总线删除；领域服务改为 `LuaAPI.global_send_custom_event` 派发，自定义事件回调负责日志与弹窗。新增事件常量表与事件名测试，`deps_check` 与回归测试通过。后续如需新增事件，按常量表扩展并在注册入口补处理即可。


## 背景与导读


当前日志输出散布在多个领域服务内，例如：
`Manager/MovementManager/Movement/MovementService.lua` 使用 `logger.event` 记录移动、路障、经过黑市。
`Manager/LandManager/Land/LandActions.lua` 记录租金、税务、强征等。
`Manager/MarketManager/Market/MarketService.lua` 记录购买。
`Manager/GameManager/Chance.lua` 记录机会卡效果。

根据 `.github/docs/eggy/eggy_lua_agent_memory.md`，应该使用 Eggy 的事件系统（`LuaAPI.global_register_custom_event` / `LuaAPI.global_send_custom_event`）进行通信，且所有 API 调用必须使用点号。UI 初始化需要在 GAME_INIT 之后，事件注册与派发应在该时机之后进行。


## 工作计划


先定义事件名称并建立注册入口，再逐步迁移日志。事件命名保持直观，保证能覆盖当前日志语义。领域服务在关键点调用 `LuaAPI.global_send_custom_event(event_name, payload)`。事件处理在启动入口或 `Layer` 初始化后注册（依据计划 16 的落位），并在回调里执行 `logger.event` 与 `ui_port` 弹窗。迁移过程中允许短期内“事件 + 旧日志”并存，但最终删除旧日志调用。

建议事件名称（最终以实现为准）：
- `monopoly.movement.moved`
- `monopoly.movement.passed_start`
- `monopoly.movement.roadblock_hit`
- `monopoly.movement.market_interrupt`
- `monopoly.movement.steal_interrupt`
- `monopoly.land.rent_paid`
- `monopoly.land.rent_bankrupt`
- `monopoly.land.tax_paid`
- `monopoly.market.bought_item`
- `monopoly.market.bought_vehicle`
- `monopoly.market.buy_failed`
- `monopoly.chance.applied`


## 具体步骤


1) 定义事件名称。
   - 在 `Globals/MonopolyEvents.lua` 新增事件常量表（或在 `Globals/Macro.lua` 中扩展）。
   - 事件名称仅用于 `LuaAPI.global_register_custom_event` 与 `LuaAPI.global_send_custom_event`。

2) 建立事件注册入口。
   - 在计划 16 约定的入口位置（如 `Manager/GameManager/Entry.lua` 或 `Manager/TurnManager/GUI/Layer.lua` 的初始化逻辑）注册事件回调。
   - 使用 `LuaAPI.global_register_custom_event` 逐一注册事件，并在回调内调用 `logger.event` 或 `ui_port`。
   - 所有 API 调用使用点号（例如 `LuaAPI.global_register_custom_event`），不使用冒号。

3) 迁移日志调用为 Eggy 事件派发。
   - `MovementService`：把 `logger.event` 改为 `LuaAPI.global_send_custom_event(MONOPOLY_EVENT.movement_moved, payload)` 等。
   - `LandActions`：把租金、税务、强征、破产相关日志迁移为事件。
   - `MarketService`：把购买成功与失败弹窗改为事件（回调里处理 UI）。
   - `Chance`：把各类效果日志改为事件。

4) 删除自建事件实现。
   - 移除 `Library/Monopoly/GameEvents.lua`、`Manager/System/EventHandlers.lua`（若存在）。
   - 清理 `CompositionRoot` 中 `game.events` 注入以及所有 `game.events:emit` 调用。

5) 新增测试（不依赖引擎）。
   - 新建 `.github/tests/eggy_event_names_test.lua`，验证事件常量表存在且包含关键键。


## 验证与验收


运行回归测试：
    lua .github/tests/deps_check.lua
    lua .github/tests/regression.lua

运行事件名称测试：
    lua .github/tests/eggy_event_names_test.lua
    ok - eggy event names

人工观察：运行游戏后仍能看到移动与租金日志，且输出内容与原先一致或语义等价。


## 可重复性与恢复


迁移以事件替换日志为主，可分阶段执行。若事件回调没有覆盖日志，可临时保留旧日志并记录在“意外与发现”。回退时恢复对应文件即可。


## 产物与备注


预期新增或改动文件：
`Globals/MonopolyEvents.lua`（或 `Globals/Macro.lua`）
`Manager/MovementManager/Movement/MovementService.lua`
`Manager/LandManager/Land/LandActions.lua`
`Manager/MarketManager/Market/MarketService.lua`
`Manager/GameManager/Chance.lua`
`.github/tests/eggy_event_names_test.lua`

预期移除文件（若存在）：
`Library/Monopoly/GameEvents.lua`
`Manager/System/EventHandlers.lua`

测试输出示例：
    lua .github/tests/eggy_event_names_test.lua
    ok - eggy event names


## 接口与依赖


事件依赖 Eggy API，必须使用 LuaAPI 的自定义事件系统：
    LuaAPI.global_register_custom_event(name, fn)
    LuaAPI.global_send_custom_event(name, payload)
    LuaAPI.global_unregister_custom_event(id)

如需触发器监听引擎事件，使用：
    LuaAPI.global_register_trigger_event({ EVENT.XXX }, fn)

事件注册与派发必须使用点号调用方式，符合 Eggy 规范。


改动记录：本计划重写为 Eggy 事件/触发器版本，删除自建事件总线方案。

改动记录：更新进度为完成状态，补充事件命名决策与实施结果（含测试）。
