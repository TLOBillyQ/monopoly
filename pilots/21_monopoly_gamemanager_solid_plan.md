# GameManager SOLID 拆分与清理计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。本仓库的 PLANS 位于 `.agent/PLANS.md`，本文件必须遵循其要求维护。


## 目的 / 全局视角


目标是在不改变玩法结果与对外接口的前提下，让 `Manager/GameManager` 按实际玩法职责拆分、合并并删除文件，降低职责耦合、减少单文件过载，同时保持启动与测试行为一致。完成后应能通过 `init.lua` 启动游戏，且在仓库根目录运行 `lua tests/acceptance.lua` 输出 `ok - acceptance suite`，并且 `lua tests/entry_smoke_test.lua` 仍能加载入口模块。


## 进度


- [x] (2026-01-30 18:45) 盘点 GameManager 目录与主要调用点，整理当前职责与依赖关系。
- [x] (2026-01-30 19:03) 拆分/合并方案落地，更新 require 与入口聚合，删除冗余文件。
- [x] (2026-01-30 19:03) 通过验收与入口加载测试，补充结果与复盘。


## 意外与发现


观察：`Manager/GameManager/BoardFactory.lua` 只有 `CompositionRoot.lua` 调用，属于单点工厂封装。证据：执行 `rg "BoardFactory" -n` 仅命中 `Manager/GameManager/BoardFactory.lua` 与 `Manager/GameManager/CompositionRoot.lua`。

观察：`Manager/GameManager/Game.lua` 同时包含状态持久化、棋盘占位维护、胜负判定、UI 端口通知与回合分发等多类职责。证据：文件内既有 `_store_set` 和 `update_player_position`，也有 `check_victory` 与 `set_tile_owner`。

观察：`Manager/GameManager/Agent.lua` 被 TurnManager、Item、Market 等多处引用，但文件内混合了自动选择与目标评估逻辑，后续维护难以定位。证据：`rg "Manager.GameManager.Agent" -n Manager` 命中 Turn/Item/Market 多处引用。

观察：验收测试会依次执行 `deps_check` 与 `regression`，通过后输出 `ok - acceptance suite`。证据：运行 `lua tests/acceptance.lua` 输出 `ok - acceptance suite`。


## 决策日志


决策：保持 `Game` 对外方法名与语义不变，仅通过提取实现细节来拆分职责。理由：`Game` 在多个 Manager 与测试中被直接调用，保持 API 稳定能降低改动面与回归风险。日期/作者：2026-01-30 / Codex。

决策：将 `BoardFactory` 合并进 `CompositionRoot` 并删除独立文件。理由：只有单一调用点，合并可减少文件数量并贴合“组装即创建棋盘”的实际流程。日期/作者：2026-01-30 / Codex。

决策：把 `Game` 的“状态写入/占位维护”与“胜负判定”拆到独立模块，以混入方式回挂到 `Game`。理由：这些都是实际玩法中的独立责任，拆分后更容易定位变更且不引入抽象接口。日期/作者：2026-01-30 / Codex。

决策：提取 `Agent` 的目标评估逻辑到独立模块，并在 `Agent` 中集中处理“自动选择”流程。理由：AI 目标评估是可复用的玩法规则，拆分后可以独立测试且减少 `Agent` 内部复杂度。日期/作者：2026-01-30 / Codex。


## 结果与复盘


已完成 GameManager 拆分与合并：`BoardFactory` 内联进 `CompositionRoot` 并删除；`Game` 状态写入/占位维护与胜负判定拆到 `GameState`、`GameVictory`；`Agent` 目标评估迁入 `AgentTargeting`，对外方法保留。运行 `lua tests/acceptance.lua` 与 `lua tests/entry_smoke_test.lua` 均通过，入口可加载且回归无异常。当前无遗留项。


## 背景与导读


`Manager/GameManager` 当前包含游戏核心的装配、AI、机会卡与破产处理等逻辑。关键文件与职责如下，这些文件的行为必须保持一致，只调整组织方式：

    Manager/GameManager/Game.lua - 游戏核心对象，维护 store、玩家与棋盘状态，提供回合分发与胜负判定。
    Manager/GameManager/CompositionRoot.lua - 组装依赖，创建棋盘、玩家、随机数与回合管理器。
    Manager/GameManager/BoardFactory.lua - 通过配置创建棋盘（仅被 CompositionRoot 调用）。
    Manager/GameManager/Agent.lua - AI 自动选择与目标评估。
    Manager/GameManager/Chance.lua - 机会卡触发入口，调用 ChanceRegistry。
    Manager/GameManager/ChanceRegistry.lua - 机会卡效果注册与默认效果。
    Manager/GameManager/BankruptcyService.lua - 破产清算与玩家出局。
    Manager/GameManager/PlayerEffects.lua / PlayerVehicle.lua - 玩家能力混入。
    Manager/GameManager/Constants.lua - 回合上限与道具 ID 常量。
    Manager/GameManager/Entry.lua - 游戏启动入口。

这些模块被 TurnManager、ItemManager、MarketManager、LandManager 与测试脚本调用。拆分与合并必须保证 `tests/deps_check.lua` 的依赖规则仍然满足，尤其是 `CompositionRoot.lua` 仍需显式 require 回合阶段模块。


## 工作计划


先在实现前明确现有调用点与公开接口，确保拆分不会改变外部行为。具体做法是用 `rg` 盘点 `GameManager` 模块在 `Manager/` 与 `tests/` 内的引用，并逐项记录哪些函数被外部依赖。完成盘点后，按“只拆实现、不改行为”的策略执行三个结构调整：合并 `BoardFactory`；抽离 `Game` 中的状态写入与胜负判定为独立模块并混入；抽离 `Agent` 的目标评估逻辑为独立模块并保留 `Agent` 作为自动选择入口。所有拆分后的模块仍位于 `Manager/GameManager/` 下，`__init.lua` 统一入口保持可加载。最后更新 require 路径与聚合文件，运行依赖检查与回归测试确认行为不变。


