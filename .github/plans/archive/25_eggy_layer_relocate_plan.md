# 移除 EggyLayer 并重建运行时


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循仓库内的 `.agent/PLANS.md` 规范。

## 目的 / 全局视角


当前适配层以 `EggyLayer` 类集中承载 UI、动画、启动与帧循环等职责，这个抽象层级过重且位置不匹配。目标是移除 `EggyLayer` 概念与文件，把运行时拆成清晰的模块函数与显式状态表，让入口直接装配运行时，UI 与动画行为保持一致。完成后代码库里不再存在 `EggyLayer` 类与 `Manager/TurnManager/GUI/Layer.lua` 文件，入口仍能启动游戏，回归测试通过，并可在运行时看到 UI 正常刷新与回合推进。

## 进度


- [x] (2026-01-31 01:32Z) 已确认入口链路与 EggyLayer 依赖点，并记录需要调整的测试与文档引用。
- [x] (2026-01-31 01:59Z) 已完成运行时模块重建与入口改造，运行时由 `Runtime` 装配。
- [x] (2026-01-31 01:59Z) 已迁移 UI、动画与事件逻辑并删除 `EggyLayer`/`MainController` 文件。
- [x] (2026-01-31 01:59Z) 已更新文档与测试并完成回归与入口验证。

## 意外与发现


观察：`init.lua` 直接调用 `Manager.GameManager.Entry.install()`，`Manager/System/Runtime.lua` 目前只是薄封装且未被入口使用，这给运行时重组留出了空间。证据片段如下：

    require "Globals.__init"
    require "Manager.__init"
    require("Manager.GameManager.Entry").install()

观察：`.github/tests/regression.lua` 直接调用 `EggyLayer.step_move_anim` 与 `EggyLayer.step_modal_timeout`，测试入口需要同步调整到新的运行时函数。证据片段如下：

    local EggyLayer = require("Manager.TurnManager.GUI.Layer")
    EggyLayer.step_move_anim(layer, { ... })

观察：规则层多处通过 `game.ui_port` 调用 `push_popup/on_tile_upgraded/on_tile_owner_changed`，并依赖 `wait_move_anim/wait_action_anim` 字段，运行时必须保留这些接口与字段。证据片段如下：

    if ui_port and ui_port.on_tile_owner_changed then
      ui_port:on_tile_owner_changed(tile.id, owner_id)
    end

## 决策日志


决策：移除 `EggyLayer` 类与文件，改为运行时模块函数加显式 `runtime` 状态表，不再提供冒号方法。理由：`EggyLayer` 是错误抽象层级，模块化函数更清晰且符合 Eggy API 只能用 `.` 的约束。日期/作者：2026-01-31 / Codex。

决策：保留 `Manager/GameManager/Entry.install()` 作为外部入口，但其内部改为调用新的 `Manager/System/Runtime.install()`。理由：保持现有入口与测试接口稳定，同时把装配职责收敛到系统运行时。日期/作者：2026-01-31 / Codex。

决策：UI 创建与运行时注册仍放在 `EVENT.GAME_INIT` 触发时执行，不提前创建 UI。理由：Eggy 环境要求 UI 只能在初始化完成后创建，保持现有运行时行为与时序。日期/作者：2026-01-31 / Codex。

决策：不新增 `RuntimeState.lua`，改为在 `Manager/System/Runtime.lua` 内部构建 runtime 状态表。理由：减少文件与额外接口，符合 CodingDiscipline 的最少文件要求。日期/作者：2026-01-31 / Codex。

决策：删除 `Manager/TurnManager/GUI/MainController.lua`，将 action 处理逻辑合并到 `RuntimeLoop.dispatch_action`，由 `UIEventRouter` 直接调用 `RuntimeLoop/RuntimeUI`。理由：去掉纯转发层并避免循环依赖。日期/作者：2026-01-31 / Codex。

决策：runtime 表保留 `push_popup/on_tile_upgraded/on_tile_owner_changed` 方法，用于 `game.ui_port` 调用。理由：规则层现有逻辑直接通过 ui_port 触发表现。日期/作者：2026-01-31 / Codex。

## 结果与复盘


已完成运行时重建并移除 `EggyLayer`/`MainController`，入口改为 `Runtime.install` 装配，`RuntimeLoop` 负责动作与帧循环，`RuntimeUI` 负责 UI 刷新与弹窗。回归与入口测试已通过：`.github/tests/deps_check.lua`、`.github/tests/regression.lua`、`.github/tests/ui_missing_impl_audit.lua`、`.github/tests/entry_smoke_test.lua`。仍需在 Eggy 环境做一次手工启动验收，确认 UI 与动画表现一致。

## 背景与导读


