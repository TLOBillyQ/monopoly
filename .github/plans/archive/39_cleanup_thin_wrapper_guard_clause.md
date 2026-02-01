# 清理 thin wrapper 与 guard clause（Manager/Globals/Components）


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 .github/agent/PLANS.md。


## 目的 / 全局视角


清理 Manager、Globals、Components 目录下的薄封装与显式 guard clause，使代码更直白但行为完全不变。用户视角不会看到功能变化，choice 与 popup 的触发逻辑保持一致，物品与黑市等流程保持原有结果。验证方式是运行 .github/tests/regression.lua，或在可运行环境中触发一次需要选择与弹窗的流程，观察 UI 与日志无变化。


## 进度


- [x] (2026-02-01 13:32) 盘点 Manager/Globals/Components 中可清理的 thin wrapper 与 guard clause，并记录目标文件
- [x] (2026-02-01 13:41) 删除薄封装并更新调用点（Tile.from_config、to_number、MarketService.buy、Registry.get）
- [x] (2026-02-01 13:41) 清理 resolve_event_name 与 dispatch_intent 的显式 guard clause（保持行为不变）
- [x] (2026-02-01 13:46) 自测与记录证据（.github/tests/regression.lua 通过）


## 意外与发现


- 观察：运行回归脚本通过。
  证据：`All regression checks passed (30)`。


## 决策日志


- 决策：Globals 目录中的对外接口（Globals/__init.lua 的全局别名、Globals/ECA.lua 的导出函数）保持不动，仅在 Manager/Components 内清理薄封装与 guard clause。
  理由：这些符号可能被引擎或外部脚本依赖，移除风险高；本次目标是低风险精简。
  日期/作者：2026-02-01 Codex
- 决策：ChoiceRegistry、ChanceRegistry、ItemRegistry 暴露 handlers 表并在调用点直接索引，移除 get 薄封装。
  理由：get 仅一处调用且无额外逻辑，直接索引更直白，减少一层函数。
  日期/作者：2026-02-01 Codex
- 决策：resolve_event_name 与 dispatch_intent 保持行为一致，去掉显式 “if not … then return” 的 guard clause，改为 nil-safe 表达式与条件判断。
  理由：避免重复的早退模板，保留所有现有分支与返回值语义。
  日期/作者：2026-02-01 Codex
- 决策：Tile.from_config 直接删除，调用点改用 Tile:new(cfg)。
  理由：Tile 使用 ClassUtils 的构造方式，Tile:new 是最小改动且行为一致。
  日期/作者：2026-02-01 Codex


## 结果与复盘


已完成代码清理并通过回归脚本验证，choice 与 popup 行为保持一致。对照“目的 / 全局视角”无偏差。


## 背景与导读


