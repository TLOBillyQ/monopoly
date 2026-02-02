# UI MVVM 重构方案


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 .github/agent/PLANS.md。


## 目的 / 全局视角


当前 UI 刷新、事件处理与数据拼装分散在 `Manager/TurnManager/GUI`、`Manager/MarketManager/GUI` 与 `Manager/BoardManager/GUI`，视图直接读取模型与引擎对象，导致改动成本高且难以测试。重构为 MVVM 后，UI 只依赖 ViewModel 的纯数据结构，事件通过命令层返回给 GameplayLoop，便于在不启动引擎的情况下验证 UI 逻辑，也减少 UI 与游戏模型的耦合。可观察结果是：界面显示与交互保持一致（回合信息、道具槽位、黑市、弹窗、棋盘与动画表现不变），但 `MainView`/`UIMarket`/`UIState` 不再直接读取 `game.store.state` 或 `GameAPI`；新增的 ViewModel 模块可以在回归脚本中被构造并断言字段；回归脚本可完整通过。


## 进度


- [ ] (2026-02-02 22:40Z) 梳理 UI 现状与数据流，确定 MVVM 边界与需要迁移的函数/字段。
- [ ] (2026-02-02 22:40Z) 新增 ViewModel 与 ViewRenderer 基础模块，并让 `Presenter`/`MainView` 进入 MVVM 调用链。
- [ ] (2026-02-02 22:40Z) 拆分市场/选择/面板/弹窗/棋盘的 ViewModel 与 View 实现，完成 UIEventRouter 命令化改造。
- [ ] (2026-02-02 22:40Z) 更新 `init.lua` 与 `GameplayLoop` 的 UI 状态结构，补充回归测试与手工验收步骤。


## 意外与发现


目前无。实施过程中如发现 UI 节点命名不一致、UIManager 查询性能异常或现有 UI 状态字段隐式依赖，需要记录现象与最小证据片段（日志或测试输出）。


## 决策日志


- 决策：将 `state.ui` 拆分为 `ui_adapter` 与 `ui_state`，并新增 `state.ui_vm` 保存最新 ViewModel。
  理由：View 仅使用适配器操作 UI 节点，运行态 UI 状态集中管理，ViewModel 只存纯数据，UIEventRouter 可基于 `ui_vm` 做映射。
  日期/作者：2026-02-02 / Codex
- 决策：棋盘渲染仍由 `BoardView` 执行引擎调用，但数据来源改为 BoardViewModel。
  理由：棋盘涉及单位对象与动画，引擎对象必须留在 View 层；通过 ViewModel 传递数据即可满足 MVVM 分层。
  日期/作者：2026-02-02 / Codex
- 决策：保留 `Presenter.present` 作为兼容入口，但内部改为构建 ViewModel。
  理由：减少改动面，逐步迁移调用点，降低一次性重构风险。
  日期/作者：2026-02-02 / Codex


## 结果与复盘


尚未实施。完成后在此总结 UI 行为是否保持一致、ViewModel 可测试性是否提升，以及迁移过程中出现的风险与修正。


## 背景与导读


UI 入口在 `init.lua`，其中构建 `state.ui` 并在 `EVENT.GAME_INIT` 后调用 `MainView.init_ui_assets`。回合 UI 刷新在 `Manager/TurnManager/GameplayLoop.lua` 的 `refresh_view`，通过 `Presenter.present` 生成 `view` 并调用 `MainView.refresh_panel` 与 `MainView.refresh_board`。UI 事件由 `Manager/TurnManager/GUI/UIEventRouter.lua` 直接派发到 `GameplayLoop.dispatch_action`。市场、选择与弹窗的 UI 拼装分别在 `Manager/MarketManager/GUI/UIMarket.lua`、`Manager/ChoiceManager/GUI/UIChoice.lua` 与 `Manager/TurnManager/GUI/MainView.lua`，其中大量逻辑直接依赖 `game.store.state`、`GameAPI`、`Globals.Refs` 与 UIManager 查询。

术语说明：MVVM 指 Model-View-ViewModel。Model 是游戏状态（`game.store.state` 与运行态 `state`），ViewModel 是面向 UI 的纯数据结构（字符串、图片 key、可见性、按钮使能等），View 负责把 ViewModel 应用到 UI 节点与引擎单位上。命令层把 UI 事件转成 GameplayLoop 能理解的 action，以保持单向数据流。


## 工作计划


