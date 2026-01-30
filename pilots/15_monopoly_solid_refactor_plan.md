# Monopoly SOLID 改造可执行计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 `.agent/PLANS.md` 的全部要求，并以其中的格式与约束为准。


## 目的 / 全局视角


本计划的目标是把 monopoly 的运行时、UI 交互、领域逻辑进一步解耦，使新增道具、机会卡和选择类型时更少修改核心代码，并让领域逻辑更易测试。完成后，开发者可以通过注册新处理器来扩展玩法，而不需要直接改动 `ItemExecutor`、`Chance`、`ChoiceService` 这些核心文件。同时，运行时初始化与帧循环被拆分成更小的模块，方便替换和测试。可观察结果是：测试用例通过，运行时仍能初始化并进入回合循环，新增的注册入口可用（例如在测试里注册一个新道具并被执行）。


## 进度


- [x] (2026-01-30 08:56Z) 里程碑 1：拆分 Runtime 与 UI 端口接口层，保留现有行为（见子计划 `pilots/16_monopoly_solid_runtime_plan.md`）
- [x] (2026-01-30 09:09Z) 里程碑 2：领域服务事件化，日志与 UI 副作用迁移到事件处理器（见子计划 `pilots/17_monopoly_solid_events_plan.md`）
- [ ] (2026-01-30 00:00Z) 里程碑 3：道具 / 机会卡 / 选择处理注册化，新增最小测试（见子计划 `pilots/18_monopoly_solid_registry_plan.md`）
- [ ] (2026-01-30 00:00Z) 完成回归测试与验收脚本整理
- [ ] (2026-01-30 00:00Z) 全局格式统一：关键 Lua 类改用 `ClassUtils.Class`，补充精简 EmmyLua 注释（见子计划 `pilots/19_monopoly_classutils_emmylua_plan.md`）


## 意外与发现


- 观察：回归测试中加载 `Manager.TurnManager.GUI.Layer` 触发 `Globals.Macro` 依赖，导致本地 Lua 缺失 `math.Vector3` 报错。
  证据：`lua tests/regression.lua` 报错 `Globals/Macro.lua:1: attempt to call field 'Vector3' (a nil value)`。


## 决策日志


- 决策：将 Runtime 初始化与帧循环拆成独立模块，并保留 `Manager/System/Runtime.lua` 作为入口。
  理由：降低风险，避免一次性重写启动流程，同时保证调用方不需要改动 `require("Manager.System.Runtime").install()`。
  日期/作者：2026-01-30 / Codex

- 决策：引入“事件处理器”作为领域逻辑与日志/UI 的隔离层，而不是把日志完全分散到各服务。
  理由：事件层可以集中维护副作用，便于测试与替换，也便于逐步迁移。
  日期/作者：2026-01-30 / Codex

- 决策：采用“注册表”方式改造道具、机会卡、选择处理器。
  理由：扩展时只需新增注册文件，减少修改核心模块，符合开闭原则。
  日期/作者：2026-01-30 / Codex

- 决策：增加全局格式统一任务，要求 Lua 类统一使用 `ClassUtils.Class` 封装，并为关键类补充精简 EmmyLua 注释。
  理由：统一类构造风格，提升可读性与编辑器提示，便于后续维护。
  日期/作者：2026-01-30 / Codex

- 决策：适配层在 `Layer.lua` 内对动画模块使用延迟 `require`。
  理由：保证回归测试可在缺少引擎数学类型的 Lua 环境中运行。
  日期/作者：2026-01-30 / Codex


## 结果与复盘


已完成里程碑 1/2（入口迁移、适配层合并、事件总线与日志迁移）。剩余里程碑 3 与全局格式统一待执行，整体目标尚未达成。


## 背景与导读


本仓库是一个 Lua 大富翁项目。入口是 `main.lua` 和 `init.lua`，由 `Manager/System/Runtime.lua` 完成运行时安装。`Manager/GameManager` 提供游戏核心模型和流程，`Manager/TurnManager` 控制回合状态机，`Components/` 是基础数据结构。UI 与引擎事件通过 `UIManager`、`LuaAPI`、`GameAPI` 对接。当前实现里，`Runtime` 同时做初始化、UI 绑定与帧循环；`Game` 会直接触发 UI 端口；`MovementService`、`MarketService`、`LandActions` 等服务直接记录日志并执行 UI/动画副作用；`ItemExecutor`、`Chance`、`ChoiceService` 通过硬编码表处理扩展。

