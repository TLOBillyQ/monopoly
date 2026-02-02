# 目录职责重划与规则抽离（PascalCase 版）


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件必须遵循 `.github/agent/PLANS.md` 规范维护。


## 目的 / 全局视角


目标是把目录职责收敛到“领域对象、运行时基础设施、规则函数、UI 适配层”四类，并避免新增顶层目录。完成后可观察的结果是：`Components/` 只保留领域对象，基础设施模块统一迁移到 `Library/Runtime/`，UI 目录从 `Manager/UIRoot` 统一为 `Manager/UI`，玩家“住院/进山”规则迁移到 `Manager/Rules/PlayerStatus.lua` 并以 PascalCase 接口调用，旧路径与旧方法调用不再命中，回归脚本通过，启动后 UI 与回合流程仍可正常运行。


## 进度


- [ ] (2026-02-02 12:28Z) 盘点基础设施、UI 与玩家规则的引用点，整理需要改动的 require 路径与调用列表。
- [ ] (2026-02-02 12:28Z) 新建 `Library/Runtime` 与 `Manager/Rules`，迁移 `Flow/Store/Logger` 与 `UIRoot`，更新全部 require 路径并校验无旧路径残留。
- [ ] (2026-02-02 12:28Z) 抽离 `Components/Player.lua` 中住院/进山规则到 `Manager/Rules/PlayerStatus.lua`，更新调用点并清理 Player 依赖。
- [ ] (2026-02-02 12:28Z) 运行回归脚本与路径扫描，补齐日志与复盘。


## 意外与发现


对比归档计划后发现：仓库当前仍保留 `Components/Flow.lua`、`Components/Store.lua`、`Components/Logger.lua` 与 `Manager/UIRoot/`，尚未出现 `Library/Runtime/` 或 `Manager/UI/`；玩家住院/进山逻辑仍在 `Components/Player.lua`，调用方式为 `player:ApplyHospitalEffects`、`player:SendToHospital`、`player:IsInMountain` 等 PascalCase 方法；旧计划中提到的 snake_case 函数名与 Windows 路径命令已不适用，且 `TurnManager.lua` 仍存在 `flow:step`、`Logger.info` 这类旧式调用，需要在迁移时保持调用方式不变只更新路径。


## 决策日志


决策：不新增顶层目录，基础设施仍收敛到 `Library/Runtime/`，UI 仍位于 `Manager/` 下并改名为 `Manager/UI`。理由：符合当前目录语义，减少顶层扩张，同时保持 UI 作为管理层适配模块的定位。日期/作者：2026-02-02 / Copilot CLI。

决策：玩家住院/进山规则迁移到 `Manager/Rules/PlayerStatus.lua`，函数命名沿用 PascalCase，并由模块函数调用替代 `Player` 方法。理由：规则被多处引用且不应嵌入领域对象本体，抽离后更利于复用与测试。日期/作者：2026-02-02 / Copilot CLI。


## 结果与复盘


尚未开始，完成后补充。


## 背景与导读


仓库当前以 `Components/` 存放领域对象，以 `Manager/` 承载流程编排与子系统，UI 位于 `Manager/UIRoot/`。运行时基础设施包括 `Components/Flow.lua`、`Components/Store.lua`、`Components/Logger.lua`，它们对外暴露 PascalCase 接口（例如 `Flow:Step`、`Store:Get`、`Logger.ConfigureGameTime`），但调用点仍分散在 `init.lua`、`Manager/TurnManager/TurnManager.lua`、`.github/tests/regression.lua` 等文件中，并夹杂少量旧式小写调用。玩家“住院/进山”逻辑目前仍在 `Components/Player.lua` 中以 `ApplyHospitalEffects`、`SendToHospital`、`ApplyMountainEffects`、`SendToMountain`、`IsInMountain` 方法存在，调用点位于 `Manager/LandManager/LandActions.lua`、`Manager/LandManager/Landing.lua`、`Manager/ChanceManager/ChanceRegistry.lua`、`Manager/EffectManager/MineEffect.lua`。

本计划需要把基础设施模块迁移到 `Library/Runtime/`，把 UI 根目录重命名为 `Manager/UI/` 并更新所有 `Manager.UIRoot.*` require，新增 `Manager/Rules/PlayerStatus.lua` 作为规则模块，确保所有调用改为模块函数形式并保持 PascalCase 命名。


## 工作计划


先在仓库根目录盘点基础设施、UI 与玩家规则的引用点，确认需要更新的 require 与调用路径。随后创建 `Library/Runtime/` 与 `Manager/Rules/`，迁移 `Components/Flow.lua`、`Components/Store.lua`、`Components/Logger.lua` 到 `Library/Runtime/`，把 `Manager/UIRoot/` 重命名为 `Manager/UI/`，并批量更新全部 require 路径。最后把玩家住院/进山规则从 `Components/Player.lua` 抽离到 `Manager/Rules/PlayerStatus.lua`，更新调用点并删除 Player 中不再需要的依赖与方法。全过程只调整路径与职责，不改动行为，保持 PascalCase 接口与现有调用方式一致。


## 具体步骤


