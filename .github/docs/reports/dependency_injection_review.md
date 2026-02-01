# 依赖注入模式审查（大富翁项目）

## 范围与方法

本次审查覆盖 `Manager`、`Globals` 与 `init.lua` 中的依赖引入方式，重点检索服务定位与注册表模式，并阅读核心装配与业务链路。主要检索命令如下：

    rg -n "get_service|get_services|services" Manager init.lua
    rg -n "CompositionRoot|SERVICE_KEY|ServiceKeys" Manager Globals init.lua
    rg -n "register_defaults|register\\(" Manager
    rg -n "setup\\(|deps\\b|inject|injection" Manager

## 模式清单

- 组合根装配 + 服务定位：`Manager/GameManager/CompositionRoot.lua` 统一创建并挂载 `game.services`；`Manager/GameManager/Game.lua` 暴露 `get_service/get_services` 作为服务定位入口；`Globals/ServiceKeys.lua` 提供服务索引；业务侧如 `Manager/TurnManager/Turn/TurnManager.lua`、`Manager/LandManager/Land/Landing.lua`、`Manager/ChanceManager/ChanceRegistry.lua` 等通过 `game:get_service` 获取服务。
- 注册表（Registry）：`Manager/ChoiceManager/Choice/ChoiceRegistry.lua`、`Manager/ItemManager/Item/ItemRegistry.lua`、`Manager/ChanceManager/ChanceRegistry.lua` 使用 `handlers` 表与 `register_defaults` 完成处理器注册。
- 上下文覆盖（context.services）：`Manager/GameManager/Game.lua` 支持 `context.services` 覆盖；`Manager/EffectManager/Effect/Effect.lua` 与 `Manager/ItemManager/Item/ItemPostEffects.lua` 通过 `game:get_services()` 生成或延续上下文服务表。
- 执行器聚合：`Manager/EffectManager/Effect/Effect.lua` 合并 `Landing.executors` 与 `Land.executors`，属于模块级扩展入口，效果类似注册表式注入。

## 可行性评估

组合根装配 + 服务定位适合当前规模的运行时需求，能集中管理服务生命周期并降低构造成本，可行性高。主要风险是依赖隐藏与运行时缺失服务导致的空指针调用，以及服务键为数字常量时的维护成本。建议保留该模式，但新增服务时必须同步更新 `Globals/ServiceKeys.lua` 与 `Manager/GameManager/CompositionRoot.lua`，并为启动流程增加完整性检查。

注册表模式适合道具、选择、机会卡等数据驱动场景，可行性中高。风险在于全局状态与注册顺序依赖，测试环境若复用同一 Lua 虚拟机可能出现污染。建议只在装配阶段或模块初始化时调用 `register_defaults`，避免在业务热路径重复注册，并在测试中显式重启或清理注册表。

上下文覆盖提供了替换服务的便利性，可用于 AI 或测试的局部替换，可行性中等。风险是上下文只覆盖部分服务时导致行为不一致。建议仅在需要替换时传入完整服务表，避免只替换单个服务而遗漏其他依赖。

执行器聚合属于轻量的插件化扩展方式，可行性中高。风险是模块加载顺序影响可见性。建议保持执行器定义集中且在启动期加载，避免运行期动态追加。

## 风险与建议

当前最大的风险是“隐式依赖难以追踪”。`game:get_service` 在业务层分散使用，导致依赖来源不直观。建议为每个使用服务定位的模块补充注释说明依赖，或在文档中维护服务使用清单。其次是注册表的全局状态风险，应尽量保持注册表只初始化一次，并在测试中避免跨用例共享。

## 后续改进候选

短期建议补充服务完整性检查（启动时检查 `game.services` 是否包含全部 `SERVICE_KEY`），并在文档层面维护“服务 -> 使用模块”的映射表。中期可以将高频使用的服务依赖改为显式参数传入（例如 TurnManager/Movement 等），降低服务定位的隐式耦合。长期可考虑引入更清晰的服务接口层，但需结合 Lua 环境的模块加载特性谨慎评估。