先补齐 MVVM 基础设施，在 `Manager/TurnManager/GUI` 新增 ViewModel 与 ViewRenderer 模块，并让 `Presenter.present` 返回 ViewModel。然后拆分 `UIState.lua` 为 UI 适配器与 UI 运行态，`MainView.lua` 只做 ViewRenderer 协调（面板、道具槽位、选择、市场、弹窗与棋盘渲染）。市场与选择的业务拼装逻辑从 `UIMarket.lua` 与 `MainView.open_choice_modal` 中抽出，集中到 `MarketViewModel` 与 `ChoiceViewModel`。接着把 `UIEventRouter` 改为命令化：它不直接操作 UI，而是通过 `CommandRouter` 生成 action 并调用 `GameplayLoop.dispatch_action`，并在需要时更新 `ui_state`（例如自动托管开关、弹窗关闭）。最后更新 `init.lua` 与 `GameplayLoop` 的 UI 状态字段，确保 `state.ui_vm` 在每次 tick 后更新，新增最小回归测试验证 ViewModel 输出结构和命令映射不回退。


## 具体步骤


步骤一：定位现有 UI 模块与依赖，确认迁移范围与可复用函数。工作目录为仓库根目录，运行：

    rg -n "MainView|Presenter|UIState|UIMarket|UIEventRouter|BoardView" Manager init.lua
    rg -n "ui_refs|pending_choice|market_choice_option_ids" Manager/TurnManager/GUI

预期看到 `MainView`、`Presenter`、`UIState`、`UIMarket`、`BoardView` 与 `UIEventRouter` 的调用链，作为后续替换入口。

步骤二：新增 MVVM 基础模块。新建目录 `Manager/TurnManager/GUI/MVVM`，新增 `RootViewModel.lua`、`PanelViewModel.lua`、`ChoiceViewModel.lua`、`MarketViewModel.lua`、`PopupViewModel.lua`、`BoardViewModel.lua`、`CommandRouter.lua` 与 `ViewRenderer.lua`。将 `UIPanel.lua`、`UIChoice.lua` 中的文本拼装逻辑复用到对应 ViewModel；将 `UIMarket.lua` 中对配置与图标的计算逻辑迁入 `MarketViewModel`，确保 ViewModel 只输出纯数据，不调用 UIManager。

步骤三：拆分 UI 状态并改造 `MainView.lua` 与 `UIState.lua`。在 `UIState.lua` 中保留 UI 节点适配器（`query_node`、`set_label`、`set_visible` 等），另新增 `UIRuntimeState`（可放在 `MVVM/UIRuntimeState.lua` 或 `UIState.lua` 中的新函数）承接 `auto_play`、`item_slot_item_ids`、`market_active`、`popup_active` 等运行态字段。`MainView.lua` 改为 ViewRenderer 的门面：新增 `MainView.render(state, ui_vm)`，内部调用 `ViewRenderer` 依次渲染面板、道具槽位、选择、市场、弹窗与棋盘。原有 `refresh_panel`、`refresh_item_slots` 等函数改为调用 `ViewRenderer` 对应子函数，避免直接读取 `game.store.state`。

步骤四：改造 `Presenter` 与 `GameplayLoop.refresh_view`。`Presenter.present` 改为 `RootViewModel.build` 的轻包装，输出 `ui_vm`。`GameplayLoop.refresh_view` 改为在每帧构造 `ui_vm`，保存到 `state.ui_vm`，然后调用 `MainView.render(state, ui_vm)`。棋盘渲染入口改为 `BoardView.refresh_board(state, ui_vm.board, log_once, build_log_prefix)`，并在 `BoardView` 内替换对 `view.state` 的直接访问为 `board_vm` 字段。

步骤五：命令化 UI 事件。`UIEventRouter` 的点击回调改为调用 `CommandRouter.dispatch(state, game, intent)`，由命令层决定生成 `GameplayLoop.dispatch_action` 的 action，或更新 `ui_state`（例如 `popup` 关闭、自动托管开关）。`resolve_option_id` 的映射改为读取 `state.ui_vm` 中的 `choice.options` 与 `market.option_ids`，避免依赖 `state.market_choice_option_ids` 的隐式状态。