在仓库根目录盘点引用关系，锁定需要更新的文件与调用点：

    cd /home/runner/work/monopoly/monopoly
    rg -n "Components\.(Flow|Store|Logger)" -g "*.lua"
    rg -n "Manager\.UIRoot" -g "*.lua"
    rg -n "ApplyHospitalEffects|SendToHospital|ApplyMountainEffects|SendToMountain|IsInMountain" -g "*.lua"

创建新目录并迁移基础设施模块，同时建立规则目录，再把 UI 目录改名：

    mkdir -p Library/Runtime Manager/Rules
    git mv Components/Flow.lua Library/Runtime/Flow.lua
    git mv Components/Store.lua Library/Runtime/Store.lua
    git mv Components/Logger.lua Library/Runtime/Logger.lua
    git mv Manager/UIRoot Manager/UI

更新 require 路径，把 `Components.Flow/Store/Logger` 替换为 `Library.Runtime.Flow/Store/Logger`，把 `Manager.UIRoot` 替换为 `Manager.UI`。重点检查 `init.lua`、`Manager/TurnManager/GameplayLoop.lua`、`Manager/TurnManager/TurnManager.lua`、`Manager/GameManager/CompositionRoot.lua`、`.github/tests/regression.lua` 与 UI 目录内部的引用。仅更新路径，不改动 `Logger.info`、`flow:step` 等调用方式。

新增 `Manager/Rules/PlayerStatus.lua`，把 `Components/Player.lua` 中的住院/进山逻辑迁移进去，暴露 `ApplyHospitalEffects(game, player)`、`SendToHospital(game, player)`、`ApplyMountainEffects(game, player)`、`SendToMountain(game, player)`、`IsInMountain(game, player)` 这些 PascalCase 函数，并保留原有逻辑与日志调用。随后从 `Components/Player.lua` 删除对应方法与不再使用的 `Logger`、`ServiceKey` 依赖。

更新调用点，把 `player:ApplyHospitalEffects`、`player:SendToHospital`、`player:ApplyMountainEffects`、`player:SendToMountain`、`player:IsInMountain` 替换为 `PlayerStatus.ApplyHospitalEffects` 等模块函数调用，并在相关文件顶部引入 `local PlayerStatus = require("Manager.Rules.PlayerStatus")`。重点更新 `Manager/LandManager/LandActions.lua`、`Manager/LandManager/Landing.lua`、`Manager/ChanceManager/ChanceRegistry.lua`、`Manager/EffectManager/MineEffect.lua`。

迁移完成后再次执行检索，确认旧路径与旧方法调用不再出现：

    rg -n "Components\.(Flow|Store|Logger)" -g "*.lua"
    rg -n "Manager\.UIRoot" -g "*.lua"
    rg -n ":ApplyHospitalEffects|:SendToHospital|:ApplyMountainEffects|:SendToMountain|:IsInMountain" -g "*.lua"


## 验证与验收


运行回归脚本并确认通过：

    lua .github/tests/regression.lua

预期输出包含 `All regression checks passed (N)`。然后执行路径扫描，确保旧路径与旧方法调用不再出现：

    rg -n "Components\.(Flow|Store|Logger)" -g "*.lua"
    rg -n "Manager\.UIRoot" -g "*.lua"
    rg -n ":ApplyHospitalEffects|:SendToHospital|:ApplyMountainEffects|:SendToMountain|:IsInMountain" -g "*.lua"

上述命令应当无输出；若仍有输出，说明仍存在未更新的引用，需要继续修正后再跑回归脚本。


## 可重复性与恢复


目录迁移与 require 更新是可重复的，只要保持目标路径一致即可。若迁移后出现问题，可用 `git status` 查看改动并用 `git checkout -- <path>` 回滚到迁移前状态，或把 `Library/Runtime` 与 `Manager/UI` 目录反向移动回原位置，再用 `rg` 把 `Library.Runtime.*` 与 `Manager.UI` 还原为旧路径，最后恢复 `Components/Player.lua` 中被抽离的规则函数并删除 `Manager/Rules/PlayerStatus.lua`，再运行回归脚本确认回到原始状态。


## 产物与备注


保留以下证据片段即可证明变更完成：

    rg -n "Manager\.UIRoot" -g "*.lua"
    (无输出)
    rg -n "Components\.(Flow|Store|Logger)" -g "*.lua"
    (无输出)
    rg -n ":ApplyHospitalEffects|:SendToHospital|:ApplyMountainEffects|:SendToMountain|:IsInMountain" -g "*.lua"
    (无输出)
    lua .github/tests/regression.lua
    All regression checks passed (N)


## 接口与依赖


迁移后的模块路径与接口约定如下：`Library.Runtime.Flow`、`Library.Runtime.Store`、`Library.Runtime.Logger` 取代原 `Components` 基础设施模块；`Manager.UI.*` 取代原 `Manager.UIRoot.*`；新增 `Manager.Rules.PlayerStatus` 提供 `ApplyHospitalEffects(game, player)`、`SendToHospital(game, player)`、`ApplyMountainEffects(game, player)`、`SendToMountain(game, player)`、`IsInMountain(game, player)`。`Components/Player.lua` 保留玩家数据与简单规则，不再直接承担住院/进山流程。


本次修改说明：根据当前 PascalCase 命名与调用方式重写计划，修正旧计划中的 snake_case 与路径假设，明确迁移目标与验证方式，确保计划可在现有代码结构上直接执行。
