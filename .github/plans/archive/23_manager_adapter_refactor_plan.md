# SOE 风格重构计划（全仓重组，避免 Logic/Presentation 命名）


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循仓库内的 `/.agent/PLANS.md`。

## 目的 / 全局视角


本次重构目标是参考 SecretOfEscaper（SOE）架构，**重新组织整个 Monopoly 仓库**，不局限于 gameplay，也不使用 “Logic/Presentation” 这类显式分层目录名。目标是采用 SOE 那种“隐含分层”的做法：顶层目录按职责自然分开，Manager 内按功能域拆分，GUI 以内聚模块管理 UI 事件与视图。完成后，入口清晰、初始化集中、GUI/View/Controller 分层明确；规则行为不变；UI 交互与动画不回退；测试通过。

## 进度


- [x] (2026-01-30 14:20) 梳理现有仓库结构与入口链路，确定 SOE 风格的目标目录树
- [x] (2026-01-30 14:20) 完成全仓迁移映射表（旧路径 -> 新路径）并确认重命名方案
- [x] (2026-01-30 14:20) 迁移文件与 require 路径，补齐入口与初始化链路
- [x] (2026-01-30 14:20) 迁移 UI 事件绑定与别名逻辑，拆分职责以符合 SOLID
- [x] (2026-01-30 14:20) 更新文档并运行依赖检查与回归测试
- [x] (2026-01-30 14:20) 重构涉及的类统一改为 ClassUtil 定义方式（本次改动未新增 Class 类）

## 意外与发现


- 观察：`Manager/System` 曾存在额外嵌套一层 `System/` 目录，需要扁平化以符合目标结构。
  证据：迁移前路径包含 `Manager/System/System/*.lua`。
- 观察：`.github/docs/reports/adapters_design.md` 与 `.github/docs/reports/solid_review.md` 当前不在工作树中，本次重构按用户要求暂不恢复。
  证据：`rg --files -g 'adapters_design.md'` / `rg --files -g 'solid_review.md'` 无输出。

## 决策日志


- 决策：不使用 “Logic/Presentation” 等显式分层目录名，采用 SOE 风格的功能域分层（Components/Config/Data/Globals/Library/Manager）。
  理由：SOE 架构通过目录职责隐含分层，符合命名偏好。
  日期/作者：2026-01-30 / Codex。

- 决策：Runtime 与 GUI 目录不再放在顶层，改为 SOE 样式挂到 `Manager/System/Runtime.lua` 与 `Manager/*Manager/GUI/`。
  理由：SOE 习惯把运行时/GUI 作为 Manager 的职责域，而非独立顶层层次。
  日期/作者：2026-01-30 / Codex。

- 决策：GUI 目录拆入具体 Manager，仅保留以下 Manager 有 GUI 子目录：MarketManager、ChoiceManager、BoardManager、TurnManager。
  理由：这些域具备明确的 UI 交互或表现职责，符合 SOE “每个业务模块自带 GUI 控制器”的习惯。
  日期/作者：2026-01-30 / Codex。

- 决策：重构范围内的“类”统一使用 ClassUtil 进行定义与构造。
  理由：统一类定义风格，降低阅读成本。
  日期/作者：2026-01-30 / Codex。

- 决策：UI 事件绑定收口到 `Manager/TurnManager/GUI/UIEventRouter.lua`，节点别名集中在 `Manager/ChoiceManager/GUI/UIAliases.lua`。
  理由：把 UI 事件路由与节点别名解耦出 Runtime，保持 Runtime 只做运行时装配。
  日期/作者：2026-01-30 / Codex。

## 结果与复盘


已完成目录迁移与 require 更新，新增 UIEventRouter/UIAliases，入口改为 `Manager/System/Runtime.install()`，并跑通依赖检查与回归测试。无行为变更观察点未发现回退，后续可补充 Eggitor 手动验收。

## 背景与导读


当前入口 `main.lua` -> `init.lua`，`init.lua` 调用 `Manager/System/Runtime.install()`。适配与 UI 逻辑分布在 `Manager/System/` 与 `Manager/*Manager/GUI/`，规则逻辑集中在 `Manager/*Manager/`。SOE 的做法是：入口只做初始化与进入关卡；Manager 下以功能域拆分；GUI 目录下有 View/Controller；运行时职责与 GUI 事件绑定分离。

本计划把 Monopoly 的整体架构改成 SOE 风格的“隐含分层”：顶层目录与 Manager 功能域即为分层，不新增 “Logic/Presentation” 名称。运行时与 GUI 作为 Manager 职责域，规则层仍集中在 Manager 各子域，保证行为不变。GUI 按 Manager 子域拆分。重构涉及的类定义统一使用 ClassUtil。