术语解释：
“UI 端口”是指 `Game.ui_port` 这类由运行时注入的对象，它提供若干 UI 行为（如弹窗、动画触发）。
“事件处理器”是指集中接收领域事件并执行日志/UI/动画的模块。
“注册表”是一个保存处理器映射的表，提供 `register/get/list` 等方法，用于扩展道具、机会卡和选择类型。

相关文件（全部为仓库相对路径）：
`Manager/System/Runtime.lua`
`Manager/System/AdapterLayer.lua`
`Manager/GameManager/Game.lua`
`Manager/GameManager/CompositionRoot.lua`
`Manager/TurnManager/Turn/TurnManager.lua`
`Manager/TurnManager/Turn/TurnMove.lua`
`Manager/MovementManager/Movement/MovementService.lua`
`Manager/MarketManager/Market/MarketService.lua`
`Manager/LandManager/Land/LandActions.lua`
`Manager/ItemManager/Item/ItemExecutor.lua`
`Manager/GameManager/Chance.lua`
`Manager/ChoiceManager/Choice/ChoiceService.lua`
`Library/Monopoly/IntentDispatcher.lua`

本计划只覆盖 monopoly 自身代码，不修改 `SecretOfEscaper/` 目录。


## 工作计划


里程碑 1、2、3 已拆分为独立子计划。执行时以本文件为总计划，按以下子计划逐一推进：
`pilots/16_monopoly_solid_runtime_plan.md`
`pilots/17_monopoly_solid_events_plan.md`
`pilots/18_monopoly_solid_registry_plan.md`
`pilots/19_monopoly_classutils_emmylua_plan.md`

本总计划只保留全局目标、统一验证与验收要求，以及跨里程碑的注意事项。每个子计划都是独立的可执行计划，包含完整步骤、验证、接口与回滚策略。

新增全局格式统一任务：要求将关键 Lua 类统一改为 `ClassUtils.Class` 的封装风格，并补充精简 EmmyLua 风格注释。具体范围、步骤与验证方式见子计划 `pilots/19_monopoly_classutils_emmylua_plan.md`。该任务需要兼容既有行为，避免改变对外接口。

每个里程碑都要保持可编译、可运行、可回归测试。若迁移中需要并行旧逻辑与新逻辑，必须在计划内说明切换条件与删除旧逻辑的时机。


## 具体步骤


步骤必须在工作目录 `C:\Users\Lzx_8\Desktop\eggitor\1_开发中\大富翁\monopoly` 执行。

里程碑 1 操作要点：
在 `Manager/System/` 新增文件并把 `Runtime.lua` 的逻辑拆出。新增 `Manager/System/UIPort.lua`，提供诸如 `push_popup`、`on_tile_owner_changed`、`on_tile_upgraded`、`wait_move_anim` 等方法的默认空实现或断言，并在 `AdapterLayer.attach` 或 `MainController.bind` 时注入到 `layer.ui` 或 `game.ui_port`。更新 `Runtime.lua` 只保留装配顺序，不改对外入口。

里程碑 2 操作要点：
新增 `Library/Monopoly/GameEvents.lua`（或同名模块）提供 `emit/on` 能力，并在 `CompositionRoot.assemble` 中创建并注入 `game.events`。逐步改造 `MovementService`、`LandActions`、`MarketService`、`Chance` 中的 `logger.event` 与 UI 调用，改为通过 `game.events.emit` 抛出事件，再由 `Manager/System/EventHandlers.lua` 统一处理并写日志或触发 UI。`TurnMove`、`IntentDispatcher` 若需要也改成只触发事件而非直接写 UI。