## 具体步骤


在仓库根目录执行依赖盘点，记录 `GameManager` 相关调用点与 `Game` 方法使用方：

    rg "Manager.GameManager" -n Manager tests
    rg "game:" -n Manager tests

先合并 `BoardFactory`：把 `Manager/GameManager/BoardFactory.lua` 的内容内联进 `CompositionRoot.lua` 的棋盘创建逻辑，删掉 `BoardFactory.lua`，并移除 `Manager/GameManager/__init.lua` 中对它的 require。调整时要保留 `CompositionRoot.lua` 对 `TurnStart/TurnRoll/TurnMove/TurnLand/TurnPost/TurnEnd` 的显式 require，以满足 `tests/deps_check.lua` 的校验。

新增 `Manager/GameManager/GameState.lua`，把 `Game.lua` 内与状态持久化和占位维护相关的方法迁入该文件并以表形式导出；`Game.lua` 通过遍历表把方法挂回类上，确保方法名与行为不变。范围包含 `_store_set`、玩家状态/属性更新、tile 更新、动画队列、占位表维护、`alive_players` 与 `current_player` 等与状态相关的方法。

新增 `Manager/GameManager/GameVictory.lua`，把 `check_victory` 及其辅助函数迁入该文件，使用与现有实现完全相同的判定规则（回合上限、资产比较、胜者日志）。`Game.lua` 保留 `check_victory` 方法名，但实现委托给该模块，确保外部调用不变。

新增 `Manager/GameManager/AgentTargeting.lua`，把 `Agent.lua` 中“目标评估”相关方法与其私有辅助函数迁入该文件，包含远程骰子落点模拟、机会卡/道具目标挑选、路障/怪物目标选择等。`Agent.lua` 保留 `auto_action_for_choice` 与 `is_auto_player`，并通过调用 `AgentTargeting` 保持原有对外函数不变。

更新 `Manager/GameManager/__init.lua` 引入新模块，并确保外部 require 路径无变化；若有测试或文档直接引用被删除/移动的模块，补充替换到新模块或保留兼容导出。


## 验证与验收


在仓库根目录执行下列命令，确认输出与预期一致：

    lua tests/acceptance.lua

预期看到结尾输出 `ok - acceptance suite` 且无报错。再单独执行入口加载测试，确认入口仍可被 require：

    lua tests/entry_smoke_test.lua

预期输出包含 `ok - entry smoke test`。若依赖检查失败，优先回查 `CompositionRoot.lua` 的 require 列表是否满足 `tests/deps_check.lua` 的要求。


## 可重复性与恢复


本计划的拆分与合并不依赖外部环境，重复执行时只会覆盖相同文件。若中途失败，可通过 `git status` 查看变更，再用 `git checkout -- <file>` 回退到初始状态；删除的文件可通过版本控制恢复。任何新文件生成后应立即纳入测试验证，避免未验证的中间状态。


## 产物与备注


产物包含新增与删除的文件，以及对 `Game.lua` 与 `CompositionRoot.lua` 的结构调整。完成后目录应包含如下变化：

    新增: Manager/GameManager/GameState.lua
    新增: Manager/GameManager/GameVictory.lua
    新增: Manager/GameManager/AgentTargeting.lua
    删除: Manager/GameManager/BoardFactory.lua
    修改: Manager/GameManager/Game.lua
    修改: Manager/GameManager/CompositionRoot.lua
    修改: Manager/GameManager/__init.lua


## 接口与依赖


以下接口必须保持名称与语义不变，且不引入新的跨层依赖：

    Game.new(opts) -> Game
    Game:advance_turn()
    Game:dispatch_action(action)
    Game:check_victory() -> boolean
    Game:current_player() -> Player
    Game:alive_players() -> Player[]
    Game:set_player_status(player, key, value)
    Game:set_player_seat(player, seat_id)
    Game:set_player_eliminated(player, eliminated)
    Game:set_player_property(player, tile_id, owned)
    Game:sync_player_inventory(player)
    Game:update_tile(tile, updates)
    Game:set_tile_owner(tile, owner_id)
    Game:set_tile_level(tile, level)
    Game:reset_tile(tile)
    Game:update_player_position(player, new_index)
    Game:queue_action_anim(payload) -> payload?
    Game:get_service(key, context?) -> any
    Game:get_services(context?) -> table
    Game:pending_choice() -> table?

    CompositionRoot.assemble(opts, GameClass) -> Game
    CompositionRoot.snapshot_inventory(inv) -> table

    Chance.resolve(game, player, card, context) -> any
    ChanceRegistry.register(effect, handler)
    ChanceRegistry.get(effect) -> handler?

    Agent.is_auto_player(player) -> boolean
    Agent.auto_action_for_choice(game, choice) -> table?
    Agent.pick_target_player(game, player, item_id, options) -> Player?
    Agent.pick_remote_dice_value(game, player, dice_count) -> number?, Tile?
    Agent.pick_roadblock_target(game, player) -> number?
    Agent.pick_demolish_target(game, player, distance) -> number?

    BankruptcyService.eliminate(game, player)
    Entry.install() -> layer
    Constants.turn_limit / Constants.item_ids 保持现有字段

新模块 `GameState`、`GameVictory`、`AgentTargeting` 不对外暴露新 API，只承载现有实现拆分后的逻辑，避免引入额外抽象层。


改动记录：完成拆分合并与测试验证，更新进度、意外与发现、结果与复盘（补充验收证据）。
