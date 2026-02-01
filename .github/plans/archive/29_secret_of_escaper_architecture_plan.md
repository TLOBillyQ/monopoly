# SecretOfEscaper 架构与 Library 研究计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。本文件遵循 `.agent/PLANS.md` 的规范。


## 目的 / 全局视角


学习 `.github/docs/SecretOfEscaper` 的架构与功能，尤其是 `Library` 的设计与实际使用方式，同时补充当前 Monopoly 现有实现的结构与关键调用链，产出可复用的研究笔记，为后续 Monopoly 全局重构提供直接参考。完成后应能通过一份笔记快速回答入口流程、各目录职责、Library 模块的核心 API 与在玩法中的调用链，并能指出与本仓库 Monopoly 现有实现的对照点。验证方式是生成 `.github/docs/SecretOfEscaper/architecture_study.md` 并通过搜索命令交叉核对引用。


## 进度


- [x] (2026-01-31 13:15Z) 阅读入口与初始化，确认启动流程与全局变量初始化顺序
- [x] (2026-01-31 13:15Z) 梳理 Library 模块职责与关键 API，覆盖 Utils、ClassUtils、UIManager、Behavior、NavMesh、Bincore
- [x] (2026-01-31 13:15Z) 追踪 Manager/Components 对 Library 的调用链，记录典型用法与文件位置
- [x] (2026-01-31 13:15Z) 产出研究笔记并对照 Monopoly 现有模块给出差异与可迁移点
- [x] (2026-01-31 13:15Z) 补充 Monopoly 现有实现的入口流程、核心模块与调用链，沉淀在同一份笔记中
- [x] (2026-01-31 12:55Z) 深挖 Monopoly 的 Choice/Item 调用链并写入研究笔记
- [x] (2026-01-31 12:55Z) 深挖 Monopoly 的 Land/Market choice 调用链并写入研究笔记
- [x] (2026-01-31 12:59Z) 深挖 EffectPipeline 与可选落地效果的 choice 链条并写入研究笔记
- [x] (2026-01-31 12:59Z) 补齐 SecretOfEscaper 的 Library/Manager 架构与 Monopoly 对照
- [x] (2026-01-31 13:05Z) 记录 EffectPipeline 执行点扫描后的重构切入点


## 意外与发现


当前暂无记录。执行过程中如发现 Library 行为与文档/代码意图不一致，或出现与 monopoly 现有实现强相关的意外耦合，请在此补充事实与证据片段。


## 决策日志


决策：继续使用同一份研究笔记承载 SecretOfEscaper 与 Monopoly 的现有实现对照，而不额外拆分新文件。理由：重构准备更依赖对照阅读，集中在一份笔记中便于检索与复用。日期/作者：2026-01-31 / Codex


## 结果与复盘


已完成架构研究初版，研究笔记覆盖入口与初始化、目录职责、Library/Manager 对照、Monopoly 关键调用链、EffectPipeline 相关链路与重构切入点。主要缺口在于更细粒度的 Manager/Components 调用链验证与运行期行为（例如模式切换时序、存档边界条件）。后续若要推动重构落地，需要补充这些细节并结合实机日志验证。


## 背景与导读


`.github/docs/SecretOfEscaper` 是一个完整的 Lua 子工程镜像，入口位于 `.github/docs/SecretOfEscaper/main.lua`，它在延迟一帧后调用 `require "init"` 并执行 `MapManager.init_level(LevelData.current_level)`。初始化文件 `.github/docs/SecretOfEscaper/init.lua` 依次加载 `Globals` 封装、`Library.Utils`、`Library.ClassUtils`、`Library.UIManager.Utils`、`Library.Bincore`、`Library.Behavior.config`，然后加载 `Manager.__init` 以及全局 `LevelData`。目录结构以 `Config`、`Data`、`Globals`、`Library`、`Manager`、`Components` 为核心，其中 `Library` 提供通用能力，`Manager` 承载玩法与系统模块。`Library` 的典型调用点包括 `.github/docs/SecretOfEscaper/Manager/ModeManager/LootEscaper/__init.lua`（NavMesh 与 UIManager）、`.github/docs/SecretOfEscaper/Manager/EntityManager`（Behavior）、`.github/docs/SecretOfEscaper/Manager/PlayerManager/Player.lua`（Bincore）。这些是后续追踪调用链的起点。