## 工作计划


先定稿目标目录树，并明确旧路径 -> 新路径映射，确保迁移可执行。目标结构如下：

    Components/
    Config/
    Data/
    Globals/
    Library/
    Manager/
      __init.lua
      BoardManager/
        __init.lua
        GUI/
          __init.lua
          BoardView.lua
          BuildingEffects.lua
          TileRenderer.lua
          MoveAnim.lua
          ActionAnim.lua
      PlayerManager/
      TurnManager/
        __init.lua
        GUI/
          __init.lua
          MainView.lua
          MainController.lua
          UIEventRouter.lua
          UIState.lua
          UIPanel.lua
          UIPhase.lua
          Layer.lua
      MovementManager/
      ItemManager/
      MarketManager/
        __init.lua
        GUI/
          __init.lua
          MarketUI.lua
          UIMarket.lua
      ChoiceManager/
        __init.lua
        GUI/
          __init.lua
          UIChoice.lua
          UIAliases.lua
      EffectManager/
      System/
        __init.lua
        Runtime.lua
        ECA.lua
        Macro.lua
        Refs.lua
        AdapterLayer.lua
        Presenter.lua
        AutoRunner.lua

目录说明：
- `Manager/` 仅保留规则与管理器逻辑（SOE 风格），按功能域拆分；原 `Manager/GameManager/*` 映射到对应 Manager 子域。
- `Manager/System/Runtime.lua` 承担运行时安装与 Tick 驱动（原 EggyRuntime）。
- GUI 拆入具体 Manager：Turn/Board/Market/Choice。
- 共享 UI 构建能力拆到对应 GUI 子域：主界面在 TurnManager/GUI；棋盘表现与动画在 BoardManager/GUI；黑市 UI 在 MarketManager/GUI；选择 UI 与别名在 ChoiceManager/GUI。
- Adapter/Core 模块（AdapterLayer/Presenter/AutoRunner）归入 Manager/System 作为系统级能力。
- 本次重构涉及的类统一使用 ClassUtil 定义。

迁移后统一把 require 路径从 `Manager.Adapter.*` 与 `Manager.GameManager.*` 更新为新的 Manager/System/GUI 结构。

### 旧路径 -> 新路径映射（核心）

运行时与系统：
- `Manager/System/Runtime.lua` -> `Manager/System/Runtime.lua`
- `Manager/System/ECA.lua` -> `Manager/System/ECA.lua`
- `Manager/System/Macro.lua` -> `Manager/System/Macro.lua`
- `Manager/System/Refs.lua` -> `Manager/System/Refs.lua`
- `Manager/System/AdapterLayer.lua` -> `Manager/System/AdapterLayer.lua`
- `Manager/System/Presenter.lua` -> `Manager/System/Presenter.lua`
- `Manager/System/AutoRunner.lua` -> `Manager/System/AutoRunner.lua`

TurnManager/GUI：
- `Manager/TurnManager/GUI/MainView.lua` -> `Manager/TurnManager/GUI/MainView.lua`
- `Manager/TurnManager/GUI/MainController.lua` -> `Manager/TurnManager/GUI/MainController.lua`
- `Manager/TurnManager/GUI/Layer.lua` -> `Manager/TurnManager/GUI/Layer.lua`
- `Manager/TurnManager/GUI/UIState.lua` -> `Manager/TurnManager/GUI/UIState.lua`
- `Manager/TurnManager/GUI/UIPanel.lua` -> `Manager/TurnManager/GUI/UIPanel.lua`
- `Manager/TurnManager/GUI/UIPhase.lua` -> `Manager/TurnManager/GUI/UIPhase.lua`

ChoiceManager/GUI：
- `Manager/ChoiceManager/GUI/UIChoice.lua` -> `Manager/ChoiceManager/GUI/UIChoice.lua`
- 节点别名映射逻辑 -> `Manager/ChoiceManager/GUI/UIAliases.lua`

MarketManager/GUI：
- `Manager/MarketManager/GUI/MarketUI.lua` -> `Manager/MarketManager/GUI/MarketUI.lua`
- `Manager/MarketManager/GUI/UIMarket.lua` -> `Manager/MarketManager/GUI/UIMarket.lua`

BoardManager/GUI：
- `Manager/BoardManager/GUI/BoardView.lua` -> `Manager/BoardManager/GUI/BoardView.lua`
- `Manager/BoardManager/GUI/BuildingEffects.lua` -> `Manager/BoardManager/GUI/BuildingEffects.lua`
- `Manager/BoardManager/GUI/TileRenderer.lua` -> `Manager/BoardManager/GUI/TileRenderer.lua`
- `Manager/BoardManager/GUI/MoveAnim.lua` -> `Manager/BoardManager/GUI/MoveAnim.lua`
- `Manager/BoardManager/GUI/ActionAnim.lua` -> `Manager/BoardManager/GUI/ActionAnim.lua`

