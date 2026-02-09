# 去除 Manager 命名的重构计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。本计划必须遵循 `.agents/PLANS.md` 的要求。


## 目的 / 全局视角


本次改动把 `src/` 内所有包含 `Manager` 的模块与标识符改为更贴合职责的命名，同时保证功能不变。完成后可以从 `Game` 流程推进、移动、黑市购买、破产清算等关键流程观察到行为一致，且代码中不再出现 `Manager` 命名（第三方 `UIManager` 除外）。


## 进度


- [x] (2026-02-09 11:18+08:00) 创建可执行计划并明确改名范围与验证方式。
- [x] (2026-02-09 11:28+08:00) 完成模块重命名、引用更新、`game.turn_flow` 替换。
- [ ] (2026-02-09 11:28+08:00) 运行 `.agents/tests/all.lua`，当前失败，原因见“意外与发现”。


## 意外与发现


运行 `.agents/tests/all.lua` 时回归测试中断，提示 `Choice.open requires game.store`，同时测试脚本依赖 `src.core.Store` 与 `src.core.StorePaths` 但仓库内不存在这些文件。证据：`lua .agents/tests/all.lua` 报错包含 `.agents/tests/regression.lua:126: Choice.open requires game.store`。


## 决策日志


决策：采用 TurnFlow / Movement / Market / Bankruptcy / ChoiceResolver 作为新模块命名，并把 `game.turn_manager` 改为 `game.turn_flow`。理由：命名更贴合职责且避免 “Manager” 泛化用词。日期/作者：2026-02-09 / Codex。


## 结果与复盘


已完成 `src/` 内的命名去除与引用更新，第三方 `UIManager` 保持不变。测试未通过，需先解决 `Store` 相关依赖缺失或调整测试环境。


## 背景与导读


本次重构把 `src/game/turn/TurnManager.lua`、`src/game/movement/MovementManager.lua`、`src/game/market/MarketManager.lua`、`src/game/game/BankruptcyManager.lua`、`src/game/choice/ChoiceManager.lua` 重命名为 `src/game/turn/TurnFlow.lua`、`src/game/movement/Movement.lua`、`src/game/market/Market.lua`、`src/game/game/Bankruptcy.lua`、`src/game/choice/ChoiceResolver.lua`。这些模块由 `CompositionRoot` 组装，并通过 `Game` 对外调用，其中 `Game` 现在依赖 `game.turn_flow` 驱动回合流程。相关引用分布在 `src/game/game/CompositionRoot.lua`、`src/game/game/Game.lua`、`src/game/turn/TurnMove.lua`、`src/game/land/Landing.lua` 等文件中。


## 工作计划


先重命名五个模块文件，保证路径与返回表名同步，再逐一更新所有 `require` 路径、局部变量名与 `game` 字段名。`TurnManager` 类名与报错字符串同步改为 `TurnFlow`。最后全仓库搜索 `Manager` 关键字确认 `src/` 内残留已清理，同时保持第三方 `UIManager` 调用不变。


## 具体步骤


在仓库根目录清空并重写 `.agents/PLAN_CURRENT.md`，写入本计划内容并保持章节完整。

重命名文件，使用 `git mv` 保留历史：

    git mv src/game/turn/TurnManager.lua src/game/turn/TurnFlow.lua
    git mv src/game/movement/MovementManager.lua src/game/movement/Movement.lua
    git mv src/game/market/MarketManager.lua src/game/market/Market.lua
    git mv src/game/game/BankruptcyManager.lua src/game/game/Bankruptcy.lua
    git mv src/game/choice/ChoiceManager.lua src/game/choice/ChoiceResolver.lua

更新所有引用与命名，包括 `require` 路径、局部变量名、`game.turn_flow` 的读写，确保逻辑一致。完成后用 `rg -n "Manager" src` 验证 `src/` 内不再出现 `Manager`。


## 验证与验收


在仓库根目录运行测试脚本：

    lua .agents/tests/all.lua

预期输出包含：

    All tests passed

手工验证时，启动一局游戏，观察回合推进、移动、黑市购买与破产流程与改名前一致。


## 可重复性与恢复


上述重命名与引用更新可重复执行，若需要回退，可通过 `git status` 确认改动并使用 `git checkout -- <file>` 或 `git restore <file>` 逐一恢复。为避免误删第三方 API 标识，本次不修改任何 `UIManager` 相关代码。


## 产物与备注


本次变更应仅触及 `src/` 相关 Lua 文件及 `.agents/PLAN_CURRENT.md`。完成后可用 `rg -n "TurnFlow" src/game/turn/TurnFlow.lua` 等命令验证新命名生效。


## 接口与依赖


`src/game/turn/TurnFlow.lua` 继续导出与原 `TurnManager` 相同的实例方法集合（例如 `init`、`dispatch`、`run_until_wait`、`run_turn`、`next_player`、`_build_flow`），`src/game/choice/ChoiceResolver.lua` 继续导出 `resolve(game, choice, action)`，`src/game/movement/Movement.lua` 继续导出 `move(game, player, steps, opts)`，`src/game/market/Market.lua` 继续导出 `list_buyable`、`build_choice_spec`、`buy_with_opts`、`auto_buy`，`src/game/game/Bankruptcy.lua` 继续导出 `eliminate(game, player)`。依赖仍然来自仓库内部 Lua 模块与 `Config` 配置，不引入新依赖。


修改说明：首次创建可执行计划以指导“去除 Manager 命名”的重构执行。
修改说明：更新进度与发现，记录测试失败原因与当前状态。
