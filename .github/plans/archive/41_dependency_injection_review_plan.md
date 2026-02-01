# 依赖注入模式审查与可行性评估计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 .github/agent/PLANS.md。


## 目的 / 全局视角


对本项目当前的依赖注入模式做一次可追溯的审查，明确哪些地方在“注入”、用什么方式注入、为何这样做，并评估这些模式是否适合继续保留或需要替换。最终产物是一份文档，写清现状、风险、可行性与建议，让后续重构时可以直接按文档执行或对照。可观察结果是 `.github/docs/reports/dependency_injection_review.md` 存在且内容覆盖关键模块与结论。


## 进度


- [x] (2026-02-01 16:25+08:00) 扫描并记录项目中的依赖注入/服务定位/注册表模式
- [x] (2026-02-01 16:35+08:00) 逐模块梳理依赖来源与调用链并形成草稿
- [x] (2026-02-01 16:45+08:00) 评估可行性与风险，写出明确结论与建议
- [x] (2026-02-01 16:55+08:00) 完成文档落地并自检覆盖范围


## 意外与发现


- 观察：Manager 目录内已不再出现 setup/deps 注入关键字，当前主要是 CompositionRoot 服务表与 Registry 注册表。
  证据：`rg -n "setup\\(|deps\\b|inject|injection" Manager` 无命中。


## 决策日志


- 决策：评估结果落在 `.github/docs/reports/dependency_injection_review.md`。
  理由：该目录已有类似评审类文档，便于统一查看与引用。
  日期/作者：2026-02-01 / Codex
- 决策：评估结论围绕“组合根+服务定位、注册表、上下文覆盖、执行器聚合”四类模式展开。
  理由：这四类已覆盖当前项目全部依赖注入形态，且有明确代码证据。
  日期/作者：2026-02-01 / Codex


## 结果与复盘


已形成依赖注入审查文档，覆盖服务定位、注册表、上下文覆盖与执行器聚合，并给出可行性结论与建议。文档可直接用于后续重构或新增服务时的检查清单，且引用了主要模块路径作为证据。


## 背景与导读


项目当前已经存在多种“依赖引入”方式：`Manager/GameManager/CompositionRoot.lua` 负责集中装配并填充 `Game` 的 services 映射；`Manager/GameManager/Game.lua` 通过 `get_service`/`get_services` 提供服务定位入口；`Manager/ChoiceManager/Choice/ChoiceRegistry.lua` 和 `Manager/ItemManager/Item/ItemRegistry.lua` 以注册表方式提供策略与处理器；以及 `Globals/ServiceKeys.lua` 等常量表用于服务索引。这些模式都属于不同形态的“依赖注入”或“服务定位”，需要统一审查与评估。


## 工作计划


先用检索命令建立依赖注入相关模式清单，锁定涉及的模块与调用链；然后逐个阅读 CompositionRoot、Game、各类 Registry、以及核心业务流程（如 TurnManager、Choice、Item、Effect、Land 等）中通过服务定位或注册表获取依赖的代码，记录依赖来源与生命周期。接着以“是否需要显式化依赖、是否引入隐藏耦合、是否容易造成循环依赖、是否影响测试替换与热更”为评估维度，逐条给出可行性判断与建议，强调哪些可以继续保留、哪些应当替换或补充约束。最后将结果写入指定文档，确保每个结论都有对应的代码证据路径。


## 具体步骤


在仓库根目录执行检索并记录命中位置，形成审查清单：

    rg -n "get_service|get_services|services" Manager init.lua
    rg -n "CompositionRoot|SERVICE_KEY|ServiceKeys" Manager Globals init.lua
    rg -n "register_defaults|register\\(" Manager
    rg -n "setup\\(|deps\\b|inject|injection" Manager

打开清单中的关键文件，记录每个模块的依赖来源、注入方式与作用范围。重点文件应至少包含 `Manager/GameManager/CompositionRoot.lua`、`Manager/GameManager/Game.lua`、`Manager/ChoiceManager/Choice/ChoiceRegistry.lua`、`Manager/ItemManager/Item/ItemRegistry.lua`、`Globals/ServiceKeys.lua` 以及所有通过 `get_service` 调用服务的业务模块。

根据记录为每种模式写评估结论，结论必须覆盖可行性、风险、替代成本与可执行建议。建议采用统一模板描述，避免只有结论没有证据。

在 `.github/docs/reports/dependency_injection_review.md` 写入最终文档。文档应包含范围与方法、模式清单、可行性评估、风险与建议、后续改进候选等小节，并在每个小节内标注相关文件路径作为证据。


## 验证与验收


确认文档文件存在且内容覆盖主要模式与结论，且至少引用了 CompositionRoot、Game 服务定位、Registry 注册表三类模式。可通过以下命令检查：

    rg -n "CompositionRoot|get_service|Registry|服务定位|注册表" .github/docs/reports/dependency_injection_review.md

若命中为空或缺少关键模式描述，则视为未完成。


## 可重复性与恢复


本计划仅新增评审文档，不影响运行代码。若需要回退，可删除 `.github/docs/reports/dependency_injection_review.md` 并重新按本计划执行审查。


## 产物与备注


最终产物为评审文档，路径如下：

    .github/docs/reports/dependency_injection_review.md

文档应包含可引用的证据片段，例如：

    Manager/GameManager/Game.lua: get_service/get_services 提供服务定位入口

变更记录：补齐实际执行结果、关键发现与结论，确保计划作为活文档可独立复现审查过程。


## 接口与依赖


本任务仅依赖仓库内 Lua 代码与配置文件，无需外部服务。检索与阅读工具建议使用 `rg` 与文本查看命令。评估时需要明确 `Game:get_service(key, context)` 与 `CompositionRoot.assemble(opts, game)` 的调用语义，并引用 `Globals/ServiceKeys.lua` 的服务索引常量作为证据。
