# UI MVC 重构计划（UIRoot 结构）


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 .github/agent/PLANS.md。


## 目的 / 全局视角


本次目标是把 UI 相关代码整理为明确的 MVC 模式，并将 UI 统一归入 `Manager/UIRoot`：Model 负责把游戏状态与 UI 运行态整理为纯数据，View 只根据 Model 更新 UI 节点和棋盘单位，Controller 只处理 UI 事件并驱动 GameplayLoop 或 UI 运行态。完成后界面显示与交互保持一致，但 TurnManager 不再承载 UI 逻辑，`UIEventRouter` 仅做事件绑定与转发，`UIModel` 可在回归脚本中构造并断言结构。可观察结果是：回合信息、道具槽位、黑市、弹窗、棋盘与动画表现与现状一致；仓库中存在清晰的 `Manager/UIRoot` 主链路；回归脚本可完整通过并包含最小 MVC 断言。


## 进度


- [x] (2026-02-02 16:22Z) 梳理现有 UI 文件归属并确定迁移清单（TurnManager/ChoiceManager/MarketManager/BoardManager）。
- [x] (2026-02-02 16:22Z) 搭建 `Manager/UIRoot` 并迁移 UI 主链路文件，修正引用路径。
- [x] (2026-02-02 16:22Z) 建立 `UIModel`/`UIController`/`UIView`，让 `GameplayLoop` 与 `UIEventRouter` 接入。
- [x] (2026-02-02 16:22Z) 迁移 Board/Market 的 UI 文件到 UIRoot 并调整引用。
- [x] (2026-02-02 17:52Z) 调整领域 View（Board/Market）只消费 Model，补齐 UIModel 结构并更新事件路由与回归脚本（UIModel 输出 panel/item_slots/choice/market/popup/board；BoardView/UIMarket/UIView/UIEventRouter 改为消费 ui_model；回归脚本新增 UIModel 结构断言并通过）。


## 意外与发现


- 观察：尝试并行 subagent 失败（线程上限）。
  处理：改为单线程推进迁移与引用更新。
- 观察：UIModel 的 item_slots 为“稀疏数组”，`#` 取值为 0，新增回归断言初版失败。
  处理：调整回归断言为检查 slot[1] 的实际 item_id。


## 决策日志


- 决策：新增 `Manager/UIRoot` 作为 UI 主链路归属，TurnManager 不再承载 UI 代码。
  理由：确保分层纯粹，避免 GameplayLoop 与 UI 代码互相耦合。
  日期/作者：2026-02-02 / Codex
- 决策：直接将 Presenter 改名为 UIModel，并统一入口为 `UIModel.build(state, game)`。
  理由：避免过渡层，结构更纯且概念清晰。
  日期/作者：2026-02-02 / Codex
- 决策：Controller 不直接操作 UI 节点，只生成 GameplayLoop action 或更新 UI 运行态字段。
  理由：符合 MVC 单向数据流，避免 UI 逻辑分散。
  日期/作者：2026-02-02 / Codex
- 决策：不保留独立 UIAdapter，直接在 UIView 内使用 UIManager 与 UIAliases。
  理由：当前仅有单一调用点且无平台适配需求，减少一层抽象。
  日期/作者：2026-02-02 / Codex
- 决策：将 Board/Market 相关 UI 文件全部迁入 UIRoot。
  理由：UI 归属集中，结构更纯。
  日期/作者：2026-02-02 / Codex
- 决策：UIModel 内部补齐 panel/item_slots/choice/market/popup/board，并让 View/Router 只依赖 ui_model。
  理由：去掉对 store_state 与 pending_choice 的直接读取，满足 MVC 单向数据流。
  日期/作者：2026-02-02 / Codex
- 决策：在 UI 运行态记录 popup_payload，用于 UIModel.popup 输出。
  理由：弹窗内容之前只写入 UI 节点，需要留存最小数据以供 Model 输出。
  日期/作者：2026-02-02 / Codex


## 结果与复盘


已完成 MVC 分层落地：UIModel 输出完整 UI 数据结构，View 与 Router 只消费 ui_model，Board/Market 视图去除对 store_state 与 pending_choice 的直接读取。回归脚本新增 UIModel 结构断言并通过（32 条）。


## 背景与导读


当前 UI 刷新入口在 `Manager/TurnManager/GameplayLoop.lua` 的 `refresh_view`，它通过 `Manager/TurnManager/GUI/Presenter.lua` 生成 `view` 并调用 `Manager/TurnManager/GUI/MainView.lua` 的 `refresh_panel`、`refresh_board`。`Manager/TurnManager/GUI/UIState.lua` 与 `Manager/MarketManager/GUI/UIMarket.lua` 直接读取 `game.store.state`、`state.pending_choice` 与 UI 运行态字段，`Manager/TurnManager/GUI/UIEventRouter.lua` 直接调用 `GameplayLoop.dispatch_action` 或 `MainView`。这些路径混合了 Model 构建、View 渲染与事件控制职责，且 UI 代码归属在 TurnManager。需要迁移到 `Manager/UIRoot` 并拆分为 MVC。

