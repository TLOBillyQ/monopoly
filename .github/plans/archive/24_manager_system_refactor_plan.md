# Manager/System 职责重构计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循仓库内的 `/.agent/PLANS.md`。

## 目的 / 全局视角


本次重构要把 Manager/System 从“杂物间”变成真正的运行时与适配层目录，让游戏核心、玩法服务与全局资源各归其位。完成后，Manager/System 只保留运行时装配、UI 适配与 ECA 桥接；Game 核心与玩法服务迁到 Manager/GameManager；资源映射与宏常量进入 Globals。对外行为保持不变，但新同学能按目录名直觉找到代码位置，维护成本下降。

可观察结果是：所有 require 路径指向新位置且没有循环依赖；UI 启动后能正常进入游戏、道具卡位图标仍能显示；运行依赖检查与回归测试通过。

## 进度


- [x] (2026-01-30 15:18) 盘点 Manager/System 模块与全仓引用，整理迁移映射与风险点
- [x] (2026-01-30 15:18) 迁移 Macro 与 Refs 到 Globals，并更新初始化与 require 顺序
- [x] (2026-01-30 15:18) 迁移游戏核心模块到 Manager/GameManager，更新所有引用
- [x] (2026-01-30 15:18) 调整入口聚合文件与文档，写明 System 与 GameManager 的职责边界
- [x] (2026-01-30 15:18) 运行依赖检查与回归测试，补齐必要的手动验收记录（手动验收按用户指示视作通过）

## 意外与发现


- 观察：依赖检查失败，原因是 Manager/BoardManager、ChoiceManager、MarketManager、TurnManager 的 __init.lua 在非 GUI 层 require GUI/__init.lua。
  证据：运行 `lua .github/tests/deps_check.lua` 报错 `gameplay must not require GUI/runtime`，指向上述 __init.lua。

## 决策日志


决策：移除 Manager/BoardManager/__init.lua、Manager/ChoiceManager/__init.lua、Manager/MarketManager/__init.lua、Manager/TurnManager/__init.lua 中对 GUI/__init.lua 的 require。理由：GUI/__init.lua 为空且依赖规则禁止 gameplay require GUI，移除不改变行为且通过依赖检查。日期/作者：2026-01-30 / Codex。

决策：Manager/System 仅保留运行时装配与适配层模块，把游戏核心与玩法服务迁入 Manager/GameManager。理由：运行时与玩法核心职责不同，混放导致定位成本高。日期/作者：2026-01-30 / Codex。

决策：将 Macro 与 Refs 迁入 Globals，并保持常量名称与映射键不变。理由：宏与资源映射是全局资源，放在 Globals 更符合命名语义且可提前加载。日期/作者：2026-01-30 / Codex。

决策：迁移时保持文件名与外部接口不变，先消除路径混乱再讨论逻辑优化。理由：降低重构风险，确保行为不回退。日期/作者：2026-01-30 / Codex。

## 结果与复盘


已完成 Manager/System 拆分与路径更新，Macro/Refs 迁入 Globals，Game/Chance/Agent 等迁入 Manager/GameManager，并更新入口聚合与文档。依赖检查与回归测试通过，手动验收按用户指示视作通过。

## 背景与导读


当前入口链路为 `main.lua` 加载 `init.lua`，`init.lua` 依次加载 `Globals.__init`、`Manager.__init` 并执行 `Manager.System.Runtime.install()`。Manager/System 内同时存在运行时装配（Runtime、ECA、AdapterLayer、Presenter、AutoRunner）、游戏核心（Game、CompositionRoot、BoardFactory）、玩法服务（Chance、Agent、BankruptcyService）与玩家能力混入（PlayerEffects、PlayerVehicle），还夹杂全局宏与资源映射（Macro、Refs）。这种混放让“系统层”语义模糊，导致跨目录依赖无法从名称判断。

本计划通过拆分职责与移动文件来解决上述问题，目标是让运行时与适配层继续留在 Manager/System，让游戏核心与玩法服务在 Manager/GameManager 汇聚，让全局宏与资源映射回到 Globals。所有迁移均保持功能与数据结构不变，只调整位置与 require 路径。

## 工作计划


先用 rg 盘点所有 `Manager.System.*` 的引用并记录到临时清单，确认哪些模块是运行时装配、哪些是玩法核心、哪些是全局资源。随后将 Macro 与 Refs 迁入 Globals，将 Game、CompositionRoot、BoardFactory、Chance、Agent、BankruptcyService、PlayerEffects、PlayerVehicle、Constants 迁入 Manager/GameManager，并更新所有 require 与文档引用。迁移完成后收口入口聚合文件，确保 `Globals.__init` 负责加载全局资源，`Manager/__init.lua` 负责装配各 Manager，`Manager/GameManager/__init.lua` 仅汇总 GameManager 内部模块，不再承担跨目录聚合职责。最后运行依赖检查与回归测试，并补充最小手动验收说明，确认 UI 行为不变。

## 具体步骤


