# Manager 层级压缩计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 `.github/agent/PLANS.md`。


## 目的 / 全局视角


本次改动把 `Manager/` 下多余的中间层目录压缩为单层路径，同时保留所有 `__init.lua`，不做空壳清理。完成后，管理器入口与域内模块的 require 路径更短、更一致，依赖关系更直观。可观察结果是：相关 Lua 文件移动后，require 路径统一更新且回归脚本通过。


## 进度


- [x] (2026-02-02 18:35Z) 盘点需压缩的子目录与目标路径，列出搬迁清单与引用点。
- [x] (2026-02-02 18:35Z) 迁移 `Choice/`、`Effect/`、`Item/`、`Land/`、`Turn/` 子目录文件到各自 Manager 根目录，保留 `__init.lua`。
- [x] (2026-02-02 18:35Z) 更新全仓 require 路径与局部变量名，确保路径与命名一致。
- [x] (2026-02-02 18:35Z) 运行回归脚本并记录输出，补充日志与复盘。


## 意外与发现


暂无。实施中未发现隐式初始化依赖或路径引用漏改。


## 决策日志


- 决策：保留各 Manager 根目录的 `__init.lua`，仅做路径压缩与 require 更新。
  理由：用户明确要求不清理空的 `__init.lua`，避免潜在加载顺序依赖。
  日期/作者：2026-02-02 / Codex
- 决策：将 `Choice/ChoiceHandlers` 上移为 `Manager/ChoiceManager/ChoiceHandlers`，并删除 `Choice/` 目录。
  理由：`Choice/` 仅承载中转目录，压缩后路径更短且不影响功能。
  日期/作者：2026-02-02 / Codex


## 结果与复盘


已完成层级压缩：`Choice/`、`Effect/`、`Item/`、`Land/`、`Turn/` 子目录搬迁至各自 Manager 根目录，并更新所有 require 路径。保留全部 `__init.lua`。回归脚本通过，行为保持一致。


## 背景与导读


`Manager/` 目录下存在多个仅用于分组的子目录，例如 `ChoiceManager/Choice/`、`EffectManager/Effect/`、`ItemManager/Item/`、`LandManager/Land/` 与 `TurnManager/Turn/`。这些子目录不包含独立初始化逻辑，只有普通模块文件，导致 require 路径冗长。本次只做路径压缩，不删除任何 `__init.lua`，避免影响加载顺序或外部依赖。

涉及的主要文件与目录：

  - `Manager/ChoiceManager/Choice/ChoiceRegistry.lua`
  - `Manager/ChoiceManager/Choice/ChoiceHandlers/*.lua`
  - `Manager/EffectManager/Effect/*.lua`
  - `Manager/ItemManager/Item/*.lua`
  - `Manager/LandManager/Land/*.lua`
  - `Manager/TurnManager/Turn/*.lua`


## 工作计划


先盘点每个子目录的文件清单与引用点，确认目标路径为各自 Manager 根目录，并将 `ChoiceHandlers` 目录上移到 `Manager/ChoiceManager/ChoiceHandlers`。随后逐类搬迁文件并更新 require：将 `Manager.ItemManager.Item.*` 替换为 `Manager.ItemManager.*`，将 `Manager.LandManager.Land.*` 替换为 `Manager.LandManager.*`，将 `Manager.EffectManager.Effect.*` 替换为 `Manager.EffectManager.*`，将 `Manager.TurnManager.Turn.*` 替换为 `Manager.TurnManager.*`，将 `Manager.ChoiceManager.Choice.ChoiceRegistry` 替换为 `Manager.ChoiceManager.ChoiceRegistry`，并将 `Manager.ChoiceManager.Choice.ChoiceHandlers.*` 替换为 `Manager.ChoiceManager.ChoiceHandlers.*`。整个过程中不删除任何 `__init.lua`。


## 具体步骤


在仓库根目录盘点子目录与引用点：

  rg -n "Manager\\.ItemManager\\.Item\\." -S
  rg -n "Manager\\.LandManager\\.Land\\." -S
  rg -n "Manager\\.EffectManager\\.Effect\\." -S
  rg -n "Manager\\.TurnManager\\.Turn\\." -S
  rg -n "Manager\\.ChoiceManager\\.Choice\\." -S
  Get-ChildItem -Path Manager/ChoiceManager/Choice -File
  Get-ChildItem -Path Manager/ChoiceManager/Choice/ChoiceHandlers -File
  Get-ChildItem -Path Manager/EffectManager/Effect -File
  Get-ChildItem -Path Manager/ItemManager/Item -File
  Get-ChildItem -Path Manager/LandManager/Land -File
  Get-ChildItem -Path Manager/TurnManager/Turn -File

按目录迁移文件并更新引用（路径示例需与盘点结果一致）：

  Move-Item Manager/ChoiceManager/Choice/ChoiceRegistry.lua Manager/ChoiceManager/ChoiceRegistry.lua
  Move-Item Manager/ChoiceManager/Choice/ChoiceHandlers Manager/ChoiceManager/ChoiceHandlers
  Move-Item Manager/EffectManager/Effect/*.lua Manager/EffectManager/
  Move-Item Manager/ItemManager/Item/*.lua Manager/ItemManager/
  Move-Item Manager/LandManager/Land/*.lua Manager/LandManager/
  Move-Item Manager/TurnManager/Turn/*.lua Manager/TurnManager/

全仓批量更新 require 路径并校验：

  rg -n "Manager\\.ItemManager\\.Item\\.|Manager\\.LandManager\\.Land\\.|Manager\\.EffectManager\\.Effect\\.|Manager\\.TurnManager\\.Turn\\.|Manager\\.ChoiceManager\\.Choice\\." -S

最后运行回归脚本并记录输出：

  lua .github/tests/regression.lua


## 验证与验收


运行 `lua .github/tests/regression.lua`，预期输出包含：

  All regression checks passed (32)

并使用 `rg -n` 确认旧路径不再出现：

  rg -n "Manager\\.ItemManager\\.Item\\.|Manager\\.LandManager\\.Land\\.|Manager\\.EffectManager\\.Effect\\.|Manager\\.TurnManager\\.Turn\\.|Manager\\.ChoiceManager\\.Choice\\." -S


## 可重复性与恢复


本次为路径迁移与 require 更新，可通过反向移动文件并恢复旧路径回滚；不涉及删除 `__init.lua`，风险可控。若迁移中断，可按“具体步骤”重新执行未完成的 Move-Item，并重新跑回归脚本确认状态。


## 产物与备注


保留以下证据片段：

  rg -n "Manager\\.TurnManager\\.Turn\\." -S
  lua .github/tests/regression.lua
  All regression checks passed (32)


## 接口与依赖


压缩后路径示例：

  - `Manager.ItemManager.ItemInventory`
  - `Manager.LandManager.LandPricing`
  - `Manager.EffectManager.EffectPipeline`
  - `Manager.TurnManager.TurnManager`
  - `Manager.ChoiceManager.ChoiceRegistry`
  - `Manager.ChoiceManager.ChoiceHandlers.MarketChoiceHandler`

上述路径必须可被现有代码 require，且对外 API 与函数签名保持不变。


本次修改说明：更新计划进度与决策/复盘，记录层级压缩执行结果与测试输出，原因是已完成实施并需保持计划为活文档。