MVC 在本仓库的定义：Model 是给 UI 使用的纯数据结构；View 负责把 Model 应用到 UI 节点、棋盘单位与动画；Controller 负责处理 UI 事件并推动游戏状态或 UI 运行态变化。Model 不直接操作 UI 节点，View 不直接修改游戏状态，Controller 不直接渲染 UI。


## 工作计划


先建立 `Manager/UIRoot` 作为 UI 主链路目录，并迁移 TurnManager/ChoiceManager/BoardManager/MarketManager 下的 UI 文件到该目录（MainView、UIEventRouter、UIState、UIPanel、UIPhase、Presenter、EventHandlers、UIChoice、UIAliases、BoardView、BoardScene、TileRenderer、MoveAnim、ActionAnim、BuildingEffects、UIMarket、MarketUI）。然后直接把 Presenter 改名为 `UIModel`，将 UIPanel/UIChoice/UIMarket 的数据拼装逻辑迁入 Model；新增 `UIController` 承接 UIEventRouter 的事件处理。最后调整 View 层接口：`UIView`（原 MainView）以 `render(state, ui_model)` 为入口，`UIView` 直接使用 UIManager 与 UIAliases 完成节点操作，`UIMarket`/`BoardView` 只消费 `ui_model`，不再直接读取 `game.store.state` 或 `state.pending_choice`。完成后删除或收敛旧入口，保证只有 MVC 主链路保留。


## 具体步骤


步骤一：确认 UI 文件归属与迁移清单。工作目录为仓库根目录，运行：

    rg -n "Presenter|MainView|UIState|UIMarket|BoardView|UIEventRouter|UIChoice|UIAliases" Manager init.lua

记录需要迁移到 `Manager/UIRoot` 的文件与引用点，作为后续替换入口。

步骤零（并行策略）：按目录切分并锁定文件归属，所有改动前先写明“谁改哪些文件、改什么目标”，避免并行冲突。建议三组并行，明确范围与目标：

- A 组（UIRoot 迁移组）：只负责 `Manager/TurnManager/GUI` 与 `Manager/ChoiceManager/GUI` 的迁移清单与改动目标，产出“迁移后目标路径 + require 替换点列表”，不改 Board/Market。
- B 组（Board/Market 迁移组）：只负责 `Manager/BoardManager/GUI` 与 `Manager/MarketManager/GUI` 的迁移清单与改动目标，产出“迁移后目标路径 + require 替换点列表”，不改 Turn/Choice。
- C 组（入口联动组）：只负责 `Manager/TurnManager/GameplayLoop.lua`、`init.lua`、`Manager/UIRoot/UIEventRouter.lua` 与回归测试的联动清单，产出“需要同步调整的入口与顺序”。

每组必须在开始前列出锁定文件清单，并在结尾给出“修改目标 + 预计改动点 + 风险提醒”。主代理在汇总后统一执行迁移与改动，禁止跨组同时改同一文件。

步骤二：建立 UIRoot 并迁移文件。创建目录 `Manager/UIRoot`，将下列文件迁入并更新 require 路径：

    Manager/TurnManager/GUI/MainView.lua -> Manager/UIRoot/UIView.lua
    Manager/TurnManager/GUI/UIEventRouter.lua -> Manager/UIRoot/UIEventRouter.lua
    Manager/TurnManager/GUI/UIState.lua -> 删除（其节点操作函数合并到 UIView）
    Manager/TurnManager/GUI/UIPanel.lua -> Manager/UIRoot/UIPanel.lua
    Manager/TurnManager/GUI/UIPhase.lua -> Manager/UIRoot/UIPhase.lua
    Manager/TurnManager/GUI/Presenter.lua -> Manager/UIRoot/UIModel.lua（直接改名）
    Manager/TurnManager/GUI/EventHandlers.lua -> Manager/UIRoot/UIEventHandlers.lua
    Manager/ChoiceManager/GUI/UIChoice.lua -> Manager/UIRoot/UIChoice.lua
    Manager/ChoiceManager/GUI/UIAliases.lua -> Manager/UIRoot/UIAliases.lua
    Manager/BoardManager/GUI/BoardView.lua -> Manager/UIRoot/BoardView.lua
    Manager/BoardManager/GUI/BoardScene.lua -> Manager/UIRoot/BoardScene.lua
    Manager/BoardManager/GUI/TileRenderer.lua -> Manager/UIRoot/TileRenderer.lua
    Manager/BoardManager/GUI/MoveAnim.lua -> Manager/UIRoot/MoveAnim.lua
    Manager/BoardManager/GUI/ActionAnim.lua -> Manager/UIRoot/ActionAnim.lua
    Manager/BoardManager/GUI/BuildingEffects.lua -> Manager/UIRoot/BuildingEffects.lua
    Manager/MarketManager/GUI/UIMarket.lua -> Manager/UIRoot/UIMarket.lua
    Manager/MarketManager/GUI/MarketUI.lua -> Manager/UIRoot/MarketUI.lua