入口链路为 `main.lua` -> `init.lua` -> `Manager/GameManager/Entry.lua`。当前 `Entry.install()` 调用 `Manager/System/Runtime.install()`，运行时在 `EVENT.GAME_INIT` 触发时完成 UIManager.Builder、`G` 初始化、`RuntimeLoop.set_game` 与 `UIEventRouter.bind`，并通过 `SetFrameOut` 驱动 `RuntimeLoop.tick`。UI 逻辑经 `RuntimeUI` -> `MainView` -> `UIState/BoardView/UIMarket` 委托，运行时状态表持有 `auto_runner/pending_choice` 等字段，同时作为 `game.ui_port` 提供 `push_popup/on_tile_upgraded/on_tile_owner_changed`。Eggy 运行时约束仍然有效：入口固定 `main.lua`，UI 必须在初始化完成后创建，逻辑帧率固定 30 FPS，API 调用只能使用 `.`，涉及浮点参数要显式写成 `x.y`。

## 工作计划


把运行时职责拆分为运行时循环与 UI 桥接两部分，在 `Manager/System` 下新增 `RuntimeLoop.lua`、`RuntimeUI.lua`，并在 `Manager/System/Runtime.lua` 内构建 runtime 状态表作为装配入口。`RuntimeLoop` 负责 `set_game/new_game/dispatch_action/step_turn/tick` 与各类 `step_*`，用于驱动回合、动画等待与选择超时；`RuntimeUI` 负责 UI 刷新与弹窗接口，继续委托 `MainView` 与 `Presenter`。入口层改为 `Entry.install()` 调用 `Runtime.install(opts)`，`UIEventRouter` 直接调用 `RuntimeLoop/RuntimeUI`，同时移除 `MainController` 与 `EggyLayer` 文件。所有对引擎 API 的调用继续使用 `.` 形式并保持 30 FPS 的时间换算。

## 具体步骤


先在仓库根目录用 `rg "EggyLayer"` 汇总所有引用位置，记录要改动的 Lua 文件与文档文件，确保没有遗漏的 require 或文字说明。命令示例如下：

    rg "EggyLayer" -n

接着在 `Manager/System` 下新增 `RuntimeLoop.lua`、`RuntimeUI.lua`，将 `Manager/TurnManager/GUI/Layer.lua` 中的初始化状态、日志适配、IntentDispatcher 监听、`step_*`、`tick`、UI 刷新与弹窗逻辑按职责搬迁到新文件，并把原有 `EggyLayer` 的字段改为 `runtime` 状态表字段。runtime 状态表由 `Manager/System/Runtime.lua` 内部构建，复用 `MainView.build_ui_state()` 生成 UI 状态，并保留 `auto_runner` 与日志适配器的初始化。`RuntimeLoop.tick` 需要完整复用原 `EggyLayer:tick` 的顺序与逻辑，包括自动行动、choice timeout、modal timeout、动画等待、阶段变化与 UI 刷新，并通过 `RuntimeUI` 调用 `MainView` 与 `Presenter`。`install_game_init` 与 `start_tick_loop` 从原 `EggyLayer` 中迁出并放入 `Manager/System/Runtime.lua`，其中 tick 回调必须调用 `RuntimeLoop.tick(runtime, tick_seconds)` 并保持 30 FPS 的时间换算与浮点写法。

然后更新入口与事件派发路径，把 `Manager/GameManager/Entry.lua` 改为 `require("Manager.System.Runtime")` 并调用 `Runtime.install({ game_factory = create_game })`，同时把 `Manager/System/Runtime.lua` 改为实际装配入口而非薄封装。同步改造 `Manager/TurnManager/GUI/UIEventRouter.lua`，将所有 `layer:dispatch_action` 等调用调整为 `RuntimeLoop/RuntimeUI` 模块函数；删除 `Manager/TurnManager/GUI/MainController.lua`，把原动作处理逻辑合并到 `RuntimeLoop.dispatch_action`。此处要保证 UI 交互逻辑不变，并继续通过 `RuntimeLoop.dispatch_action(runtime, action)` 作为规则层入口。

完成代码迁移后删除 `Manager/TurnManager/GUI/Layer.lua`，并用 `rg "Manager.TurnManager.GUI.Layer"` 与 `rg "EggyLayer"` 再次确认代码中不再引用该文件或命名。随后更新 `.github/tests/regression.lua` 等测试，将 `require("Manager.TurnManager.GUI.Layer")` 改为新的运行时模块引用，并把 `EggyLayer.step_move_anim`、`EggyLayer.step_modal_timeout` 等调用替换为 `RuntimeLoop.step_move_anim`、`RuntimeLoop.step_modal_timeout`。文档层面同步替换 `.github/docs/ui/03_popup_screen.md`、`.github/docs/reports/sync_report.md` 等对 `EggyLayer` 的描述，使其指向新的运行时模块与函数名。

