# Monopoly SOE 式结构重构计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。本文件遵循 `.agent/PLANS.md` 的规范。


## 目的 / 全局视角


基于计划29的研究结果，把 Monopoly 的入口与模块组织方式调整为更接近 SecretOfEscaper 的“地图/模式/系统”结构，不再以平台分层作为设计前提。目标是让 `MapManager` 与 `ModeManager` 成为新的启动主干，核心玩法逻辑仍保留在现有 Manager 中，但由模式驱动串联。可观察结果是：`init.lua` 不再直接调用 `GameManager.Entry.install()`，而是通过 `MapManager.init_level` 选择地图并加载模式；`.github/tests/regression.lua` 仍通过；运行时启动路径清晰可追踪。


## 进度


- [x] (2026-01-31 14:09Z) 已完成：按用户指示废弃本计划并记录原因
- [x] (2026-01-31 14:08Z) 已完成：根据计划34做代码审查与 SOLID 评估，并把发现与建议写入本计划
- [ ] (2026-01-31 13:30Z) 明确 SOE 式入口链路在 Monopoly 的目标形态与模块边界
- [ ] (2026-01-31 13:30Z) 新增 LevelData、MapManager、ModeManager 最小实现并接入入口
- [ ] (2026-01-31 13:30Z) 迁移启动逻辑到 ModeManager，并补齐地图/模式配置
- [ ] (2026-01-31 13:30Z) 梳理与更新相关 require 路径与文档，确保回归测试通过
- [ ] (2026-01-31 13:30Z) 完成验证与复盘，记录后续重构的优先方向


## 意外与发现


发现当前仓库尚未新增与计划对应的核心文件与最小实现。MapManager 与 ModeManager 目录为空，Config 下尚未出现 MapConfig 与 ModeConfig，Globals 下尚未出现 LevelData，这意味着计划的步骤 1-4 尚未开始，代码审查只能针对现有入口链路进行。

证据：ls Manager/MapManager 输出为空；ls Manager/ModeManager/Classic 输出为空；ls Config 只包含 Map.lua。


## 决策日志


- 决策：在正式实现前先做一次面向现有入口链路的 SOLID 评估，并把缺口与建议写入计划。
  理由：当前计划相关文件未落地，先给出结构性改进方向可降低后续设计反复。
  日期/作者：2026-01-31 / Codex
- 决策：废弃本计划。
  理由：用户明确要求废弃该计划。
  日期/作者：2026-01-31 / Codex


## 结果与复盘


本计划已按用户要求废弃，未进入实现与验证阶段。保留的代码审查与路线图可作为后续替代计划的参考，但不再作为执行依据。


## 代码审查与 SOLID 评估


当前入口链路由 `init.lua` 直接调用 `Manager.GameManager.Entry.install()`，这使启动流程依赖具体实现而非抽象入口，违反依赖倒置原则，也导致未来 MapManager/ModeManager 接入时需要修改入口文件而非配置。`Manager/__init.lua` 一次性加载全部管理器，入口层承担过多装配职责，职责边界模糊，放大了启动依赖。`Manager/GameManager/Entry.lua` 同时负责运行时安装与创建游戏实例，且在 `create_game` 内部硬编码玩家与 AI 配置，容易阻塞扩展点，影响开闭原则与单一职责。

这些问题与计划 34 的目标一致，说明把入口迁移到 MapManager/ModeManager 并引入 LevelData 与配置映射，能够把启动决策与运行逻辑解耦，从结构上改善上述 SOLID 缺口。


## 修改建议与路线图


第一阶段以最小可运行骨架为目标，把 `Globals/LevelData.lua`、`Config/MapConfig.lua`、`Config/ModeConfig.lua`、`Manager/MapManager/__init.lua`、`Manager/ModeManager/__init.lua` 与 `Manager/ModeManager/Classic/__init.lua` 补齐，并在 `init.lua` 改为 `MapManager.init_level(LevelData.current_level)`，确保入口只依赖抽象的地图与模式选择。

第二阶段把 `Manager/GameManager/Entry.lua` 的 `create_game` 拆为可注入的工厂或配置读取，ModeManager 通过配置或参数传入，减少硬编码并让模式层成为唯一的启动决策点。

第三阶段整理 `Manager/__init.lua` 的加载顺序，让 MapManager/ModeManager 处于入口层最小依赖集合，其余 Manager 由模式或运行时按需加载，降低入口职责并避免全量 require 的启动耦合。

第四阶段在 `.github/tests/regression.lua` 通过后，再补充新的启动链路验证点，确保入口调整的可观察结果稳定，并把验证输出写回“结果与复盘”。


## 背景与导读