步骤六：同步入口与弹窗逻辑。`init.lua` 中 `build_state` 创建 `ui_adapter` 与 `ui_state`，并设置 `state.ui_vm = nil`；`state.push_popup` 改为写入 `ui_state.popup`，由渲染层显示与隐藏。`GameplayLoop.step_modal_timeout`、`GameplayLoop.clear_choice` 等逻辑改为基于 `ui_state` 或 `ui_vm` 判断当前是否有弹窗/选择，确保关闭行为只修改状态，不直接操作 UI 节点。

步骤七：补充验证与回归测试。在 `.github/tests/regression.lua` 增加最小用例，构造一个伪 `store_state` 与 `state.ui_state`，调用 `RootViewModel.build` 并断言关键字段存在；同时增加 UI 命令映射的轻量测试（例如 `CommandRouter` 接收 `next` 命令会调用 `GameplayLoop.dispatch_action` 的路径可被 stub 计数）。最后运行回归脚本。


## 验证与验收


在仓库根目录运行回归脚本：

    lua .github/tests/regression.lua

预期输出包含：

    All regression checks passed (N)

其中 N 为新增测试后的总数。手工验收步骤：启动游戏后确认“基础屏”显示，回合信息与玩家资产显示正常；点击“行动按钮”与“托管按钮”能推进回合并切换自动控制；触发黑市时黑市 UI 正常打开并可选择购买；触发弹窗时确认按钮可关闭弹窗；棋盘上的玩家单位与建筑更新与改动前一致。


## 可重复性与恢复


本次重构遵循先并行、后切换的策略，可分阶段迁移。若需回退，可将 `Presenter` 与 `MainView` 的调用链恢复为旧逻辑，删除 `MVVM` 新模块并恢复 `UIState` 原结构。建议在每个阶段保留一个可运行状态，并在回退后再次运行回归脚本确认一致性。


## 产物与备注


应保留以下证据片段：

    rg -n "RootViewModel|ViewRenderer|CommandRouter" Manager/TurnManager/GUI

    lua .github/tests/regression.lua
    All regression checks passed (N)


## 接口与依赖


在 `Manager/TurnManager/GUI/MVVM/RootViewModel.lua` 中定义：

    RootViewModel.build(state, game) -> ui_vm

`ui_vm` 至少包含：

    ui_vm.panel.turn_label
    ui_vm.panel.player_rows[1..4].name
    ui_vm.panel.player_rows[1..4].cash
    ui_vm.panel.player_rows[1..4].land_count
    ui_vm.panel.player_rows[1..4].total_assets
    ui_vm.item_slots[i].icon_key
    ui_vm.item_slots[i].enabled
    ui_vm.item_slots[i].item_id
    ui_vm.choice.active
    ui_vm.choice.title
    ui_vm.choice.body
    ui_vm.choice.options[i].label
    ui_vm.choice.options[i].id
    ui_vm.choice.allow_cancel
    ui_vm.choice.cancel_label
    ui_vm.market.active
    ui_vm.market.option_ids[i]
    ui_vm.market.items[i].label
    ui_vm.market.items[i].visible
    ui_vm.market.items[i].enabled
    ui_vm.market.items[i].frame_key
    ui_vm.market.selected.icon_key
    ui_vm.market.selected.price_label
    ui_vm.popup.active
    ui_vm.popup.title
    ui_vm.popup.body
    ui_vm.popup.button_text
    ui_vm.board.tile_count
    ui_vm.board.tiles[i].id
    ui_vm.board.tiles[i].owner_id
    ui_vm.board.players[i].id
    ui_vm.board.players[i].position
    ui_vm.board.players[i].eliminated

在 `Manager/TurnManager/GUI/MVVM/ViewRenderer.lua`（或 `MainView.lua`）中定义：

    ViewRenderer.render(state, ui_vm) -> nil

在 `Manager/TurnManager/GUI/MVVM/CommandRouter.lua` 中定义：

    CommandRouter.dispatch(state, game, intent) -> nil

其中 `intent` 需覆盖：`next`、`auto`、`item_slot_i`、`choice_select`、`choice_cancel`、`market_select`、`market_confirm`、`popup_confirm`。命令层内部通过 `GameplayLoop.dispatch_action` 与 `state.ui_state` 更新实现行为。

`UIState` 需提供 UI 适配器初始化函数（例如 `UIState.build_adapter()`）与 UI 运行态初始化函数（例如 `UIState.build_runtime_state()`），并在 `init.lua` 中分别挂载为 `state.ui_adapter` 与 `state.ui_state`。

本次修改说明：新建 46 号计划，明确 UI MVVM 重构范围与执行步骤，便于后续实施。