里程碑 3 操作要点：
新增注册表模块并迁移现有处理函数。`ItemExecutor` 从 `ItemRegistry.get(item_id)` 获取处理器。`Chance` 从 `ChanceRegistry.get(effect)` 获取处理器。`ChoiceService.setup` 只负责装配默认注册表，不再硬编码 handler 表。新增 `tests/` 下的 Lua 测试文件，模拟注册一个虚拟道具或机会卡，并断言执行路径被调用。


## 验证与验收


基础回归：运行以下命令，预期全部通过，无新增报错。
    lua tests/deps_check.lua
    lua tests/regression.lua

新增注册与事件测试：运行新建的测试脚本（按你创建的文件名），预期输出包含 “ok” 或断言通过。
    lua tests/solid_event_registry_test.lua

人工验证：启动流程不变，`Runtime.install()` 仍能创建游戏并开始回合推进；在日志中仍能看到关键事件（如“移动到某地块”、“支付租金”）。


## 可重复性与恢复


所有步骤应是增量式修改，可重复执行。若需要回退，使用 `git status` 确认变更文件，然后对单个文件使用版本控制恢复（例如 `git restore <path>`）。不要使用破坏性清理命令。若新增测试文件导致问题，可以先注释对应测试或临时移出测试列表，再继续定位。


## 产物与备注


预期新增或改动文件（示例，不限于此）：
`Manager/System/Runtime.lua`
`Manager/System/RuntimeInit.lua`
`Manager/System/RuntimeLoop.lua`
`Manager/System/RuntimeTime.lua`
`Manager/System/UIPort.lua`
`Library/Monopoly/GameEvents.lua`
`Manager/System/EventHandlers.lua`
`Manager/ItemManager/Item/ItemRegistry.lua`
`Manager/GameManager/ChanceRegistry.lua`
`Manager/ChoiceManager/Choice/ChoiceRegistry.lua`
`tests/solid_event_registry_test.lua`

测试输出示例（缩进块，实际以运行结果为准）：
    lua tests/solid_event_registry_test.lua
    ok - registry extension works


## 接口与依赖


必须新增或保持的接口如下，供后续实现对齐：

在 `Library/Monopoly/GameEvents.lua` 中定义事件总线：
    local GameEvents = {}
    function GameEvents.new() end
    function GameEvents:on(kind, fn) end
    function GameEvents:emit(kind, payload) end

在 `Manager/System/UIPort.lua` 中定义最小 UI 端口接口（以空实现或断言为主）：
    local UIPort = {}
    function UIPort.new(overrides) end
    function UIPort:push_popup(payload) end
    function UIPort:on_tile_owner_changed(tile_id, owner_id) end
    function UIPort:on_tile_upgraded(tile_id, level) end
    function UIPort:on_move_anim(payload) end

在 `Manager/ItemManager/Item/ItemRegistry.lua` 中定义：
    local ItemRegistry = {}
    function ItemRegistry.register(item_id, handler) end
    function ItemRegistry.get(item_id) end
    function ItemRegistry.register_defaults() end

在 `Manager/GameManager/ChanceRegistry.lua` 中定义：
    local ChanceRegistry = {}
    function ChanceRegistry.register(effect, handler) end
    function ChanceRegistry.get(effect) end
    function ChanceRegistry.register_defaults() end

在 `Manager/ChoiceManager/Choice/ChoiceRegistry.lua` 中定义：
    local ChoiceRegistry = {}
    function ChoiceRegistry.register(kind, handler) end
    function ChoiceRegistry.get(kind) end
    function ChoiceRegistry.register_defaults() end

这些接口的默认实现应兼容现有逻辑，确保在不添加新注册项的情况下，游戏行为保持一致。


改动记录：本计划为首次版本，尚未实施。
改动记录：拆分为总计划 + 三个子计划，里程碑细节迁移到 `pilots/16_*`、`pilots/17_*`、`pilots/18_*`。
改动记录：新增全局格式统一任务（ClassUtils.Class + EmmyLua 精简注释），并拆分为子计划 `pilots/19_monopoly_classutils_emmylua_plan.md`。
改动记录：完成里程碑 1 执行与验收，更新进度与测试环境发现。
改动记录：完成里程碑 2 执行与验收，更新进度与事件化结果。