规则层映射（示例）：
- `Manager/GameManager/Turn/*` -> `Manager/TurnManager/*`
- `Manager/GameManager/Item/*` -> `Manager/ItemManager/*`
- `Manager/GameManager/Market/*` -> `Manager/MarketManager/*`
- `Manager/GameManager/Choice/*` -> `Manager/ChoiceManager/*`
- `Manager/GameManager/Movement/*` -> `Manager/MovementManager/*`
- `Manager/GameManager/Effect/*` -> `Manager/EffectManager/*`
- `Manager/GameManager/System/*` -> `Manager/System/*`（除 Runtime/ECA/Macro/Refs）

## 具体步骤


1) 扫描现有路径与入口链路，生成“旧路径 -> 新路径”映射表，并补到计划中。确保所有 require 都能替换。

    rg -n "Manager.Adapter|Manager.GameManager" Manager

2) 创建新目录树并迁移文件；完成后全量替换 require 路径。

    mkdir Manager/BoardManager/GUI
    mkdir Manager/PlayerManager
    mkdir Manager/TurnManager/GUI
    mkdir Manager/MovementManager
    mkdir Manager/ItemManager
    mkdir Manager/MarketManager/GUI
    mkdir Manager/ChoiceManager/GUI
    mkdir Manager/EffectManager
    mkdir Manager/System

3) 调整入口链路：
- `main.lua` 仍只 require `init.lua`。
- `init.lua` 调用 `Manager/System/Runtime.install()`。
- `Manager/__init.lua` 装配所有 Manager 子域与各自 GUI 子目录的 `__init.lua`。

4) 拆分 UI 事件绑定：把原 Runtime 内的 UI 事件注册迁移到 `Manager/TurnManager/GUI/UIEventRouter.lua`，由 `MainController.bind(layer)` 调用；UI 别名统一到 `Manager/ChoiceManager/GUI/UIAliases.lua`。

5) 重构过程中，凡是需要类结构的模块，统一改为 `ClassUtil` 定义方式；避免新增无调用点的抽象。

6) 更新 `.github/tests/deps_check.lua` 依赖规则前缀与说明文字，确保规则层不依赖 `Manager/*/GUI` 与运行时装配逻辑。

## 验证与验收


在仓库根目录运行依赖与回归测试：

    lua .github/tests/deps_check.lua
    lua .github/tests/regression.lua

预期输出包含：

    Dependency self-check passed
    All regression checks passed (30)

手动验收：进入 Eggitor 场景后，点击 `btn_next` 能推进回合，点击 `btn_auto` 能切换自动推进；当出现选择或黑市时，按钮点击仍能触发对应选择，弹窗可关闭，且无新增报错日志。

## 可重复性与恢复


改动以目录重排、文件移动与入口调整为主，可重复执行。若 UI 无响应，可临时恢复旧 UI 事件注册逻辑到 Runtime 并调用；若需回退，恢复旧目录结构与入口文件。

## 产物与备注


产物包含新的目录层级、入口文件、事件路由模块、统一别名模块、更新后的文档与依赖规则。完成后应能在 `Manager/TurnManager/GUI/MainController.lua` 看到 `bind(layer)` 入口，在 `Manager/ChoiceManager/GUI/UIAliases.lua` 看到统一别名解析方法。

依赖与回归测试输出示例：

    Dependency self-check passed
    All regression checks passed (30)

## 接口与依赖


需要保证以下接口对外行为不变，并在重构后仍可被现有调用链使用：

    -- Manager/System/Runtime.lua
    function Runtime.install()

    -- Manager/TurnManager/GUI/MainController.lua
    function MainController.bind(layer)
    function MainController.dispatch_action(layer, action)

    -- Manager/ChoiceManager/GUI/UIAliases.lua
    function UIAliases.resolve(name)

`Manager/**` 规则层仍禁止依赖 `Manager/*/GUI` 与 `Manager/System/Runtime.lua` 之外的装配细节；GUI 仅依赖 `Components`、`Config`、`Library/Monopoly` 与 `Manager/*`。

变更说明：根据“GUI 像 SOE 架构那样放入各个具体 Manager 中”的要求，更新目录树与迁移步骤，并补充 ClassUtil 统一约束。

2026-01-30 更新：完成文件迁移、require 路径更新、UIEventRouter/UIAliases 拆分与文档同步，依赖检查与回归测试通过。原因是按计划落实 SOE 风格目录重组并验证无回归。
