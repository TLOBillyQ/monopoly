# 目录职责重划与规则抽离计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 `.github/agent/PLANS.md`。


## 目的 / 全局视角


目标是把目录职责收敛到“领域对象、运行时基础设施、规则函数、UI 适配层”四类，并避免新增顶层目录。完成后可观察的结果是：`Components/` 只保留领域对象，基础设施模块统一在 `Library/Runtime/`，UI 目录从 `Manager/UIRoot` 统一为 `Manager/UI`，玩家相关的住院/进山规则移动到 `Manager/Rules/PlayerStatus.lua`，旧路径与旧方法调用不再命中，回归脚本通过，启动后 UI 与回合流程仍可正常运行。


## 进度


- [ ] (2026-02-02 20:10Z) 盘点基础设施与 UI 的引用点，以及玩家状态规则的调用点，整理迁移清单。
- [ ] (2026-02-02 20:10Z) 建立 `Library/Runtime` 与 `Manager/Rules`，迁移 `Flow/Store/Logger` 与 `UIRoot`，更新全部 `require` 路径并验证检索无旧路径。
- [ ] (2026-02-02 20:10Z) 把玩家“住院/进山”规则抽离到 `Manager/Rules/PlayerStatus.lua`，更新调用点并清理 `Components/Player.lua` 中的游戏编排逻辑。
- [ ] (2026-02-02 20:10Z) 运行回归脚本与路径扫描，补齐日志与复盘。


## 意外与发现


暂无，实施中补充。


## 决策日志


决策：不新增顶层 `Core/` 或 `UIRoot/` 目录，基础设施统一收敛到 `Library/Runtime/`，UI 保留在 `Manager/` 下并改名为 `Manager/UI`。
理由：减少顶层目录扩张，复用已有 `Library/` 的工具语义，同时保持 UI 仍是管理层的适配部分。
日期/作者：2026-02-02 / Codex。

决策：新增 `Manager/Rules/PlayerStatus.lua` 承载“住院/进山”规则，不放入 `GameManager`。
理由：该规则被多处调用，属于共享规则层，放在 `GameManager` 会过度耦合具体管理器。
日期/作者：2026-02-02 / Codex。

决策：不在本计划中处理函数命名风格，仅调整目录与职责归属。
理由：避免与函数命名统一计划交叉，降低一次性改动风险。
日期/作者：2026-02-02 / Codex。


## 结果与复盘


尚未开始，完成后补充。


## 背景与导读


仓库当前以 `Components/` 存放领域对象，以 `Manager/` 承载流程编排与子系统，UI 位于 `Manager/UIRoot/`。领域对象指“只描述玩家、棋盘、格子等游戏状态与规则的对象”；运行时基础设施指“状态机、状态存储、日志等不属于具体业务对象的工具”；规则函数指“对 game 与 player 进行操作但不负责流程编排的纯业务规则”；UI 适配层指“把游戏状态映射到 UI 节点、并处理 UI 事件的逻辑”。

当前混放点主要有三类：`Components/Flow.lua`、`Components/Store.lua`、`Components/Logger.lua` 是通用基础设施但被放在 `Components/`；`Manager/UIRoot/` 是 UI 适配层但命名上像是顶层根模块；`Components/Player.lua` 内包含“住院/进山”等会直接操纵 `game` 与服务的规则逻辑。上述问题削弱了目录语义，增加了跨层依赖。

涉及的关键文件与目录包括：`Components/Flow.lua`、`Components/Store.lua`、`Components/Logger.lua`、`Components/Player.lua`、`Manager/UIRoot/`、`Manager/ChanceManager/ChanceRegistry.lua`、`Manager/LandManager/LandActions.lua`、`Manager/LandManager/Landing.lua`、`Manager/EffectManager/MineEffect.lua`、`Manager/TurnManager/GameplayLoop.lua`、`init.lua`。这些文件需要随着目录迁移与规则抽离而更新 `require` 与调用方式。


## 工作计划


先在仓库根目录盘点基础设施、UI 与玩家规则的引用点，确认需要更新的 `require` 与调用路径。随后建立 `Library/Runtime/` 与 `Manager/Rules/`，把 `Flow/Store/Logger` 迁移到 `Library/Runtime/`，把 `Manager/UIRoot/` 重命名为 `Manager/UI/`，并批量更新引用路径。最后把“住院/进山”规则从 `Components/Player.lua` 抽离到 `Manager/Rules/PlayerStatus.lua`，更新所有调用点，清理 Player 中对 `game` 与服务的直接依赖。完成后运行回归脚本与路径扫描，确认旧路径与旧方法调用不再存在。


## 具体步骤


在仓库根目录 `C:\Users\Lzx_8\Desktop\dev\monopoly` 盘点引用关系，锁定需要更新的文件与调用点：

    rg -n "Components\.(Flow|Store|Logger)" -g "*.lua"
    rg -n "Manager\.UIRoot" -g "*.lua"
    rg -n "send_to_hospital|apply_hospital_effects|send_to_mountain|apply_mountain_effects|is_in_mountain" -g "*.lua"