同时把 `Manager/TurnManager/GUI/AutoRunner.lua` 移回 `Manager/TurnManager/AutoRunner.lua`，并更新引用。迁移完成后删除原目录下空文件夹。

步骤三：改名 Model 并新增 Controller。将 `Manager/UIRoot/UIModel.lua` 作为原 Presenter 改名后的文件，同时新增 `Manager/UIRoot/UIController.lua`：

- `UIModel.build(state, game)` 聚合 panel、item_slots、choice、market、popup、board 六块数据，复用 `UIPanel`、`UIChoice`、`UIMarket` 的拼装逻辑，但输出只包含纯数据字段。
- `UIController.dispatch(state, game, intent)` 负责 UI 事件 -> GameplayLoop action 或 UI 运行态更新，不直接操作 UI 节点。

完成后删除 `Presenter` 的所有引用点，确保仓库中只保留 `UIModel`。

步骤四：改造 View 入口与节点操作。将 `UIView` 作为 View 入口，新增 `UIView.render(state, ui_model, log_once, build_log_prefix)`，内部调用：

- `UIView.refresh_panel(ui_model.panel)`、`UIView.refresh_item_slots(ui_model.item_slots)`（这些函数直接用 UIManager 与 UIAliases 操作节点）
- `UIMarket` 的新接口 `refresh_market(ui_model.market)`
- `BoardView.refresh_board(state, ui_model.board, log_once, build_log_prefix)`

同时将 `UIMarket` 去除对 `game.store.state` 与 `state.pending_choice` 的读取，改为消费 `ui_model`。

步骤五：接入 GameplayLoop 与事件路由。`GameplayLoop.refresh_view` 改为：

- 构建 `ui_model = UIModel.build(state, game)` 并保存到 `state.ui_model`
- 调用 `UIView.render(state, ui_model, log_once, build_log_prefix)`

`UIEventRouter.bind` 改为只监听节点并把 intent 交给 `UIController.dispatch`，不再直接调用 `GameplayLoop.dispatch_action` 或 `UIView`。

步骤六：更新回归测试与验收。修改 `.github/tests/regression.lua` 中依赖 `Presenter` 的测试，改为构造 `UIModel` 并断言关键字段存在。运行回归脚本并记录结果。


## 验证与验收


在仓库根目录运行回归脚本：

    lua .github/tests/regression.lua

预期输出包含：

    All regression checks passed (31)

同时进行手工验收：启动游戏后确认“基础屏”显示，回合信息与玩家资产显示正常；点击“行动按钮”与“托管按钮”可推进回合并切换自动控制；触发黑市时黑市 UI 正常打开并可选择购买；触发弹窗时确认按钮可关闭弹窗；棋盘单位与建筑更新与改动前一致。


## 可重复性与恢复


重构应分阶段保持可运行状态。若需要回退，可先恢复 `GameplayLoop.refresh_view` 对 `Presenter` 的调用与 `UIView` 的旧接口，再移除 `UIModel`/`UIController` 新模块。每次回退后运行回归脚本确认一致。


## 产物与备注


应保留以下证据片段：

    rg -n "UIModel|UIController|UIView|UIRoot" Manager

    lua .github/tests/regression.lua
    All regression checks passed (32)


## 接口与依赖


在 `Manager/UIRoot/UIModel.lua` 中定义：

    UIModel.build(store_state, env) -> ui_model

`env.game` 必填；`env.ui_state` 用于读取 UI 运行态（自动控制开关、market 选中项、popup payload）。

`ui_model` 至少包含：panel（回合与玩家信息）、item_slots（道具图标与可用性）、choice（选择标题/正文/选项/取消状态）、market（黑市列表/选中项/价格与图标）、popup（弹窗标题/正文/按钮文本）、board（tiles、players 与 overlay 数据）。

在 `Manager/UIRoot/UIController.lua` 中定义：

    UIController.dispatch(state, game, intent) -> nil

`intent` 需要覆盖 `next`、`auto`、`item_slot_i`、`choice_select`、`choice_cancel`、`market_select`、`market_confirm`、`popup_confirm` 等 UI 事件。Controller 内部通过 `GameplayLoop.dispatch_action` 与 `state` 的 UI 运行态字段实现行为。

`UIView.render(state, ui_model, log_once, build_log_prefix)` 作为 View 入口，必须在 `GameplayLoop.refresh_view` 中被调用；`UIView`、`UIMarket`、`BoardView` 的刷新函数必须只依赖 `ui_model` 与 `state` 的 UI 运行态，不得再直接读取 `game.store.state`。

本次修改说明：执行迁移与接入步骤，更新进度与意外记录，原因是计划已进入实施阶段并完成大部分结构调整。
本次修改说明：补充保留“Board/Market UI 文件集中到 UIRoot”的变更缘由，原因是避免遗漏关键结构决策。
本次修改说明：记录回归通过并更新进度描述，原因是已完成当前阶段验证。
本次修改说明：补齐 UIModel 输出结构并完成 View/Router 去状态化，原因是完成 MVC 分层落地。
本次修改说明：更新 UIModel 接口签名描述，原因是同步实际实现与计划文本。
