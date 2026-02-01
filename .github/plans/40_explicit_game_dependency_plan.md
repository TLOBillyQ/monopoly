# 明确 Game 依赖并去除注入与间接引用


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 .github/agent/PLANS.md。


## 目的 / 全局视角


移除 GameplayLoop 中通过 state 间接持有 game 的做法，改为显式传入或直接引用 game；同时评估 Manager 目录内的依赖注入模式，改为显式依赖暴露，避免通过 setup/deps 注入。用户视角行为不变：回合推进、动画等待、choice/popup 流程、自动行动与 UI 事件路由保持一致。验证方式是运行 tests/regression.lua 并观察现有回归脚本全部通过。


## 进度


- [ ] (2026-02-01 13:55) 盘点 GameplayLoop 与 UIEventRouter 的 game 间接引用与调用链
- [ ] (2026-02-01 13:55) 盘点 Manager 目录内 deps/setup 注入点并确定替换策略
- [ ] (2026-02-01 13:55) 按策略改造 GameplayLoop 与 UIEventRouter 调用签名
- [ ] (2026-02-01 13:55) 去除 ChoiceService/ItemExecutor/ItemRegistry/ItemStrategy 的 deps 注入
- [ ] (2026-02-01 13:55) 自测并记录证据（tests/regression.lua）


## 意外与发现


- 暂无。


## 决策日志


- 决策：GameplayLoop 相关函数改为显式传入 game，不再通过 state.game 获取。
  理由：state 只承载 UI 状态，game 作为核心依赖应在函数签名中直观体现。
  日期/作者：2026-02-01 Codex
- 决策：去除 ChoiceService.setup 和各类 deps 表注入，改为模块内显式 require 或显式参数传入。
  理由：避免隐藏依赖来源，减少初始化顺序耦合。
  日期/作者：2026-02-01 Codex


## 结果与复盘


未开始。完成后补充变更范围、验证结果与经验复盘，并对照“目的 / 全局视角”确认行为一致。


## 背景与导读


当前 GameplayLoop 通过 state.game 访问核心游戏对象，UIEventRouter 也只接受 state，因此 game 依赖在调用链中被隐藏。Manager 下还存在 deps/setup 注入：ChoiceService.setup 在 CompositionRoot 中注入 executor/inventory/strategy 等模块；ItemExecutor、ItemRegistry、ItemStrategy 通过 deps 参数再传递依赖。此类隐式依赖导致调用点难以直观看到依赖来源。关键文件包括：Manager/TurnManager/GameplayLoop.lua、Manager/TurnManager/GUI/UIEventRouter.lua、init.lua、Manager/GameManager/CompositionRoot.lua、Manager/ChoiceManager/Choice/ChoiceService.lua、Manager/ChoiceManager/Choice/ChoiceRegistry.lua、Manager/ItemManager/Item/ItemExecutor.lua、Manager/ItemManager/Item/ItemRegistry.lua、Manager/ItemManager/Item/ItemStrategy.lua。


## 工作计划


先梳理 GameplayLoop 与 UIEventRouter 的调用链，确定所有以 state.game 取用 game 的位置，并统一改为显式传参；同步修改 init.lua 的 game 初始化与 tick 调用方式。接着梳理 Manager 中的 deps/setup 注入点，决定使用显式 require 或函数签名参数替换 deps 表；移除 ChoiceService.setup 与 CompositionRoot 中的注入逻辑，改为在 ChoiceService 内部显式依赖或由调用点传参。最后全局检查是否还有 state.game 与 deps/setup 残留，确保行为不变。


## 具体步骤


所有命令在仓库根目录执行。

1) 盘点 state.game 使用点与调用链。

    rg -n "state\\.game" Manager/TurnManager/GameplayLoop.lua
    rg -n "GameplayLoop\\." Manager/TurnManager/GUI/UIEventRouter.lua init.lua

2) 盘点 deps/setup 注入点。

    rg -n "\\bdeps\\b|setup\\(" Manager
    rg -n "ChoiceService\\.setup" Manager/GameManager/CompositionRoot.lua

3) 改造 GameplayLoop：为以下函数新增 game 参数（示例次序为 game, state, ...），并移除内部的 state.game 读取。

    - GameplayLoop.set_game
    - GameplayLoop.new_game
    - GameplayLoop.step_auto_runner
    - GameplayLoop.step_choice_timeout
    - GameplayLoop.step_move_anim
    - GameplayLoop.step_action_anim
    - GameplayLoop.step_turn
    - GameplayLoop.dispatch_action
    - GameplayLoop.tick

   同步修改 UIEventRouter.bind 与其内部对 GameplayLoop.dispatch_action 的调用，使 game 由调用点传入而不是通过 state 获取；修改 init.lua 在 GAME_INIT 时创建 game 后显式传入。

4) 去除 deps/setup 注入。

   - ChoiceService：删除 setup 与模块级 deps 状态，直接 require 所需模块或把依赖作为函数参数显式传入；更新 ChoiceRegistry.register_defaults 的调用方式。
   - ItemExecutor：去掉 deps 参数，直接使用 ItemInventory 与 ItemStrategy，保持行为不变。
   - ItemRegistry：去掉 deps 传递链，直接引用 Inventory/Strategy/Demolish 等模块；更新调用点。
   - ItemStrategy：移除 deps 参数，直接使用 ItemInventory/ItemExecutor/Demolish；替换 deps.find_monster_target 为 Demolish.find_target。
   - CompositionRoot：删除 ChoiceService.setup 注入，保留必要的 register_defaults 调用时机。

5) 全局复查残留。

    rg -n "state\\.game" Manager/TurnManager/GameplayLoop.lua
    rg -n "\\bdeps\\b|setup\\(" Manager


## 验证与验收


在仓库根目录运行回归脚本，期望全部通过。

    lua tests/regression.lua

预期输出包含：

    All regression checks passed (30)


## 可重复性与恢复


改动为局部签名替换与依赖引用调整，可重复执行。若中途失败，可按文件回退到修改前版本，再逐步重放每个步骤定位问题。


## 产物与备注


完成后应满足：

    GameplayLoop.lua 不再出现 state.game 读取
    UIEventRouter.bind 需要显式传入 game
    ChoiceService 不再包含 setup/deps 注入
    ItemExecutor/ItemRegistry/ItemStrategy 不再出现 deps 参数

可在此处补充关键 diff 或测试输出证据。


## 接口与依赖


需要明确的新接口（示例签名，最终以实现为准）：

    GameplayLoop.tick(game, state, dt)
    GameplayLoop.dispatch_action(game, state, action)
    UIEventRouter.bind(state, game)

ChoiceService、ItemExecutor、ItemRegistry、ItemStrategy 依赖应通过显式 require 或显式参数暴露，不再通过 setup/deps 注入。