创建新目录并迁移基础设施模块，同时建立规则目录：

    New-Item -ItemType Directory -Path Library/Runtime -Force | Out-Null
    New-Item -ItemType Directory -Path Manager/Rules -Force | Out-Null
    Move-Item -Path Components/Flow.lua -Destination Library/Runtime/Flow.lua
    Move-Item -Path Components/Store.lua -Destination Library/Runtime/Store.lua
    Move-Item -Path Components/Logger.lua -Destination Library/Runtime/Logger.lua

重命名 UI 目录，并更新所有引用路径：

    Rename-Item -Path Manager/UIRoot -NewName UI

把 `Components.Flow/Store/Logger` 的 `require` 更新为 `Library.Runtime.Flow/Store/Logger`，把 `Manager.UIRoot` 更新为 `Manager.UI`。重点检查 `init.lua`、`Manager/TurnManager/GameplayLoop.lua`、`Manager/TurnManager/TurnManager.lua`、`Manager/LandManager/Landing.lua`、`Manager/ChanceManager/Chance.lua` 与 `Manager/ChoiceManager/ChoiceManager.lua` 等文件的引用。

新增 `Manager/Rules/PlayerStatus.lua`，把 `Components/Player.lua` 中的住院/进山规则迁移进去，函数以现有 snake_case 命名对外暴露：`apply_hospital_effects(game, player)`、`send_to_hospital(game, player)`、`apply_mountain_effects(game, player)`、`send_to_mountain(game, player)`、`is_in_mountain(game, player)`。这些函数内部保持原有逻辑不变，使用 `Config.Generated.Constants`、`Globals.ServiceKeys` 与 `Library.Runtime.Logger`。随后从 `Components/Player.lua` 删除对应方法与无用依赖，使 Player 保持纯数据与简单规则。

更新调用点，把 `player:send_to_hospital` 等调用替换为 `PlayerStatus.send_to_hospital`，并在相关文件顶部引入 `local PlayerStatus = require("Manager.Rules.PlayerStatus")`。重点更新 `Manager/ChanceManager/ChanceRegistry.lua`、`Manager/LandManager/LandActions.lua`、`Manager/LandManager/Landing.lua`、`Manager/EffectManager/MineEffect.lua`。

迁移完成后再次执行检索，确认旧路径与旧方法调用不再出现：

    rg -n "Components\.(Flow|Store|Logger)" -g "*.lua"
    rg -n "Manager\.UIRoot" -g "*.lua"
    rg -n ":send_to_hospital|:apply_hospital_effects|:send_to_mountain|:apply_mountain_effects|:is_in_mountain" -g "*.lua"


## 验证与验收


运行回归脚本并确认通过：

    lua .github/tests/regression.lua

预期输出包含 `All regression checks passed (N)`。然后执行路径扫描，确保旧路径与旧方法调用不再出现：

    rg -n "Components\.(Flow|Store|Logger)" -g "*.lua"
    rg -n "Manager\.UIRoot" -g "*.lua"
    rg -n ":send_to_hospital|:apply_hospital_effects|:send_to_mountain|:apply_mountain_effects|:is_in_mountain" -g "*.lua"

上述命令应当无输出；若仍有输出，说明仍存在未更新的引用，需要继续修正后再跑回归脚本。


## 可重复性与恢复


目录迁移与 `require` 更新是可重复的，只要保持目标路径一致即可。若迁移后出现问题，可先把 `Library/Runtime` 与 `Manager/UI` 目录反向移动回原位置，再用 `rg` 把 `Library.Runtime.*` 与 `Manager.UI` 还原为旧路径，最后恢复 `Components/Player.lua` 中被抽离的规则函数并回滚 `Manager/Rules/PlayerStatus.lua`。恢复后再次运行回归脚本，确认回到原始状态。


## 产物与备注


保留以下证据片段即可证明变更完成：

    rg -n "Manager\.UIRoot" -g "*.lua"
    (无输出)
    rg -n "Components\.(Flow|Store|Logger)" -g "*.lua"
    (无输出)
    rg -n ":send_to_hospital|:apply_hospital_effects|:send_to_mountain|:apply_mountain_effects|:is_in_mountain" -g "*.lua"
    (无输出)
    lua .github/tests/regression.lua
    All regression checks passed (N)


## 接口与依赖


迁移后的模块路径与接口约定如下：`Library.Runtime.Flow`、`Library.Runtime.Store`、`Library.Runtime.Logger` 取代原 `Components` 基础设施模块；`Manager.UI.*` 取代原 `Manager.UIRoot.*`；新增 `Manager.Rules.PlayerStatus` 提供 `apply_hospital_effects(game, player)`、`send_to_hospital(game, player)`、`apply_mountain_effects(game, player)`、`send_to_mountain(game, player)`、`is_in_mountain(game, player)`。`Components/Player.lua` 保留玩家数据与简单规则，不再直接调用 `game` 或服务。


本次修改说明：重写目录与职责安排，把基础设施收敛到 `Library/Runtime`，UI 保持在 `Manager` 下并改名为 `Manager/UI`，将玩家住院/进山规则抽离到 `Manager/Rules/PlayerStatus`，原因是减少顶层目录扩张并让规则位置更中立，避免与 `GameManager` 耦合过深。