Manager 目录包含玩法逻辑与 UI 选择流程，Components 目录提供核心数据对象，Globals 目录提供事件与全局别名。本次关注的薄封装主要是只做转发或等价返回的函数，例如 Components/Tile.lua 的 Tile.from_config，以及 Manager/ChoiceManager/Choice/ChoiceHandlers 内部的 to_number 与 MarketService.buy。guard clause 主要集中在各模块的 resolve_event_name 与 dispatch_intent，当前写法以 “if not … then return” 早退为主，但可以用 nil-safe 写法保持语义不变。关键修改会落在 Manager/EffectManager/Effect/EffectPipeline.lua、Manager/TurnManager/Turn/TurnMove.lua、Manager/ItemManager/Item/ItemInventory.lua、Manager/ItemManager/Item/ItemPhase.lua、Manager/ChoiceManager/Choice/ChoiceHandlers/*.lua、Manager/MarketManager/Market/MarketService.lua、Manager/ChoiceManager/Choice/ChoiceRegistry.lua、Manager/ChanceManager/ChanceRegistry.lua、Manager/ItemManager/Item/ItemRegistry.lua、Manager/GameManager/CompositionRoot.lua 与 Components/Tile.lua。


## 里程碑


里程碑一：完成薄封装清理。完成后，Tile.from_config、to_number、MarketService.buy、Registry.get 等不再存在，调用点改为直接调用或表索引，行为保持不变。验证方式是在 .github/tests/regression.lua 中通过对黑市购买、道具使用与选择流程的现有断言，或在可运行环境里人工触发相关流程。

里程碑二：完成 guard clause 清理。完成后，resolve_event_name 与 dispatch_intent 不再含显式早退语句，但对 nil 输入的处理仍然等价；choice 与 popup 的触发行为不变。验证方式与里程碑一相同，并重点观察 need_choice 与 push_popup 的事件触发与 UI 展示。


## 工作计划


先处理 Components/Tile.lua，删除 Tile.from_config 并在 Manager/GameManager/CompositionRoot.lua 中把 Tile.from_config 改为 Tile:new。然后在 Manager/ChoiceManager/Choice/ChoiceHandlers/ItemChoiceHandler.lua 与 Manager/ChoiceManager/Choice/ChoiceHandlers/MarketChoiceHandler.lua 移除 to_number，直接使用 tonumber。接着移除 MarketService.buy 并在 Manager/ChoiceManager/Choice/ChoiceHandlers/MarketChoiceHandler.lua 与 .github/tests/regression.lua 改为调用 MarketService.buy_with_opts。随后在 Manager/ChoiceManager/Choice/ChoiceRegistry.lua、Manager/ChanceManager/ChanceRegistry.lua、Manager/ItemManager/Item/ItemRegistry.lua 暴露 handlers 表并删除 get 函数，在 Manager/ChoiceManager/Choice/ChoiceService.lua、Manager/ChanceManager/Chance.lua、Manager/ItemManager/Item/ItemExecutor.lua 替换为直接索引。最后清理 guard clause：在 Manager/EffectManager/Effect/EffectPipeline.lua、Manager/TurnManager/Turn/TurnMove.lua、Manager/ItemManager/Item/ItemInventory.lua、Manager/ItemManager/Item/ItemPhase.lua、Manager/ChoiceManager/Choice/ChoiceHandlers/*.lua 中，改写 resolve_event_name 为 nil-safe 返回式，改写 dispatch_intent 为先计算 intent，再在分支中判断 intent 是否存在，确保对 nil payload 的行为不变。


## 具体步骤


所有命令在仓库根目录执行。第一步，使用 ripgrep 定位薄封装与 guard clause 位置，例如：

    rg -n "Tile\\.from_config|to_number|MarketService\\.buy|Registry\\.get|resolve_event_name|dispatch_intent" Manager Globals Components .github/tests

第二步，按“工作计划”顺序逐个修改文件，确保每个改动只做等价替换，不引入新逻辑。第三步，重复运行 ripgrep 确认薄封装函数与旧调用点已清理。第四步，执行验证命令并记录输出片段。


## 验证与验收


在仓库根目录运行 lua .github/tests/regression.lua，期望脚本通过或至少不因本次改动新增报错。如果本地环境无法运行回归脚本，则在游戏运行流程中触发一次 need_choice 与 push_popup（如黑市购买或道具选择），确认 choice 面板与弹窗仍正常出现，并在日志中看到对应事件触发记录。


## 可重复性与恢复


所有改动都是局部替换，反复执行不会产生累计副作用。如需回退，可逐文件撤销到上一次提交或使用 git checkout 还原这些文件。验证失败时优先回滚最近改动并逐步重放。


## 产物与备注


完成后，rg 应不再命中以下符号：

    Tile.from_config
    local function to_number
    function MarketService.buy
    function ChoiceRegistry.get
    function ChanceRegistry.get
    function ItemRegistry.get

resolve_event_name 与 dispatch_intent 内部不再包含 “if not kind then return” 或 “if not payload then return” 的显式早退写法。

可在此处补充关键 diff 片段或测试输出证据。

    All regression checks passed (30)


## 接口与依赖


继续使用现有模块与事件名，不引入新依赖。ChoiceRegistry、ChanceRegistry、ItemRegistry 将新增只读的 handlers 字段用于直接索引；dispatch_intent 与 resolve_event_name 的函数签名保持不变，仅调整内部实现。MarketService.buy 被移除后，调用点统一使用 MarketService.buy_with_opts(game, player, product_id, nil)。

更新说明：标记薄封装与 guard clause 清理为已完成，补充 Tile:new 的实现决策，并收敛产物清单以匹配实际范围。
更新说明：移除产物清单的重复条目，保持列表可读性。