在仓库根目录运行以下命令，收集所有旧路径引用与文档引用，并把输出保存到临时清单中，便于逐项核对：

    rg -n "Manager\.System\.(Game|CompositionRoot|BoardFactory|Chance|Agent|BankruptcyService|PlayerEffects|PlayerVehicle|Constants|Macro|Refs)" -g "*.lua"
    rg -n "Manager/System/(Macro|Refs)\.lua" .github/docs

确认引用后创建目标目录并移动文件，以下命令以 PowerShell 为例，可按实际需要拆分执行：

    New-Item -ItemType Directory -Force Globals | Out-Null
    New-Item -ItemType Directory -Force Manager/GameManager | Out-Null
    Move-Item Manager/System/Macro.lua Globals/Macro.lua
    Move-Item Manager/System/Refs.lua Globals/Refs.lua
    Move-Item Manager/System/Game.lua Manager/GameManager/Game.lua
    Move-Item Manager/System/CompositionRoot.lua Manager/GameManager/CompositionRoot.lua
    Move-Item Manager/System/BoardFactory.lua Manager/GameManager/BoardFactory.lua
    Move-Item Manager/System/Chance.lua Manager/GameManager/Chance.lua
    Move-Item Manager/System/Agent.lua Manager/GameManager/Agent.lua
    Move-Item Manager/System/BankruptcyService.lua Manager/GameManager/BankruptcyService.lua
    Move-Item Manager/System/PlayerEffects.lua Manager/GameManager/PlayerEffects.lua
    Move-Item Manager/System/PlayerVehicle.lua Manager/GameManager/PlayerVehicle.lua
    Move-Item Manager/System/Constants.lua Manager/GameManager/Constants.lua

逐个更新 require 路径，确保 Runtime、ECA、GUI、Item/Choice/Movement/Land 等模块全部指向新位置，并注意测试文件与文档也要同步改动。推荐先用 rg 找到所有 `Manager.System` 引用，再手动修改为新路径，避免误替换：

    rg -n "Manager\.System\." -g "*.lua"

调整入口聚合文件与文档。更新 `Globals/__init.lua` 以显式加载 `Globals/Macro.lua`（必要时也加载 `Globals/Refs.lua`），更新 `Manager/GameManager/__init.lua` 以只汇总 GameManager 内部模块并移除对其他 Manager 的 require，更新 `.github/docs/ui/04_market_screen.md` 中关于 Refs 的路径说明。

完成迁移后运行依赖检查与回归测试，必要时补充最小手动验收记录：

    lua .github/tests/deps_check.lua
    lua .github/tests/regression.lua

## 验证与验收


依赖检查通过，终端包含 `Dependency self-check passed`。回归测试通过，终端包含 `All regression checks passed (30)`。手动验收时进入场景后能正常打开主界面，道具卡槽位图标可显示（来自 Refs 映射），移动与动画事件不报错，ECA 转发 UI 事件可正常触发。

## 可重复性与恢复


迁移前先复制目录作为备份，确保可回滚且不依赖 git 命令。若迁移失败或出现运行时错误，将备份覆盖回原路径并重新运行测试：

    Copy-Item -Recurse Manager/System Manager/System_backup
    Copy-Item -Recurse Globals Globals_backup

备份确认无误后再继续迁移；恢复完成后保持备份目录以便二次对照。

## 产物与备注


重构后的关键引用示例应类似如下，便于快速核对：

    -- Manager/System/Runtime.lua
    local Game = require("Manager.GameManager.Game")
    require "Globals.Macro"
    ...
    G.refs = require "Globals.Refs"

    -- Manager/BoardManager/GUI/MoveAnim.lua
    require "Globals.Macro"

确保 `Globals/Macro.lua` 仍然定义 V3_LEFT、Q_LEFT、ECA_EVENT 等全局常量，避免运行时行为变化。

## 接口与依赖


以下接口需要保持签名与语义不变，只允许迁移路径：

    -- Manager/GameManager/Game.lua
    function Game.new(opts)

    -- Manager/GameManager/CompositionRoot.lua
    function CompositionRoot.assemble(opts, GameClass)

    -- Manager/GameManager/Agent.lua
    function Agent.is_auto_player(player)
    function Agent.auto_action_for_choice(game, choice)

    -- Manager/GameManager/Chance.lua
    function ChanceEffects.resolve(game, player, card, context)

    -- Manager/System/Runtime.lua
    function Runtime.install()

    -- Manager/System/AdapterLayer.lua
    function AdapterLayer.attach(layer, opts)
    function AdapterLayer.new_game(layer)

    -- Globals/Macro.lua
    -- 保持 V3_LEFT、Q_LEFT、ECA_EVENT 等全局常量名不变

`Manager/GameManager/Constants.lua` 继续提供 `turn_limit` 与 `item_ids`，并被 Movement、Item、Land、Choice 等模块引用。`Globals/Refs.lua` 仍返回道具与机会卡的资源映射表。迁移后不新增新的跨层依赖，Runtime 只依赖 Game 核心与 Globals。

变更说明：更新进度与结果，记录依赖检查问题与修复，并补充测试执行情况。

变更说明：按用户指示将手动验收视作通过，并将进度更新为完成。