当前 Monopoly 工程入口位于 `main.lua`，它直接 `require "init"`。初始化文件 `init.lua` 依次加载 `Globals.__init` 与 `Manager.__init`，并调用 `Manager.GameManager.Entry.install()` 启动运行时。`Globals/__init.lua` 封装 `SetTimeOut`、触发器注册与 `ALLROLES` 等全局变量。`Manager/__init.lua` 汇总加载 `System`、`GameManager`、`TurnManager`、`BoardManager`、`MarketManager`、`ChoiceManager`、`MovementManager`、`ItemManager`、`LandManager`、`EffectManager`。运行时主逻辑在 `Manager/System/Runtime.lua`：构建 `runtime`（UI、自动回合、状态同步与弹窗），监听 `IntentDispatcher`，安装 GAME_INIT 回调并通过 `UIManager.Builder` 构建 UI。核心游戏对象由 `Manager/GameManager/CompositionRoot.lua` 组装：读取 `Config/Generated` 与 `Config/Map.lua`，构建 `Components.Board` 与 `Components.Player`，创建 `Components.Store` 状态树，注册 `ChoiceService`、`ItemRegistry`、`ChanceRegistry`，并生成 `TurnManager` 以运行阶段状态机。回合阶段在 `Manager/TurnManager/Turn` 下拆分为 `TurnStart`、`TurnRoll`、`TurnMove`、`TurnLand`、`TurnPost`、`TurnEnd`。这些模块是后续总结 Monopoly 现有实现与重构对照的基线。


## 工作计划


先从入口与初始化读起，确认模块加载顺序与全局变量的生命周期，建立整体心智模型。随后逐一阅读 `Library` 内的核心模块，整理每个模块提供的入口、关键数据结构与最小使用示例，并把需要在笔记中保留的 API 签名标出来。接着从 `Manager` 与 `Components` 中逆向追踪实际调用链，把 Library 如何支撑玩法逻辑写清楚。然后补充 Monopoly 当前实现：从 `Runtime` 与 `CompositionRoot` 入手，串起 `Store` 状态树、`TurnManager` 状态机与各个 Manager 服务的调用链，明确数据驱动与 UI 同步方式。最后把这些结论整理为一份研究笔记，并与仓库中 Monopoly 的 `Library` 与 `Manager` 现有实现做对照，提炼可迁移的结构与潜在冲突点。

为加速执行，可将调研拆成多个子任务并行推进。建议将子任务按模块分配给 subagent：A 负责 SecretOfEscaper 的 `Library` 结构与关键入口；B 负责 SecretOfEscaper 的 `Manager` 体系（Map/Mode/Entity/Player/Item/Shop）；C 负责 Monopoly 的对应模块与调用链补齐；主执行者负责统一汇总到同一份笔记并做对照。每个 subagent 必须输出“关键文件路径 + 入口函数 + 调用关系 + 结论要点”，并标注是否存在仍需二次确认的疑点。


## 具体步骤


在仓库根目录依次运行搜索命令，先建立目录与引用视图，再进入代码阅读与记录阶段。建议按顺序执行以下命令并在笔记中记录观察结果：

    rg --files .github/docs/SecretOfEscaper
    rg "Library\\." -n .github/docs/SecretOfEscaper
    rg "Behavior" -n .github/docs/SecretOfEscaper/Manager
    rg "NavMesh" -n .github/docs/SecretOfEscaper/Manager
    rg "UIManager" -n .github/docs/SecretOfEscaper/Manager
    rg "Bincore" -n .github/docs/SecretOfEscaper

这些命令应返回包含入口文件与关键引用的位置，例如 `.github/docs/SecretOfEscaper/init.lua`、`.github/docs/SecretOfEscaper/Manager/ModeManager/LootEscaper/__init.lua`、`.github/docs/SecretOfEscaper/Manager/PlayerManager/Player.lua`。随后打开这些文件逐段阅读，补齐对初始化流程、Library 模块职责与实际调用的理解，并把结论实时写入笔记文件。