Monopoly 当前入口是 `main.lua` → `init.lua` → `Manager.GameManager.Entry.install()`，运行时与回合流程主要挂在 `Manager/System/Runtime.lua` 与 `Manager/TurnManager`。SecretOfEscaper 的入口则是 `main.lua` → `init.lua` → `MapManager.init_level`，由地图选择与模式加载驱动玩法。计划29的研究笔记已整理出其 `MapManager`、`ModeManager`、`PlayerManager`、`EntityManager` 的职责与调用链。本计划将把 Monopoly 的入口重构为“地图选择 + 模式驱动”的形态，并保持现有 Manager 内部逻辑不大幅改动。


## 工作计划


先建立 `LevelData` 的最小结构，明确当前地图与模式的默认值。随后新增 `Manager/MapManager/__init.lua` 与 `Manager/ModeManager/__init.lua`，让 `MapManager.init_level` 负责加载地图模块，再调用 `ModeManager` 加载模式入口。接着把 `GameManager.Entry.install()` 的调用迁移到 `ModeManager`，并用配置文件声明地图与模式的对应关系，保证后续扩展时只需新增配置与模块。最后更新 `init.lua` 的入口链路，运行回归测试并记录验证结果。


## 具体步骤


1) 新增 `Globals/LevelData.lua`，定义 `LevelData` 的初始结构，至少包含 `current_level` 与 `current_mode`，默认值指向现有地图与模式。修改 `init.lua` 在加载 `Globals.__init` 后引入 `Globals.LevelData`。

2) 新增 `Manager/MapManager/__init.lua`，提供 `select_level(level_name)` 与 `init_level(level_name)`，其行为参考 SecretOfEscaper：`init_level` 根据配置加载地图模块，并在加载后调用 `ModeManager.init_mode`。

3) 新增 `Manager/ModeManager/__init.lua` 与 `Manager/ModeManager/Classic/__init.lua`。`ModeManager.init_mode(mode_name)` 负责加载 `Classic` 模式，并在该模式中调用现有 `Manager.GameManager.Entry.install()` 启动游戏逻辑。

4) 新增 `Config/MapConfig.lua` 与 `Config/ModeConfig.lua`，将现有 `Config/Map.lua` 作为默认地图配置并建立名称映射，模式配置至少包含 `classic`。地图配置需要提供 `namespace` 或 `module` 字段，用于 `MapManager.init_level` 的 `require` 路径。

5) 更新 `Manager/__init.lua` 的加载顺序，确保 `MapManager` 与 `ModeManager` 在入口可用。更新 `init.lua` 的启动逻辑为 `MapManager.init_level(LevelData.current_level)`，并保留旧入口作为注释或回退指引。

6) 运行验证并记录输出：

    lua .github/tests/regression.lua

如果运行时依赖引擎无法在本地复现，可记录最小启动步骤与预期观察点，补充到“产物与备注”。


## 验证与验收


必须满足以下条件：`lua .github/tests/regression.lua` 通过；`init.lua` 启动链路已改为 `MapManager.init_level` 且能加载 `Classic` 模式；核心玩法逻辑与现有 `Entry.install` 行为一致。


## 可重复性与恢复


本计划的改动可重复执行。若需要回滚，恢复 `init.lua` 对 `Entry.install` 的直接调用，并删除新增的 `Manager/MapManager`、`Manager/ModeManager` 与配置文件即可。


## 产物与备注


产物包括新增的 `Globals/LevelData.lua`、`Manager/MapManager/__init.lua`、`Manager/ModeManager/__init.lua`、`Manager/ModeManager/Classic/__init.lua`、`Config/MapConfig.lua`、`Config/ModeConfig.lua`，以及更新后的 `init.lua` 与 `Manager/__init.lua`。


## 接口与依赖


`Globals/LevelData.lua` 必须提供全局 `LevelData`，包含字段 `current_level` 与 `current_mode`。`Manager/MapManager/__init.lua` 必须提供以下接口：

    MapManager.select_level(level_name)
    MapManager.init_level(level_name)

`Manager/ModeManager/__init.lua` 必须提供：

    ModeManager.init_mode(mode_name)

`Manager/ModeManager/Classic/__init.lua` 中应调用：

    require("Manager.GameManager.Entry").install()

配置依赖：`Config/MapConfig.lua` 必须能映射 `LevelData.current_level` 到地图模块路径或配置；`Config/ModeConfig.lua` 必须能映射 `LevelData.current_mode` 到模式模块路径。

修改说明：根据计划29的研究结论，重写为 SOE 式入口链路重构计划，移除 core/adapter 分层思路。

变更说明：补充了基于计划34的代码审查与 SOLID 评估、当前缺口与修改路线图，用于在实现前明确问题与推进顺序。

变更说明：按用户要求废弃本计划，更新进度、决策日志与结果与复盘以反映终止状态。
