# Manager 管理器层级梳理与命名统一计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 .github/agent/PLANS.md。


## 目的 / 全局视角


目标是把 `Manager/` 下的管理器层级梳理清楚，删除已无职责或空壳目录，并把对外管理器入口模块统一为 `*Manager.lua` 的命名，避免与 `Config/Generated/Constants.lua` 等“常量模块”产生概念混淆。完成后可观察的结果是：`Manager/` 目录层级更直接、无空壳目录；对外入口模块的文件名一致为 `*Manager.lua`；所有 require 引用更新且回归脚本通过。


## 进度


- [x] (2026-02-02 18:10Z) 步骤 0：分配子 agent 目录与目标，确认并行边界与写入策略。
- [x] (2026-02-02 18:10Z) 盘点 Manager 目录结构与跨目录入口模块，形成“管理器入口 + 目标文件名 + 需移动目录”的清单。
- [x] (2026-02-02 18:10Z) 执行入口模块的重命名与必要的目录迁移，更新所有 require 路径与局部变量名。
- [x] (2026-02-02 18:10Z) 删除无用目录与空壳 `__init.lua` 引用，保证 Manager 层级无冗余。
- [x] (2026-02-02 18:10Z) 运行回归脚本并记录结果，补充计划日志与复盘。


## 意外与发现


子 agent 并行创建失败（达到线程上限），本次由主 agent 串行执行。
回归脚本内存在旧路径 require（Movement/Market/Choice Service），随重命名一并更新。


## 决策日志


- 因子 agent 无法创建，改为主 agent 串行执行各目录改动，以避免未记录的并发修改。
- Movement/Market 目录仅含单一入口模块，入口上移至各自 Manager 根目录并删除空目录，减少无意义层级。
- Choice 入口模块上移至 `Manager/ChoiceManager/ChoiceManager.lua`，保留 `Choice/` 目录承载 Registry 与 Handlers。
- BankruptcyService 更名为 BankruptcyManager 以统一入口命名，不移动目录。


## 结果与复盘


完成入口命名统一与目录清理：Movement/Market/Choice/Bankruptcy 入口模块改为 `*Manager.lua` 并更新所有 require；删除 `Manager/BoardManager` 与空的 Movement/Market 子目录；更新回归脚本引用路径。回归脚本通过，行为不变。


## 背景与导读


当前 `Manager/` 目录包含多个域目录，例如 `GameManager`、`TurnManager`、`MovementManager`、`MarketManager`、`ChoiceManager`、`ItemManager`、`LandManager`、`EffectManager`、`ChanceManager` 与 `UIRoot`。其中部分目录仅作为命名占位或已迁移职责，例如 `BoardManager` 仅剩空 `__init.lua` 且没有其它模块；`MovementManager/Movement/` 与 `MarketManager/Market/` 仅包含单一 `*Service.lua` 文件，造成多层路径却缺少实际层级意义。另一方面，多个对外入口模块以 `*Service.lua` 命名（如 MovementService、MarketService、ChoiceService），与“管理器层级”的命名目标不一致。需要明确“管理器入口模块”的判定标准，统一命名，并在移动或删改目录后更新所有 require 引用与 `Manager/__init.lua`。


## 工作计划


步骤 0：分配子 agent 并行执行，按目录锁定文件归属，避免交叉修改。所有子 agent 必须把“已改动文件清单 + 关键变更点 + 未决问题”记录到本计划的“意外与发现 / 决策日志 / 结果与复盘”中。

- 子 agent A：`Manager/MovementManager/**`、`Manager/MarketManager/**`，目标是查明入口模块与是否可移除中间目录，完成重命名与 require 更新。
- 子 agent B：`Manager/ChoiceManager/**`、`Manager/GameManager/**`（仅涉及 Choice/Bankruptcy 入口模块），目标是统一 `*Manager.lua` 命名并更新 require。
- 子 agent C：`Manager/__init.lua` 与 `Manager/BoardManager/**`（仅做空壳目录确认与删除），目标是清理无用 require 与空目录。

主 agent 负责整体盘点、冲突合并与回归脚本验证，最终统一记录结果。

在仓库根目录盘点 `Manager/` 目录结构与入口模块的实际引用关系，定义“管理器入口模块”的规则：凡是被其它管理器或初始化入口使用、对外提供域能力的模块视为入口模块，并统一命名为 `*Manager.lua`。基于该规则，将 `MovementManager/Movement/MovementService.lua`、`MarketManager/Market/MarketService.lua`、`ChoiceManager/Choice/ChoiceService.lua`、`GameManager/BankruptcyService.lua` 等入口模块改名为 `*Manager.lua`，并视情况将仅包含单一入口模块的中间目录（如 `Movement/`、`Market/`）上移并删除。对于已无职责的 `BoardManager/` 目录，直接删除并移除 `Manager/__init.lua` 中的空壳 require。完成重命名与迁移后，更新所有 require 路径与局部变量名，确保外部调用保持行为一致。最后运行回归脚本，记录通过结果并更新计划日志。


## 具体步骤


在仓库根目录执行结构盘点，确认入口模块与引用点（工作目录为仓库根目录）：

    rg -n "Manager\\.[A-Za-z]+Manager\\.[A-Za-z]+" Manager init.lua .github/tests
    rg -n "MovementService|MarketService|ChoiceService|BankruptcyService|Chance" Manager
    ls Manager
    ls Manager/MovementManager/Movement
    ls Manager/MarketManager/Market

依据盘点结果，执行文件重命名与移动（示例命令需根据最终清单逐一执行），并在同一步更新 require 路径与局部变量名。完成后删除空壳目录与无用 `__init.lua` require，例如移除 `Manager/BoardManager` 与 `Manager/__init.lua` 中对应 require 行。

重命名后在仓库根目录运行回归脚本并记录输出：

    lua .github/tests/regression.lua


## 验证与验收


运行 `lua .github/tests/regression.lua`，预期输出包含 “All regression checks passed (N)”。完成后用 `rg -n "Service.lua" Manager` 与 `rg -n "Manager\\.\\w+Manager\\.\\w+Service" Manager` 确认入口模块命名已统一为 `*Manager.lua`，且不存在旧路径引用。


## 可重复性与恢复


所有改动均为重命名与路径更新，可重复执行。若需要恢复，可按重命名前的路径反向移动文件并恢复旧 require 路径；在恢复后运行回归脚本确认行为未变。删除目录前应确保已无引用，避免出现空路径依赖。


## 产物与备注


保留以下证据片段：

    rg -n "GameplayRules|MovementManager|MarketManager|ChoiceManager" Manager
    lua .github/tests/regression.lua
    All regression checks passed (N)


## 接口与依赖


统一后的入口模块路径应为 `Manager.<Domain>Manager.<Domain>Manager`，并保持原有 API 入口函数不变。例如 Movement、Market、Choice、Bankruptcy 等入口模块仅重命名文件与 require 路径，不改变函数签名或行为。若需要移动目录（例如移除 `Movement/`、`Market/` 子目录），必须同步更新所有 require 路径与 `Manager/__init.lua` 引用。


本次修改说明：新建计划以梳理 Manager 层级、删除无用目录并统一入口模块命名，原因是用户要求统一管理器命名与结构。