补充 Monopoly 现有实现时，建议额外运行以下命令以定位核心调用链：

    rg "Runtime" -n Manager/System
    rg "CompositionRoot" -n Manager/GameManager
    rg "TurnManager" -n Manager/TurnManager Manager/GameManager
    rg "ChoiceService" -n Manager/ChoiceManager Manager/GameManager
    rg "Store" -n Components Manager/GameManager
    rg "UIManager" -n Manager Manager/System

这些命令应定位 `Manager/System/Runtime.lua`、`Manager/GameManager/CompositionRoot.lua`、`Manager/TurnManager/Turn/TurnManager.lua`、`Components/Store.lua` 等关键文件。阅读后把 Monopoly 的入口流程、状态树结构、回合阶段与服务注册方式写入同一份笔记。


## 验证与验收


完成后检查 `.github/docs/SecretOfEscaper/architecture_study.md` 是否包含入口与初始化、目录职责、Library 模块说明、典型调用链、Monopoly 现有实现概览、与 Monopoly 对照与待验证问题这些内容。再重复上述 `rg` 命令，确保每条调用链在笔记中都有对应引用路径。若能在不打开源码的情况下通过笔记回答“某个玩法模块如何调用 Library”与“Monopoly 当前回合是如何驱动的”这类问题，则视为达标。


## 可重复性与恢复


本计划仅涉及阅读与写笔记，命令可重复执行而不会改动代码。若笔记内容失真，可删除 `.github/docs/SecretOfEscaper/architecture_study.md` 后按步骤重新生成，并在进度中记录重做原因。


## 产物与备注


最终产物是研究笔记 `.github/docs/SecretOfEscaper/architecture_study.md`。示例结构如下：

    # SecretOfEscaper 架构与 Library 笔记
    入口与初始化：说明 main.lua 与 init.lua 的调用顺序与全局初始化
    目录职责：Config/Data/Globals/Library/Manager/Components 的定位
    Library 模块：Utils、ClassUtils、UIManager、Behavior、NavMesh、Bincore 的职责与关键 API
    SecretOfEscaper 调用链：列出关键 Manager/Components 对 Library 的具体使用
    Monopoly 现有实现：入口、Runtime、CompositionRoot、TurnManager、Store 与关键 Manager/Services
    与 Monopoly 对照：可迁移点、差异、潜在冲突
    待验证问题：需要进一步确认的细节


## 接口与依赖


笔记中必须明确 `Library` 的入口模块与关键 API，以便后续重构直接引用，包括 `Library.Utils` 的 `SetFrameOut(...)`、`Library.ClassUtils` 的 `Class(...)`、`Library.UIManager` 的 `Builder:new(...)` 与节点查询接口、`Library.Behavior.config` 的 `build_tree(...)`、`Library.NavMesh.__init` 的构建与编辑入口、`Library.Bincore` 的 `encode(...)` 与 `decode(...)`。同时明确 Monopoly 的关键接口与状态路径，包括 `Manager/System/Runtime.install(...)`、`Manager/GameManager/CompositionRoot.assemble(...)`、`Components.Store:get/set`、`Manager/TurnManager/Turn/TurnManager:dispatch/advance_turn`、`Library.Monopoly.IntentDispatcher.on/dispatch` 与 `Library.Monopoly.Logger` 的调用点。如果这些入口在实际调用链中有变体或封装，也要在笔记中注明对应文件与原因。

修改说明：补充 Monopoly 现有实现的背景、步骤与验收要求，并决定将对照内容写入同一份研究笔记，便于重构准备与检索。
修改说明：记录 Choice/Item 调用链已落地到研究笔记，便于后续重构对照。
修改说明：补充 Land/Market choice 调用链到研究笔记，覆盖落地与黑市流程。
修改说明：补充 EffectPipeline 与可选落地效果 choice 链条到研究笔记，便于落地效果重构对照。
修改说明：补齐 SecretOfEscaper 的 Library/Manager 架构对照章节，覆盖核心差异点。
修改说明：补充 EffectPipeline 执行点扫描后的重构切入点，便于后续设计拆分。
修改说明：补充 subagent 并行拆分的执行指导，以便正式执行时加速推进。
修改说明：执行计划补齐入口/目录/调用链章节，完成初版并更新进度与复盘。
