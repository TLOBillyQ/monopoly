# 里程碑 3：注册化道具 / 机会卡 / 选择处理器（子计划）


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 `.agent/PLANS.md` 的全部要求，并作为总计划 `pilots/15_monopoly_solid_refactor_plan.md` 的子计划。


## 目的 / 全局视角


本里程碑把道具、机会卡、选择处理器从“硬编码表”迁移到“注册表”机制。完成后，新增道具或机会卡时，只需要新建注册文件并调用 `register`，无需改动 `ItemExecutor`、`Chance`、`ChoiceService` 的核心逻辑。这样可降低核心文件被频繁修改的风险，提高扩展性。

可观察结果：
1) 默认玩法保持不变；
2) 新增一个测试注册项，能被执行并输出验证结果；
3) 回归测试通过。


## 进度


- [x] (2026-01-30 17:53Z) 新增注册表模块并完成默认注册迁移
- [x] (2026-01-30 17:53Z) 改造 `ItemExecutor`、`Chance`、`ChoiceService` 依赖注册表
- [x] (2026-01-30 17:53Z) 新增注册测试并回归验证


## 意外与发现


暂无。若发现注册顺序影响行为或出现重复注册覆盖问题，必须记录并说明处理策略。


## 决策日志


- 决策：注册表提供 `register_defaults()`，由 `CompositionRoot` 或 `ChoiceService.setup` 调用一次。
  理由：保持初始化集中，避免分散调用。
  日期/作者：2026-01-30 / Codex

- 决策：默认注册沿用现有函数实现，保证行为不变。
  理由：迁移期间避免引入新逻辑风险。
  日期/作者：2026-01-30 / Codex

- 决策：道具/机会卡默认注册在 `CompositionRoot` 中调用，选择处理器默认注册在 `ChoiceService.setup` 中调用。
  理由：道具与机会卡不依赖 setup 的 helper，保持装配集中；选择处理器依赖 helper，继续由 setup 负责。
  日期/作者：2026-01-30 / Codex


## 结果与复盘


已完成注册表迁移：道具、机会卡、选择处理器都改为注册表读取，新增扩展测试验证注册入口可用；回归测试通过。后续新增玩法只需注册处理器，不再改核心分发表。


## 背景与导读


当前实现中：
`Manager/ItemManager/Item/ItemExecutor.lua` 使用 `item_handlers` 静态表绑定道具处理逻辑。
`Manager/GameManager/Chance.lua` 使用 `handlers` 静态表处理机会卡效果。
`Manager/ChoiceManager/Choice/ChoiceService.lua` 通过 `setup` 绑定多个 handler group。

这些位置需要在新增玩法时改动核心文件，违反开闭原则。本里程碑引入注册表并迁移现有默认实现。


## 工作计划


先新增注册表模块，再逐步替换调用点。注册表必须支持“注册默认处理器”和“按 key 获取处理器”。迁移时，保留原有函数实现，只是把它们从静态表搬到注册函数中。最后补充测试，验证注册入口可扩展。


## 具体步骤


1) 新增注册表模块。
   - 新建 `Manager/ItemManager/Item/ItemRegistry.lua`。
   - 新建 `Manager/GameManager/ChanceRegistry.lua`。
   - 新建 `Manager/ChoiceManager/Choice/ChoiceRegistry.lua`。
   - 每个注册表提供 `register/get/register_defaults`。

2) 迁移道具处理。
   - 把 `ItemExecutor.lua` 中 `item_handlers` 逻辑改为 `ItemRegistry.get(item_id)`。
   - 在 `ItemRegistry.register_defaults()` 内注册原有处理器（遥控骰子、路障、怪兽、导弹、目标玩家类道具）。

3) 迁移机会卡处理。
   - 把 `Chance.lua` 中 `handlers` 表迁移到 `ChanceRegistry.register_defaults()`。
   - `Chance.resolve` 调用 `ChanceRegistry.get(effect)`。

4) 迁移选择处理器。
   - 把 `ChoiceService.setup` 里的 `merge_handlers` 改为向 `ChoiceRegistry` 注册。
   - `ChoiceService.resolve` 通过 `ChoiceRegistry.get(choice.kind)` 获取处理器。

5) 新增测试。
   - 新建 `tests/registry_extension_test.lua`，注册一个虚拟道具或机会卡处理器并断言执行。


## 验证与验收


运行回归测试：
    lua tests/deps_check.lua
    lua tests/regression.lua

运行新增注册测试：
    lua tests/registry_extension_test.lua
    ok - registry extension works

人工验证：进入游戏流程后，道具/机会卡仍能正常触发（由回归测试日志或手动触发验证）。


## 可重复性与恢复


注册表迁移为增量改动，可随时回退到原静态表方式。若出现行为差异，先检查默认注册是否完整，再逐步恢复旧逻辑。


## 产物与备注


预期新增或改动文件：
`Manager/ItemManager/Item/ItemRegistry.lua`
`Manager/GameManager/ChanceRegistry.lua`
`Manager/ChoiceManager/Choice/ChoiceRegistry.lua`
`Manager/ItemManager/Item/ItemExecutor.lua`
`Manager/GameManager/Chance.lua`
`Manager/ChoiceManager/Choice/ChoiceService.lua`
`tests/registry_extension_test.lua`

测试输出示例：
    lua tests/registry_extension_test.lua
    ok - registry extension works


## 接口与依赖


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

默认注册必须完整覆盖现有玩法。


改动记录：本计划为首次版本，尚未实施。

改动记录：完成注册表模块落地、默认注册迁移与测试验证。
