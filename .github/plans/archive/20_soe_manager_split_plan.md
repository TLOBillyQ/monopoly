本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循仓库内的 `/.agent/PLANS.md`。

# SOE Manager 分域重构


## 目的 / 全局视角

把 `Manager/GameManager` 下的规则逻辑按职责域拆分到子目录，接近 SecretOfEscaper 的 Manager 组织方式。完成后，每个子域有清晰边界，入口仍可通过原有模块加载，行为不变。验收时回归脚本应通过，且模块路径符合新的目录结构。

## 进度

- [x] (2026-01-29 15:57Z) 盘点 `Manager/GameManager` 模块并完成子域目录划分与落点确认
- [x] (2026-01-29 15:57Z) 按子域迁移文件与更新 require 路径，补齐 `__init.lua`
- [x] (2026-01-29 15:57Z) 清理旧路径引用与文档说明，运行测试验证

## 意外与发现

- 观察：批量替换 require 时，`Land` 与 `Effect` 的路径出现重复片段（如 `Land.Land.LandPricing`、`Effect.Effect.EffectPipeline`）。
  证据：`.github/tests/regression.lua` 已修正为 `Manager.EffectManager.Effect.EffectPipeline`，并通过回归测试。

## 决策日志

- 决策：将 `BankruptcyService`、`Chance`、`CompositionRoot` 与 `Game/Constants` 等核心模块放入 `System/` 子域。
  理由：避免新增新域，保持“系统内核”集中，符合 SOE 的按职责分层习惯。
  日期/作者：2026-01-29 / Codex

## 结果与复盘

完成 `Manager/GameManager` 分域目录重排与 require 路径更新，新增 `__init.lua` 入口，依赖检查与回归测试通过。后续计划可基于新目录继续拆分 UI 与配置层。

## 背景与导读

目前 `Manager/GameManager` 已拆分为 `Turn/Item/Land/Market/Choice/Movement/Effect/System` 子域，原有模块按职责分层组织。SOE 的 Manager 结构更倾向按功能域分层组织，因此本计划以“只改路径不改行为”为原则，保留原有调用方式，仅更新 require 路径与入口文件。

## 工作计划

先给出子域划分清单，例如：

  Turn/: TurnManager、TurnStart/TurnRoll/TurnMove/TurnLand/TurnPost/TurnEnd
  Item/: ItemInventory、ItemExecutor、ItemPhase、ItemPostEffects、ItemDemolish、ItemRoadblock、ItemRemoteDice、ItemSteal、ItemStrategy
  Land/: Land、LandActions、LandChoiceSpecs、LandPricing、Landing
  Market/: MarketService
  Choice/: ChoiceService、ChoiceHandlers/*
  Movement/: MovementService
  Effect/: Effect、EffectPipeline、MineEffect
  System/: BoardFactory、Agent、PlayerEffects、PlayerVehicle、Constants、Game

迁移时优先改目录、后改文件路径，并新增 `Manager/GameManager/__init.lua` 与子域 `__init.lua` 作为统一出口。所有 require 路径统一为新结构（例如 `Manager.ItemManager.Item.ItemInventory`），并同步更新测试与文档引用。保持模块表与函数名不变，只移动路径。

## 具体步骤

在仓库根目录执行：

  1) 生成“旧路径 -> 新路径”映射清单并确认子域划分。
  2) 按子域创建目录并移动文件，必要时使用临时名处理大小写。
  3) 全量替换 require 路径与文档引用，并修正重复路径。
  4) 新增或更新 `__init.lua`，确保入口模块可被统一加载。

## 验证与验收

在仓库根目录运行：

  lua .github/tests/deps_check.lua
  lua .github/tests/regression.lua

预期测试无报错。重点验证回合推进、道具使用与地块交易流程不受影响。已完成上述测试并通过。

## 可重复性与恢复

改动为文件移动与路径改写，可重复执行。若迁移失败，可先恢复目录结构与 require 路径，再重新迁移。本次已按新目录完成迁移。

## 产物与备注

产物为新的 `Manager/GameManager/<Domain>/` 目录结构及对应 `__init.lua` 出口文件。

  Dependency self-check passed
  ..............................
  All regression checks passed (30)

## 接口与依赖

所有模块对外接口与返回值保持不变。新增 `__init.lua` 保持幂等与纯导出，不引入新逻辑。

更新说明：完成 Manager 分域迁移与 require 路径更新，补齐 `__init.lua` 并记录测试结果，确保计划落地可追溯。