## 验证与验收


在仓库根目录运行以下命令，预期全部退出码为 0。若有报错，优先回到 `rg "EggyLayer"` 的查找结果补齐遗漏替换，再重复验证。

    lua .github/tests/deps_check.lua
    lua .github/tests/regression.lua
    lua .github/tests/ui_missing_impl_audit.lua
    lua .github/tests/entry_smoke_test.lua

此外需要在 Eggy 环境中启动入口流程，观察 UI 正常显示、回合可推进、弹窗与动画等待仍然按原逻辑触发，以证明行为一致。

## 可重复性与恢复


本次重构以逻辑迁移与 require 替换为主，可重复执行。若出现不可恢复的行为差异，可从版本控制恢复 `Manager/TurnManager/GUI/Layer.lua` 与 `Manager/TurnManager/GUI/MainController.lua`，并把入口与测试 require 指回旧文件，以便快速回退到旧路径，再逐步按模块拆分迁移。

## 产物与备注


完成后应能看到入口装配与运行时调用的变化，例如：

    local Runtime = require("Manager.System.Runtime")
    local runtime = Runtime.install({ game_factory = create_game })

同时 `Manager/TurnManager/GUI/Layer.lua` 与 `Manager/TurnManager/GUI/MainController.lua` 已删除，入口与测试改为使用 `Manager/System/Runtime*.lua` 模块。

测试通过的输出片段：

    lua .github/tests/deps_check.lua
    Dependency self-check passed
    lua .github/tests/regression.lua
    All regression checks passed (30)
    lua .github/tests/entry_smoke_test.lua
    ok - entry load

## 接口与依赖


新的运行时模块需要暴露明确且可测试的函数接口，避免隐式冒号方法。推荐接口如下，实际实现需保持一致的文件路径与签名：

    -- Manager/System/Runtime.lua
    function Runtime.install(opts) end
    function Runtime.install_game_init(runtime) end
    function Runtime.start_tick_loop(runtime, interval) end

    -- Manager/System/RuntimeLoop.lua
    function RuntimeLoop.set_game(runtime, game) end
    function RuntimeLoop.new_game(runtime) end
    function RuntimeLoop.dispatch_action(runtime, action) end
    function RuntimeLoop.step_turn(runtime) end
    function RuntimeLoop.tick(runtime, dt) end
    function RuntimeLoop.step_auto_runner(runtime, dt, context) end
    function RuntimeLoop.step_choice_timeout(runtime, dt, opts) end
    function RuntimeLoop.step_modal_timeout(runtime, dt, opts) end
    function RuntimeLoop.step_move_anim(runtime, opts) end
    function RuntimeLoop.step_action_anim(runtime, opts) end

    -- Manager/System/RuntimeUI.lua
    function RuntimeUI.build_view(runtime) end
    function RuntimeUI.refresh_view(runtime) end
    function RuntimeUI.refresh_panel(runtime, view) end
    function RuntimeUI.refresh_item_slots(runtime, view) end
    function RuntimeUI.refresh_board(runtime, view) end
    function RuntimeUI.open_choice_modal(runtime, pending) end
    function RuntimeUI.close_choice_modal(runtime) end
    function RuntimeUI.select_market_option(runtime, option_id) end
    function RuntimeUI.push_popup(runtime, payload) end
    function RuntimeUI.close_popup(runtime) end
    function RuntimeUI.on_tile_upgraded(runtime, tile_id, level) end
    function RuntimeUI.on_tile_owner_changed(runtime, tile_id, owner_id) end

runtime 需要保留 `push_popup/on_tile_upgraded/on_tile_owner_changed` 方法，以及 `wait_move_anim/wait_action_anim` 字段，供 `game.ui_port` 调用。依赖方面必须继续使用 `LuaAPI`、`GameAPI`、`GlobalAPI` 的 `.` 调用形式，延迟与时间换算维持 30 FPS 与显式浮点写法，UI 创建仍需放在 `EVENT.GAME_INIT` 触发回调中执行。

变更记录：2026-01-31 重写计划，改为移除 EggyLayer 并重建运行时，原因是 EggyLayer 抽象层级错误且用户授权全局重构。
变更记录：2026-01-31 执行期间取消 `RuntimeState` 与 `MainController`，合并 dispatch_action 到 `RuntimeLoop` 并由 `Runtime` 构建状态表，原因是减少转发层与文件数量。
变更记录：2026-01-31 根据实现删除 `RuntimeUI.open/close_market_panel` 描述并补充测试输出，原因是清理未使用接口并记录验证证据。
变更记录：2026-01-31 移除 runtime.close_popup 约束与实现，原因是无调用点。
